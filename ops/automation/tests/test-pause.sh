#!/usr/bin/env bash
# Tests for the project pause (ops/scripts/graft + the pause handling in worker.sh /
# review.sh / lib.sh). Offline: Ollama is a tiny stub HTTP server (or an unreachable
# port), nvidia-smi and claude are stubs. End-to-end checks run the working-tree
# worker.sh in a throwaway clone with no remote.
set -uo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
auto="$(cd "${here}/.." && pwd)"
repo="$(cd "${auto}/../.." && pwd)"
graft="${repo}/ops/scripts/graft"
tmp="$(mktemp -d)"
stub_pid=""
cleanup() { [[ -n "${stub_pid}" ]] && kill "${stub_pid}" 2>/dev/null; rm -rf "${tmp}"; }
trap cleanup EXIT
fails=0
ok()   { printf 'ok   - %s\n' "$1"; }
fail() { printf 'FAIL - %s\n' "$1"; fails=$((fails + 1)); }
check() { local name="$1"; shift; if "$@"; then ok "${name}"; else fail "${name}"; fi; }

# Every graft invocation below is confined to ${tmp}: its own flag, data dir, log.
export PAUSE_FLAG="${tmp}/pause" DATA_DIR="${tmp}/data" RUNS_LOG="${tmp}/data/runs.log"
export OLLAMA_HOST_URL="http://127.0.0.1:9"   # discard port: nothing listens
printf '#!/usr/bin/env bash\necho "2000, 8188"\n' > "${tmp}/nvidia-smi"; chmod +x "${tmp}/nvidia-smi"
export NVIDIA_SMI_BIN="${tmp}/nvidia-smi"
export GRAFT_UNLOAD_TIMEOUT=5

# ── 6 (syntax first) ──
check "graft parses" bash -n "${graft}"
check "graft is executable" test -x "${graft}"
check "worker.sh parses" bash -n "${auto}/worker.sh"
check "review.sh parses" bash -n "${auto}/review.sh"
check "lib.sh parses" bash -n "${auto}/lib.sh"

# ── 1: pause / status / resume round trip ──
rc=0; out="$("${graft}" status)" || rc=$?
check "status while active exits 0" test "${rc}" = 0
check "status while active prints ACTIVE" grep -q '^ACTIVE' <<< "${out}"
rc=0; out="$("${graft}" pause --reason "gaming night")" || rc=$?
check "pause exits 0" test "${rc}" = 0
check "flag has since=" grep -qE '^since=[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9:]{8}Z$' "${PAUSE_FLAG}"
check "flag has reason=" grep -qx 'reason=gaming night' "${PAUSE_FLAG}"
check "flag has mode=soft" grep -qx 'mode=soft' "${PAUSE_FLAG}"
check "pause-requested logged" grep -qE 'run=ctl-[^ ]+ item=- event=pause-requested mode=soft' "${RUNS_LOG}"
check "pause prints GPU before → after" grep -q 'GPU memory used: 2000 → 2000 MiB (of 8188 MiB)' <<< "${out}"
since1="$(sed -n 's/^since=//p' "${PAUSE_FLAG}")"
sleep 1
"${graft}" pause --hard --reason again >/dev/null
check "re-pause keeps original since" test "$(sed -n 's/^since=//p' "${PAUSE_FLAG}")" = "${since1}"
check "re-pause updates reason and mode" bash -c "grep -qx 'reason=again' '${PAUSE_FLAG}' && grep -qx 'mode=hard' '${PAUSE_FLAG}'"
rc=0; out="$("${graft}" status)" || rc=$?
check "status while paused exits 3" test "${rc}" = 3
check "status while paused prints PAUSED + since/reason/mode" grep -qE "^PAUSED since ${since1} — reason: again — mode: hard" <<< "${out}"
check "status reports GPU memory" grep -q 'GPU memory used: 2000 / 8188 MiB' <<< "${out}"
rc=0; "${graft}" resume >/dev/null || rc=$?
check "resume exits 0" test "${rc}" = 0
check "resume removes the flag" test ! -e "${PAUSE_FLAG}"
check "resumed logged" grep -q 'event=resumed' "${RUNS_LOG}"
rc=0; "${graft}" status >/dev/null || rc=$?
check "status after resume exits 0" test "${rc}" = 0
rc=0; "${graft}" resume >/dev/null || rc=$?
check "resume when not paused exits 0" test "${rc}" = 0
rc=0; "${graft}" bogus >/dev/null 2>&1 || rc=$?
check "unknown subcommand exits 2" test "${rc}" = 2

