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
