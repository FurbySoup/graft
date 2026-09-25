#!/usr/bin/env bash
# Shared functions for Graft's dev-automation scripts (worker.sh, review.sh).
# Sourced, never executed. Every function is pure over its arguments/env where
# possible so ops/automation/tests/ can exercise it without a network or a model.

# Resolve paths relative to this file so the scripts work from cron and worktrees.
AUTOMATION_DIR="${AUTOMATION_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"
REPO_ROOT="${REPO_ROOT:-$(cd "${AUTOMATION_DIR}/../.." && pwd)}"
DATA_DIR="${DATA_DIR:-${REPO_ROOT}/data/automation}"
RUNS_LOG="${RUNS_LOG:-${DATA_DIR}/runs.log}"
PAUSE_FLAG="${PAUSE_FLAG:-${AUTOMATION_DIR}/pause}"
EXCLUSIONS_FILE="${EXCLUSIONS_FILE:-${AUTOMATION_DIR}/exclusions.txt}"

# cron has a minimal PATH; pnpm lives in a corepack shim under ~/.local/bin.
export PATH="${HOME}/.local/bin:/usr/local/bin:/usr/bin:/bin:${PATH:-}"

# log <run_id> <item_id> <event> [key=value ...]
# One line per event: ISO-8601 UTC timestamp, then space-separated key=value pairs.
log_event() {
  local run_id="$1" item="$2" event="$3"
  shift 3
  mkdir -p "$(dirname "${RUNS_LOG}")"
  printf '%s run=%s item=%s event=%s%s\n' \
    "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "${run_id}" "${item}" "${event}" \
    "$(for kv in "$@"; do printf ' %s' "${kv}"; done)" >> "${RUNS_LOG}"
}

is_paused() { [[ -e "${PAUSE_FLAG}" ]]; }

new_run_id() { printf '%s-%s' "$(date -u +%Y%m%dT%H%M%SZ)" "$$"; }

# ── BACKLOG parsing ─────────────────────────────────────────────────────────────
# Items look like:
#   ### <id> · <title>
#   - status: open
#   - key: value
# Emits one tab-separated record per item: id, status, phase, executor, depends, dod-cmd
backlog_records() {
  local backlog="$1"
  awk '
    function flush() {
      if (id != "") printf "%s\t%s\t%s\t%s\t%s\t%s\n", id, f["status"], f["phase"], f["executor"], f["depends"], f["dod-cmd"]
      id = ""; delete f
    }
    /^### / {
      flush()
      line = substr($0, 5)
      split(line, parts, " · ")
      id = parts[1]
      next
    }
    /^## / { flush(); next }
    id != "" && /^- [a-z-]+: / {
      key = $2; sub(/:$/, "", key)
      val = $0; sub(/^- [a-z-]+: /, "", val)
      f[key] = val
    }
    END { flush() }
  ' "${backlog}"
}

backlog_current_phase() {
  awk '/^current-phase: /{ print $2; exit }' "$1"
}

# phase_le <item_phase> <current_phase>: numeric phases only; anything else
# (e.g. "pre-P3") is never eligible for the worker.
phase_le() {
  awk -v a="$1" -v b="$2" 'BEGIN {
    if (a !~ /^[0-9]+(\.[0-9]+)?$/ || b !~ /^[0-9]+(\.[0-9]+)?$/) exit 1
    exit !(a + 0 <= b + 0)
  }'
}

# item_status <backlog> <id>
item_status() {
  backlog_records "$1" | awk -F'\t' -v id="$2" '$1 == id { print $2; exit }'
}

# select_item <backlog> [existing-branches-file]
# Prints the id of the first eligible item (top to bottom): status open,
# executor worker, phase <= current-phase, every dependency done, and no
# auto/<id> branch already present (the branch is the claim lock).
select_item() {
  local backlog="$1" branches="${2:-/dev/null}" current id status phase executor depends dod dep ok
  current="$(backlog_current_phase "${backlog}")"
  while IFS=$'\t' read -r id status phase executor depends dod; do
    [[ "${status}" == "open" && "${executor}" == "worker" ]] || continue
    phase_le "${phase}" "${current}" || continue
    grep -qxF "auto/${id}" "${branches}" 2>/dev/null && continue
    ok=1
    if [[ -n "${depends}" && "${depends}" != "—" && "${depends}" != "-" ]]; then
      IFS=',' read -ra deps <<< "${depends}"
      for dep in "${deps[@]}"; do
        dep="${dep// /}"
        [[ -z "${dep}" ]] && continue
        [[ "$(item_status "${backlog}" "${dep}")" == "done" ]] || { ok=0; break; }
      done
    fi
    [[ "${ok}" == 1 ]] || continue
    printf '%s\n' "${id}"
    return 0
  done < <(backlog_records "${backlog}")
  return 1
}

# item_block <backlog> <id>: the item's full markdown block, verbatim.
item_block() {
  awk -v id="$2" '
    /^### / { inblock = (index(substr($0, 5), id " · ") == 1) }
    /^## / { inblock = 0 }
    /^---$/ { inblock = 0 }
    inblock { print }
  ' "$1"
}