# stale pid file (dead pid) is not reported as a running worker
mkdir -p "${DATA_DIR}"; printf '999999 999999 r-stale\nE-01\n' > "${DATA_DIR}/worker.pid"
check "stale worker.pid reads as not running" bash -c "'${graft}' status | grep -q '^  worker: none'"
rm -f "${DATA_DIR}/worker.pid"

# ── 2: unreachable Ollama ──
rc=0; out="$("${graft}" pause)" || rc=$?
check "pause with unreachable Ollama exits 0" test "${rc}" = 0
check "pause with unreachable Ollama says nothing to free" grep -q 'not reachable.*nothing to free' <<< "${out}"
"${graft}" resume >/dev/null

# ── 3: unload models reported by a stub /api/ps ──
cat > "${tmp}/ollama_stub.py" <<'PY'
import json, sys, threading
from http.server import BaseHTTPRequestHandler, HTTPServer
state_dir = sys.argv[1]
lock = threading.Lock()
models = [
    {"name": "chat-a:8k", "model": "chat-a:8k", "size": 6000000000, "size_vram": 6000000000},
    {"name": "embed-b:0.6b", "model": "embed-b:0.6b", "size": 2000000000, "size_vram": 0},
]
class H(BaseHTTPRequestHandler):
    def log_message(self, *a): pass
    def reply(self, code, obj):
        body = json.dumps(obj).encode()
        self.send_response(code); self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body))); self.end_headers(); self.wfile.write(body)
    def do_GET(self):
        with lock:
            if self.path == "/api/ps": return self.reply(200, {"models": models})
        self.reply(404, {})
    def do_POST(self):
        req = json.loads(self.rfile.read(int(self.headers.get("Content-Length", 0))) or b"{}")
        name = req.get("model")
        # This stub refuses /api/generate for embedding models (as some Ollama
        # versions do), so the client must fall back to /api/embed.
        code = 400 if (self.path == "/api/generate" and name.startswith("embed")) else 200
        with lock:
            if code == 200 and req.get("keep_alive") == 0:
                models[:] = [m for m in models if m["name"] != name]
            with open(state_dir + "/requests.log", "a") as f:
                f.write("%s %s keep_alive=%s status=%d\n" % (self.path, name, json.dumps(req.get("keep_alive")), code))
        self.reply(code, {"done": True} if code == 200 else {"error": "does not support generate"})
srv = HTTPServer(("127.0.0.1", 0), H)
open(state_dir + "/port", "w").write(str(srv.server_address[1]))
srv.serve_forever()
PY
python3 "${tmp}/ollama_stub.py" "${tmp}" & stub_pid=$!
for _ in $(seq 50); do [[ -s "${tmp}/port" ]] && break; sleep 0.1; done
stub_url="http://127.0.0.1:$(cat "${tmp}/port")"
out="$(OLLAMA_HOST_URL="${stub_url}" "${graft}" status)" || true
check "status lists loaded models with processor" bash -c "grep -q 'chat-a:8k .*100% GPU' <<< \"\$1\" && grep -q 'embed-b:0.6b .*100% CPU' <<< \"\$1\"" _ "${out}"
rc=0; out="$(OLLAMA_HOST_URL="${stub_url}" "${graft}" pause)" || rc=$?
check "pause against stub exits 0" test "${rc}" = 0
check "chat model unloaded once via /api/generate keep_alive 0" \
  test "$(grep -c '^/api/generate chat-a:8k keep_alive=0 status=200$' "${tmp}/requests.log")" = 1
