#!/usr/bin/env bash
# Tests for worker.sh / lib.sh. No network, no model: `claude` and `gh` are stubs.
# Unit checks run against lib.sh; end-to-end checks run the real worker.sh in a
# throwaway clone of the committed repo with no remote.
set -uo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
auto="$(cd "${here}/.." && pwd)"
repo="$(cd "${auto}/../.." && pwd)"
tmp="$(mktemp -d)"; trap 'rm -rf "${tmp}"' EXIT
fails=0
ok()   { printf 'ok   - %s\n' "$1"; }
fail() { printf 'FAIL - %s\n' "$1"; fails=$((fails + 1)); }
check() { local name="$1"; shift; if "$@"; then ok "${name}"; else fail "${name}"; fi; }

export RUNS_LOG="${tmp}/runs.log" PAUSE_FLAG="${tmp}/pause" DATA_DIR="${tmp}/data"
# shellcheck source=../lib.sh
source "${auto}/lib.sh"

# ── syntax ──
check "worker.sh parses" bash -n "${auto}/worker.sh"
check "review.sh parses" bash -n "${auto}/review.sh"

# ── selection (--dry-run on a fixture backlog) ──
fixture="${auto}/fixtures/backlog-sample.md"
printf 'auto/F-03\n' > "${tmp}/branches"
check "select_item picks first eligible (F-04)" test "$(select_item "${fixture}" "${tmp}/branches")" = "F-04"
check "without the claim branch, F-03 is first" test "$(select_item "${fixture}" /dev/null)" = "F-03"
printf 'auto/F-03\nauto/F-04\n' > "${tmp}/branches2"
check "nothing eligible → non-zero" bash -c "! (source '${auto}/lib.sh'; select_item '${fixture}' '${tmp}/branches2')"
check "phase_le rejects non-numeric phases" bash -c "! (source '${auto}/lib.sh'; phase_le pre-P3 0.5)"
dry="$(cd "${repo}" && WORKER_BACKLOG_FILE="${fixture}" RUNS_LOG="${tmp}/dry.log" DATA_DIR="${tmp}/dry" \
       WORKER_REMOTE=__none__ "${auto}/worker.sh" --dry-run)"
check "worker.sh --dry-run prints the selected item" test "${dry}" = "F-03"
cp "${fixture}" "${tmp}/b.md"; set_item_status "${tmp}/b.md" F-04 claimed "claimed-by: r1"
check "set_item_status rewrites only the target item" test "$(item_status "${tmp}/b.md" F-04)/$(item_status "${tmp}/b.md" F-03)" = "claimed/open"
check "set_item_status inserts the extra field" grep -q '^- claimed-by: r1$' "${tmp}/b.md"
check "item_field reads dod-cmd" test "$(item_field "${fixture}" F-04 dod-cmd)" = "true"

# ── hard exclusions: every listed path is refused ──
while IFS= read -r p; do
  p="${p%%#*}"; p="${p//[[:space:]]/}"; [[ -z "${p}" ]] && continue
  probe="${p}"; [[ "${p}" == */ ]] && probe="${p}x.md"
  check "exclusion refuses ${probe}" bash -c "! (source '${auto}/lib.sh'; exclusion_violations '${repo}' '${probe}' >/dev/null)"
done < "${auto}/exclusions.txt"
check "allowed path passes" bash -c "source '${auto}/lib.sh'; exclusion_violations '${repo}' packages/core/src/x.ts PROGRESS.md"
mkdir -p "${tmp}/cr/canaries/s1"; git -C "${tmp}/cr" init -q
printf 'id: c1\nholdout: true\n' > "${tmp}/cr/canaries/s1/c1.yaml"; printf 'id: c2\nholdout: false\n' > "${tmp}/cr/canaries/s1/c2.yaml"
check "canary holdout is refused" bash -c "! (source '${auto}/lib.sh'; exclusion_violations '${tmp}/cr' canaries/s1/c1.yaml >/dev/null)"
check "non-holdout canary is allowed" bash -c "source '${auto}/lib.sh'; exclusion_violations '${tmp}/cr' canaries/s1/c2.yaml"

# ── wall-clock timeout ──
rc=0; run_with_timeout 1 sleep 5 || rc=$?
check "run_with_timeout fires (exit 124)" test "${rc}" = 124

# ── logging ──
log_event r-test F-99 start base=main
check "log line has timestamp, run, item, event, fields" \
  grep -qE '^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9:]{8}Z run=r-test item=F-99 event=start base=main$' "${RUNS_LOG}"

# ── pause flag ──
touch "${PAUSE_FLAG}"
out="$(cd "${repo}" && "${auto}/worker.sh")"; rc=$?
check "paused worker exits 0" test "${rc}" = 0
check "paused worker logs 'paused'" grep -q 'event=paused' "${RUNS_LOG}"
rm -f "${PAUSE_FLAG}"