# item_field <backlog> <id> <key>
item_field() {
  item_block "$1" "$2" | awk -v k="$3" 'index($0, "- " k ": ") == 1 { sub("^- " k ": ", ""); print; exit }'
}

# set_item_status <backlog> <id> <new-status> [extra "key: value" line]
# Rewrites the item's status line in place; optionally inserts one extra field
# line right after it (e.g. "claimed-by: <run>" or "blocked: <reason>").
set_item_status() {
  local backlog="$1" id="$2" new="$3" extra="${4:-}" tmp
  tmp="$(mktemp)"
  awk -v id="$id" -v new="$new" -v extra="$extra" '
    /^### / { inblock = (index(substr($0, 5), id " · ") == 1) }
    /^## / { inblock = 0 }
    inblock && /^- status: / {
      print "- status: " new
      if (extra != "") print "- " extra
      next
    }
    { print }
  ' "${backlog}" > "${tmp}" && mv "${tmp}" "${backlog}"
}

# ── Hard exclusions (SPEC §9) ───────────────────────────────────────────────────
# exclusion_violations <repo_dir> <path>...
# Prints every path that an autonomous run must not touch; exit 1 if any.
# Rules come from exclusions.txt (one path prefix per line, '#' comments), plus:
# any canaries/** file whose old or new content declares `holdout: true`.
exclusion_violations() {
  local repo="$1" path prefix bad=0
  shift
  local -a prefixes=()
  while IFS= read -r prefix; do
    prefix="${prefix%%#*}"; prefix="${prefix//[[:space:]]/}"
    [[ -n "${prefix}" ]] && prefixes+=("${prefix}")
  done < "${EXCLUSIONS_FILE}"
  for path in "$@"; do
    for prefix in "${prefixes[@]}"; do
      if [[ "${path}" == "${prefix}" || "${path}" == "${prefix%/}/"* ]]; then
        printf '%s\n' "${path}"; bad=1; continue 2
      fi
    done
    if [[ "${path}" == canaries/* ]]; then
      if grep -qE '^holdout:[[:space:]]*true' "${repo}/${path}" 2>/dev/null \
         || git -C "${repo}" show "HEAD:${path}" 2>/dev/null | grep -qE '^holdout:[[:space:]]*true'; then
        printf '%s\n' "${path}"; bad=1
      fi
    fi
  done
  return "${bad}"
}

# changed_paths <repo_dir> <base_ref>: committed-since-base + staged + unstaged + untracked.
changed_paths() {
  local repo="$1" base="$2"
  {
    git -C "${repo}" diff --name-only "${base}" HEAD
    git -C "${repo}" diff --name-only --cached
    git -C "${repo}" diff --name-only
    git -C "${repo}" ls-files --others --exclude-standard
  } | sort -u
}

# ── Running the headless session under a wall-clock budget ─────────────────────
# run_with_timeout <seconds> <cmd...>: exit 124 on timeout (GNU timeout semantics).
run_with_timeout() {
  local secs="$1"; shift
  timeout --kill-after=30 "${secs}" "$@"
}

# claude_logged_in <claude-bin>: exit 0 only if the CLI reports an authenticated
# session. The worker and reviewer refuse to run otherwise (observed 2026-09-25: an
# unauthenticated CLI fails every attempt in ~2 s and would masquerade as a cap hit).
claude_logged_in() {
  "$1" auth status 2>/dev/null | python3 -c 'import json,sys; sys.exit(0 if json.load(sys.stdin).get("loggedIn") else 1)' 2>/dev/null
}

# ── Pause support: pid files, clean shutdown, claim release, Ollama unload ─────
# Consumed by worker.sh / review.sh (pid files, TERM traps) and ops/scripts/graft.
OLLAMA_HOST_URL="${OLLAMA_HOST_URL:-http://localhost:11434}"
NVIDIA_SMI_BIN="${NVIDIA_SMI_BIN:-nvidia-smi}"
WORKER_PID_FILE="${WORKER_PID_FILE:-${DATA_DIR}/worker.pid}"
REVIEW_PID_FILE="${REVIEW_PID_FILE:-${DATA_DIR}/review.pid}"

# write_pid_file <file> <run_id> [item]
# Line 1: "<pid> <pgid> <run_id>"; line 2 (once known): the backlog item id.
write_pid_file() {
  local file="$1" run_id="$2" item="${3:-}" pgid
  pgid="$(ps -o pgid= -p "$$" 2>/dev/null | tr -d ' ')"
  mkdir -p "$(dirname "${file}")"
  { printf '%s %s %s\n' "$$" "${pgid:-?}" "${run_id}"; [[ -n "${item}" ]] && printf '%s\n' "${item}"; } > "${file}.tmp.$$"
  mv -f "${file}.tmp.$$" "${file}"
}

# remove_own_pid_file <file>: remove it only if it still names this process.
remove_own_pid_file() {
  local file="$1" pid _rest
  [[ -f "${file}" ]] || return 0
  read -r pid _rest < "${file}" 2>/dev/null || return 0
  [[ "${pid}" == "$$" ]] && rm -f "${file}"
  return 0
}

# pid_file_live <file> <script-name>: prints the pid if the file names a live
# process that is running <script-name> (guards against stale files / pid reuse).
pid_file_live() {
  local file="$1" script="$2" pid _rest
  [[ -f "${file}" ]] || return 1
  read -r pid _rest < "${file}" 2>/dev/null || return 1
  [[ "${pid}" =~ ^[0-9]+$ ]] || return 1
  kill -0 "${pid}" 2>/dev/null || return 1
  tr '\0' ' ' < "/proc/${pid}/cmdline" 2>/dev/null | grep -qF "${script}" || return 1
  printf '%s\n' "${pid}"
}

# descendants <pid>: every descendant pid, depth-first, children before parents.
descendants() {
  local child
  for child in $(pgrep -P "$1" 2>/dev/null); do
    descendants "${child}"
    printf '%s\n' "${child}"
  done
}

# stop_children [grace-seconds]: TERM every descendant of this shell (the headless
# `timeout`/`claude` group, gate/pnpm runs), wait up to the grace, then KILL.
stop_children() {
  local grace="${1:-15}" pids p i
  pids="$(descendants "$$")"
  [[ -z "${pids}" ]] && return 0
  for p in ${pids}; do kill -TERM "${p}" 2>/dev/null || true; done
  for (( i = 0; i < grace * 5; i++ )); do
    local alive=0
    for p in ${pids}; do kill -0 "${p}" 2>/dev/null && { alive=1; break; }; done
    (( alive )) || return 0
    sleep 0.2
  done
  for p in ${pids}; do kill -KILL "${p}" 2>/dev/null || true; done
  return 0
}

# run_interruptible <cmd...>: run in the background and `wait`, so a TERM/INT trap
# in the calling script fires immediately instead of after the child finishes.
# Returns the command's exit status.
run_interruptible() {
  "$@" &
  local child=$! rc=0
  wait "${child}" || rc=$?
  return "${rc}"
}

# release_claim <repo> <worktree> <branch> [remote]: drop a worker claim entirely —
# worktree removed, branch deleted locally and (if a remote is given) remotely.
# The item stays `open` on main; nothing is marked blocked.
release_claim() {
  local repo="$1" wt="$2" branch="$3" remote="${4:-}"
  [[ -n "${wt}" && -d "${wt}" ]] && { git -C "${repo}" worktree remove --force "${wt}" >/dev/null 2>&1 || true; }
  git -C "${repo}" worktree prune >/dev/null 2>&1 || true
  git -C "${repo}" branch -q -D "${branch}" >/dev/null 2>&1 || true
  if [[ -n "${remote}" ]]; then
    git -C "${repo}" push --quiet "${remote}" --delete "${branch}" >/dev/null 2>&1 || true
  fi
  return 0
}

# ollama_ps: prints "<name>\t<size-bytes>\t<size_vram-bytes>" per loaded model.
# Exit 1 if Ollama is unreachable.
ollama_ps() {
  local json
  json="$(curl -fsS --max-time 5 "${OLLAMA_HOST_URL}/api/ps" 2>/dev/null)" || return 1
  python3 -c '
import json, sys
for m in json.loads(sys.argv[1]).get("models") or []:
    print("%s\t%s\t%s" % (m.get("name") or m.get("model"), m.get("size", 0), m.get("size_vram", 0)))
' "${json}"
}

# ollama_unload <model>: ask Ollama to evict it now (keep_alive 0). /api/generate
# works for completion and (on 0.34.x) embedding models; /api/embed with empty
# input is the fallback for servers that refuse generate on an embedding model.
ollama_unload() {
  local model="$1" body
  body="$(python3 -c 'import json,sys; print(json.dumps({"model": sys.argv[1], "keep_alive": 0}))' "${model}")"
  curl -fsS --max-time 60 -o /dev/null "${OLLAMA_HOST_URL}/api/generate" -d "${body}" 2>/dev/null && return 0
  body="$(python3 -c 'import json,sys; print(json.dumps({"model": sys.argv[1], "input": "", "keep_alive": 0}))' "${model}")"
  curl -fsS --max-time 60 -o /dev/null "${OLLAMA_HOST_URL}/api/embed" -d "${body}" 2>/dev/null
}

# gpu_mem: prints "<used-MiB> <total-MiB>" for GPU 0; exit 1 if unavailable.
gpu_mem() {
  command -v "${NVIDIA_SMI_BIN}" >/dev/null 2>&1 || return 1
  "${NVIDIA_SMI_BIN}" --query-gpu=memory.used,memory.total --format=csv,noheader,nounits 2>/dev/null \
    | awk -F', *' 'NR == 1 && $1 ~ /^[0-9]+$/ { print $1, $2; found = 1 } END { exit !found }'
}