check "embedding model unloaded once via /api/embed keep_alive 0" \
  test "$(grep -c '^/api/embed embed-b:0.6b keep_alive=0 status=200$' "${tmp}/requests.log")" = 1
check "exactly one successful unload per model" test "$(grep -c 'status=200' "${tmp}/requests.log")" = 2
check "pause reports both models unloaded and ps empty" \
  bash -c "grep -q 'unloaded chat-a:8k' <<< \"\$1\" && grep -q 'unloaded embed-b:0.6b' <<< \"\$1\" && grep -q 'no models loaded' <<< \"\$1\"" _ "${out}"
kill "${stub_pid}" 2>/dev/null; wait "${stub_pid}" 2>/dev/null; stub_pid=""
"${graft}" resume >/dev/null

# ── 4 & 5: worker end-to-end in a throwaway clone (no remote; stub claude) ──
clone="${tmp}/clone"
git clone -q "${repo}" "${clone}"
git -C "${clone}" checkout -q -B main
git -C "${clone}" config user.name "Graft Test"; git -C "${clone}" config user.email test@example.invalid
# Test the working-tree scripts, not the last commit.
cp "${auto}/lib.sh" "${auto}/worker.sh" "${auto}/review.sh" "${clone}/ops/automation/"
mkdir -p "${clone}/ops/scripts"; cp "${graft}" "${clone}/ops/scripts/graft"
cat > "${clone}/BACKLOG.md" <<'B'
# BACKLOG
current-phase: 0.5

## Phase 0.5

### E-01 · Pause end-to-end item
- status: open
- phase: 0.5
- executor: worker
- owner-only: no
- depends: —
- dod: see dod-cmd
- dod-cmd: false
B
git -C "${clone}" add -A && git -C "${clone}" commit -q --no-verify -m "test: pause e2e fixture"
mkstub() { # mkstub <name> <body>
  printf '#!/usr/bin/env bash\nif [ "$1" = auth ]; then echo "{\\"loggedIn\\": true}"; exit 0; fi\n%s\n' "$2" > "${tmp}/$1"; chmod +x "${tmp}/$1"
}
worker_env() { # worker_env <label> <cmd...>: run with the clone's paths and a per-test data dir
  local label="$1"; shift
  env DATA_DIR="${tmp}/e2e-${label}" RUNS_LOG="${tmp}/e2e-${label}/runs.log" PAUSE_FLAG="${tmp}/e2e-${label}/pause" \
      AUTOMATION_DIR="${clone}/ops/automation" REPO_ROOT="${clone}" \
      EXCLUSIONS_FILE="${clone}/ops/automation/exclusions.txt" WORKER_REMOTE=__none__ "$@"
}
wait_for() { # wait_for <seconds> <cmd...>
  local secs="$1" i; shift
  for (( i = 0; i < secs * 5; i++ )); do "$@" && return 0; sleep 0.2; done
  return 1
}

# (4) --hard stops an in-flight worker and releases its claim
mkstub claude-sleep "echo \$\$ > '${tmp}/claude-sleep.pid'; exec sleep 60"
( cd "${clone}" && CLAUDE_BIN="${tmp}/claude-sleep" worker_env hard "${clone}/ops/automation/worker.sh" ) \
  > "${tmp}/hard.out" 2>&1 &
wpid=$!
check "hard: headless session started" wait_for 180 test -s "${tmp}/claude-sleep.pid"
check "hard: worker.pid names the worker and the item" \
  bash -c "read -r p _ < '${tmp}/e2e-hard/worker.pid' && [ \"\$p\" = '${wpid}' ] || pgrep -P '${wpid}' | grep -qx \"\$p\"; sed -n 2p '${tmp}/e2e-hard/worker.pid' | grep -qx E-01"