# ── end-to-end in a throwaway clone (no remote; stub claude) ──
clone="${tmp}/clone"
git clone -q "${repo}" "${clone}"
git -C "${clone}" config user.name "Graft Test"; git -C "${clone}" config user.email test@example.invalid
git -C "${clone}" config core.hooksPath ops/automation/githooks
(cd "${clone}" && pnpm install --frozen-lockfile --offline --reporter=silent) || fail "clone install"
mkstub() { # mkstub <name> <body>
  printf '#!/usr/bin/env bash\n%s\n' "$2" > "${tmp}/$1"; chmod +x "${tmp}/$1"
}
e2e_backlog() { # e2e_backlog <dod-cmd>
  cat > "${clone}/BACKLOG.md" <<B
# BACKLOG
current-phase: 0.5

## Phase 0.5

### E-01 · End-to-end item
- status: open
- phase: 0.5
- executor: worker
- owner-only: no
- depends: —
- dod: see dod-cmd
- dod-cmd: $1
B
  git -C "${clone}" add BACKLOG.md && git -C "${clone}" commit -q -m "test: e2e backlog" --no-verify
}
run_e2e() { # run_e2e <label> ; env passed through
  ( cd "${clone}" && DATA_DIR="${tmp}/e2e-$1" RUNS_LOG="${tmp}/e2e-$1/runs.log" PAUSE_FLAG="${tmp}/nopause" \
      AUTOMATION_DIR="${clone}/ops/automation" REPO_ROOT="${clone}" EXCLUSIONS_FILE="${clone}/ops/automation/exclusions.txt" \
      WORKER_REMOTE=__none__ "${clone}/ops/automation/worker.sh" )
}

# (a) green: stub writes a file the DoD checks for, and commits it
mkstub claude-green 'printf "export const e2e = 1;\n" > packages/core/src/e2e.ts; git add -A; git commit -q -m "feat(core): e2e"; echo "{}"'
e2e_backlog 'test -f packages/core/src/e2e.ts'
CLAUDE_BIN="${tmp}/claude-green" WORKER_MAX_ATTEMPTS=2 run_e2e green >/dev/null 2>&1
check "e2e green: success logged with exit=0" grep -qE 'item=E-01 event=end status=success .*exit=0' "${tmp}/e2e-green/runs.log"
check "e2e green: item marked done on branch" bash -c "git -C '${clone}' show auto/E-01:BACKLOG.md | grep -A1 'E-01 ·' | grep -q 'status: done'"
check "e2e green: claim then done commits present" bash -c "git -C '${clone}' log --format=%s main..auto/E-01 | grep -q 'claim E-01' && git -C '${clone}' log --format=%s main..auto/E-01 | grep -q 'E-01 done'"
git -C "${clone}" branch -q -D auto/E-01

# (b) exclusion: stub edits ops/stats.yaml → refused, no success, blocked
mkstub claude-excl 'echo "# tamper" >> ops/stats.yaml; echo "{}"'
e2e_backlog 'true'
CLAUDE_BIN="${tmp}/claude-excl" WORKER_MAX_ATTEMPTS=2 run_e2e excl >/dev/null 2>&1
check "e2e exclusion: violation logged for ops/stats.yaml" grep -qE 'event=exclusion-violation paths=ops/stats.yaml' "${tmp}/e2e-excl/runs.log"
check "e2e exclusion: blocked, never success" bash -c "grep -q 'status=blocked reason=exclusion-violation' '${tmp}/e2e-excl/runs.log' && ! grep -q 'status=success' '${tmp}/e2e-excl/runs.log'"
check "e2e exclusion: tampered file not on branch" bash -c "! git -C '${clone}' show auto/E-01:ops/stats.yaml | grep -q tamper"
git -C "${clone}" branch -q -D auto/E-01

# (c) iteration cap + timeout: stub hangs past the per-attempt budget; DoD never passes
mkstub claude-hang 'sleep 30'
e2e_backlog 'false'
CLAUDE_BIN="${tmp}/claude-hang" WORKER_MAX_ATTEMPTS=2 WORKER_CLAUDE_TIMEOUT=1 run_e2e cap >/dev/null 2>&1
check "e2e cap: each attempt times out" test "$(grep -c 'event=timeout' "${tmp}/e2e-cap/runs.log")" = 2
check "e2e cap: stops at iteration cap with clean exit" grep -qE 'status=blocked reason=iteration-cap attempts=2 exit=0' "${tmp}/e2e-cap/runs.log"
check "e2e cap: blocked status + reason on branch" bash -c "git -C '${clone}' show auto/E-01:BACKLOG.md | grep -A2 'E-01 ·' | grep -q 'status: blocked'"
check "e2e cap: PROGRESS note on branch" bash -c "git -C '${clone}' show auto/E-01:PROGRESS.md | grep -q 'E-01 is BLOCKED'"

echo
if (( fails > 0 )); then echo "${fails} check(s) failed"; exit 1; fi
echo "all checks passed"