check "hard: claim branch exists" bash -c "git -C '${clone}' rev-parse -q --verify auto/E-01 >/dev/null"
t0="$(date +%s)"
out="$(cd "${clone}" && worker_env hard "${clone}/ops/scripts/graft" pause --hard --reason test-hard)"; rc=$?
secs=$(( $(date +%s) - t0 ))
check "hard: stop completed promptly via TERM (${secs}s < 30s, no SIGKILL fallback)" test "${secs}" -lt 30
check "hard: graft pause --hard exits 0" test "${rc}" = 0
check "hard: pause reports a clean stop" grep -q 'worker: stopped cleanly' <<< "${out}"
check "hard: worker process gone" wait_for 5 bash -c "! kill -0 ${wpid} 2>/dev/null"
wrc=0; wait "${wpid}" || wrc=$?
check "hard: worker exited 0" test "${wrc}" = 0
check "hard: headless session killed" bash -c "! kill -0 \$(cat '${tmp}/claude-sleep.pid') 2>/dev/null"
check "hard: logged status=paused claim=released" grep -qE 'item=E-01 event=end status=paused .*claim=released exit=0' "${tmp}/e2e-hard/runs.log"
check "hard: claim branch deleted" bash -c "! git -C '${clone}' rev-parse -q --verify auto/E-01 >/dev/null"
check "hard: worktree removed" test "$(git -C "${clone}" worktree list | wc -l)" = 1
check "hard: item not marked blocked" bash -c "! grep -q 'status=blocked' '${tmp}/e2e-hard/runs.log' && git -C '${clone}' show main:BACKLOG.md | grep -A1 'E-01 ·' | grep -q 'status: open'"
check "hard: pid file removed" test ! -e "${tmp}/e2e-hard/worker.pid"
check "hard: flag written with mode=hard" grep -qx 'mode=hard' "${tmp}/e2e-hard/pause"
rc=0; out="$(cd "${clone}" && worker_env hard "${clone}/ops/automation/worker.sh")" || rc=$?
check "hard: next worker run is paused (exit 0, no claim)" \
  bash -c "[ '${rc}' = 0 ] && [ \"\$1\" = paused ] && ! git -C '${clone}' rev-parse -q --verify auto/E-01 >/dev/null" _ "${out}"

# (5) soft pause mid-run: the in-flight attempt finishes, no further attempt starts
mkstub claude-pauser "touch '${tmp}/e2e-soft/pause'; echo '{}'"
rc=0
( cd "${clone}" && CLAUDE_BIN="${tmp}/claude-pauser" WORKER_MAX_ATTEMPTS=3 worker_env soft "${clone}/ops/automation/worker.sh" ) \
  > "${tmp}/soft.out" 2>&1 || rc=$?
check "soft: worker exits 0" test "${rc}" = 0
check "soft: exactly one attempt ran" test "$(grep -c 'event=attempt' "${tmp}/e2e-soft/runs.log")" = 1
check "soft: logged status=paused attempts=1 claim=released" \
  grep -qE 'item=E-01 event=end status=paused attempts=1 claim=released exit=0' "${tmp}/e2e-soft/runs.log"
check "soft: claim branch deleted" bash -c "! git -C '${clone}' rev-parse -q --verify auto/E-01 >/dev/null"
check "soft: not blocked" bash -c "! grep -q 'status=blocked' '${tmp}/e2e-soft/runs.log'"
check "soft: pid file removed" test ! -e "${tmp}/e2e-soft/worker.pid"

# ── 6: the existing worker suite still passes ──
if "${here}/test-worker.sh" > "${tmp}/test-worker.out" 2>&1; then ok "test-worker.sh passes"; else
  fail "test-worker.sh passes"; grep '^FAIL' "${tmp}/test-worker.out" | sed 's/^/    /'
fi

echo
if (( fails > 0 )); then echo "${fails} check(s) failed"; exit 1; fi
echo "all checks passed"
