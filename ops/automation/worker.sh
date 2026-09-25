#!/usr/bin/env bash
# Graft backlog worker (SPEC §9). One short run per invocation, designed for cron:
#   pause flag? → lock → pick first eligible BACKLOG item → branch auto/<id> in a
#   worktree → claim → headless Claude Code (≤ MAX_ATTEMPTS, each under a wall-clock
#   budget) → exclusion check → gate + DoD → push + PR, or mark blocked (no PR).
# It NEVER merges and never pushes to main.
#
# Pause (ops/scripts/graft pause): the flag is checked at start and before every
# attempt (soft: the in-flight attempt finishes, then the claim is released). While
# running, the pid (and, once selected, the item) is in data/automation/worker.pid;
# SIGTERM/SIGINT (graft pause --hard) stops the headless session and releases the
# claim — item stays open, branch deleted local + remote, exit 0.
#
# Usage: worker.sh [--dry-run]
#   --dry-run   print the item that would be selected and exit (no side effects)
#
# Tunables (env): WORKER_MAX_ATTEMPTS (5), WORKER_CLAUDE_TIMEOUT seconds per
# attempt (1200), WORKER_RUN_DEADLINE seconds for the whole run (7200),
# CLAUDE_BIN (claude), GH_BIN (gh), WORKER_REMOTE (origin), WORKER_BASE (main).
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

MAX_ATTEMPTS="${WORKER_MAX_ATTEMPTS:-5}"
CLAUDE_TIMEOUT="${WORKER_CLAUDE_TIMEOUT:-1200}"
RUN_DEADLINE="${WORKER_RUN_DEADLINE:-7200}"
CLAUDE_BIN="${CLAUDE_BIN:-claude}"
GH_BIN="${GH_BIN:-gh}"
REMOTE="${WORKER_REMOTE:-origin}"
BASE="${WORKER_BASE:-main}"
WT_ROOT="${DATA_DIR}/wt"

# Tools the headless session may use. Everything else is denied in -p mode.
ALLOWED_TOOLS=(
  Read Edit Write Glob Grep TodoWrite
  "Bash(pnpm:*)" "Bash(npx tsc:*)" "Bash(npx vitest:*)" "Bash(npx eslint:*)"
  "Bash(python3 -m unittest:*)" "Bash(sidecars/calibrate/.venv/bin/python:*)"
  "Bash(ops/automation/gate.sh:*)"
  "Bash(git status:*)" "Bash(git diff:*)" "Bash(git log:*)" "Bash(git show:*)"
  "Bash(git add:*)" "Bash(git commit:*)" "Bash(git restore:*)" "Bash(git rm:*)"
  "Bash(ls:*)" "Bash(cat:*)" "Bash(head:*)" "Bash(tail:*)" "Bash(wc:*)"
  "Bash(grep:*)" "Bash(find:*)" "Bash(mkdir:*)" "Bash(sed -n:*)"
)
DISALLOWED_TOOLS=(
  WebFetch WebSearch
  "Bash(git push:*)" "Bash(git checkout:*)" "Bash(git switch:*)" "Bash(git reset:*)"
  "Bash(git rebase:*)" "Bash(git merge:*)" "Bash(git branch:*)" "Bash(git worktree:*)"
  "Bash(git commit --no-verify:*)" "Bash(git commit -n:*)"
  "Bash(gh:*)" "Bash(curl:*)" "Bash(wget:*)" "Bash(ssh:*)" "Bash(sudo:*)"
)

has_remote() { git -C "${REPO_ROOT}" remote get-url "${REMOTE}" >/dev/null 2>&1; }

# All existing auto/* branch names, local and remote, one per line.
existing_branches() {
  git -C "${REPO_ROOT}" for-each-ref --format='%(refname:short)' refs/heads/auto/
  if has_remote; then
    git -C "${REPO_ROOT}" ls-remote --heads "${REMOTE}" 'auto/*' | awk '{ sub("refs/heads/", "", $2); print $2 }'
  fi
}

base_ref() { if has_remote; then printf '%s/%s' "${REMOTE}" "${BASE}"; else printf '%s' "${BASE}"; fi; }

render_prompt() {
  local item="$1" block="$2" dod="$3" attempt="$4" feedback="$5" phase="$6"
  GRAFT_ITEM_ID="${item}" GRAFT_RUN_ID="${RUN_ID}" GRAFT_ATTEMPT="${attempt}" \
  GRAFT_MAX_ATTEMPTS="${MAX_ATTEMPTS}" GRAFT_PHASE="${phase}" GRAFT_ITEM_BLOCK="${block}" \
  GRAFT_DOD_CMD="${dod}" GRAFT_FEEDBACK="${feedback}" \
  python3 -c '
import os, sys
t = open(sys.argv[1], encoding="utf-8").read()
e = os.environ
subs = {
    "{{ITEM_ID}}": e["GRAFT_ITEM_ID"], "{{RUN_ID}}": e["GRAFT_RUN_ID"],
    "{{BRANCH}}": "auto/" + e["GRAFT_ITEM_ID"], "{{ATTEMPT}}": e["GRAFT_ATTEMPT"],
    "{{MAX_ATTEMPTS}}": e["GRAFT_MAX_ATTEMPTS"], "{{PHASE}}": e["GRAFT_PHASE"],
    "{{ITEM_BLOCK}}": e["GRAFT_ITEM_BLOCK"], "{{DOD_CMD}}": e["GRAFT_DOD_CMD"],
    "{{FEEDBACK}}": e["GRAFT_FEEDBACK"],
}
for k, v in subs.items():
    t = t.replace(k, v)
sys.stdout.write(t)
' "${AUTOMATION_DIR}/task-prompt.md"
}

# run_claude <worktree> <prompt-file> <transcript-file>: one headless attempt.
run_claude() {
  local wt="$1" prompt_file="$2" transcript="$3"
  ( cd "${wt}" && run_with_timeout "${CLAUDE_TIMEOUT}" "${CLAUDE_BIN}" -p "$(cat "${prompt_file}")" \
      --permission-mode acceptEdits \
      --allowedTools "${ALLOWED_TOOLS[@]}" \
      --disallowedTools "${DISALLOWED_TOOLS[@]}" \
      --output-format json < /dev/null > "${transcript}" 2>&1 )
}

# verify <worktree> <dod-cmd> <out-file>: gate + DoD, output captured for feedback.
verify() {
  local wt="$1" dod="$2" out="$3"
  (
    cd "${wt}"
    echo "## gate"
    ops/automation/gate.sh --install
    echo "## dod"
    bash -euo pipefail -c "${dod}"
  ) > "${out}" 2>&1
}

cleanup_worktree() {
  local wt="$1"
  [[ -d "${wt}" ]] && git -C "${REPO_ROOT}" worktree remove --force "${wt}" >/dev/null 2>&1 || true
}

claim_remote() { if has_remote; then printf '%s' "${REMOTE}"; fi; }

# Run state the signal/exit handlers need (globals: traps run outside main's scope).
CUR_ITEM="" CUR_BRANCH="" CUR_WT="" CUR_ATTEMPT=0 FINALIZING=0 STOP_REQUESTED=0

on_exit() {
  [[ -n "${CUR_WT}" ]] && cleanup_worktree "${CUR_WT}"
  remove_own_pid_file "${WORKER_PID_FILE}"
}

# SIGTERM/SIGINT (graft pause --hard): stop the session, release the claim, exit 0.
# Once the run is finalising (success push / PR, or blocked commit) the signal is
# deferred instead, so a finished result is never half-written.
on_signal() {
  if (( FINALIZING )); then STOP_REQUESTED=1; return 0; fi
  trap '' TERM INT
  stop_children 15
  if [[ -n "${CUR_BRANCH}" ]]; then
    release_claim "${REPO_ROOT}" "${CUR_WT}" "${CUR_BRANCH}" "$(claim_remote)"
    CUR_WT=""
    log_event "${RUN_ID}" "${CUR_ITEM:--}" end status=paused signal=term attempts="${CUR_ATTEMPT}" claim=released exit=0
    echo "stopped by signal: claim on ${CUR_ITEM} released" >&2
  else
    log_event "${RUN_ID}" "${CUR_ITEM:--}" end status=paused signal=term claim=none exit=0
    echo "stopped by signal before claiming" >&2
  fi
  remove_own_pid_file "${WORKER_PID_FILE}"
  exit 0
}

main() {
  local dry_run=0
  [[ "${1:-}" == "--dry-run" ]] && dry_run=1
  RUN_ID="$(new_run_id)"
  local start_epoch; start_epoch="$(date +%s)"

  if is_paused; then log_event "${RUN_ID}" - paused; echo "paused"; return 0; fi

  mkdir -p "${DATA_DIR}"
  exec 9> "${DATA_DIR}/worker.lock"
  if ! flock -n 9; then log_event "${RUN_ID}" - busy; echo "another worker run holds the lock"; return 0; fi
  write_pid_file "${WORKER_PID_FILE}" "${RUN_ID}"
  trap on_exit EXIT
  trap on_signal TERM INT

  has_remote && git -C "${REPO_ROOT}" fetch --quiet --prune "${REMOTE}"
  local base; base="$(base_ref)"
  local backlog_snapshot; backlog_snapshot="$(mktemp)"
  if [[ -n "${WORKER_BACKLOG_FILE:-}" ]]; then
    cp "${WORKER_BACKLOG_FILE}" "${backlog_snapshot}"   # tests / dry runs only
  else
    git -C "${REPO_ROOT}" show "${base}:BACKLOG.md" > "${backlog_snapshot}"
  fi
  local branches; branches="$(mktemp)"
  existing_branches > "${branches}"

  local item
  if ! item="$(select_item "${backlog_snapshot}" "${branches}")"; then
    log_event "${RUN_ID}" - idle; echo "no eligible item"; return 0
  fi
  local dod phase block
  dod="$(item_field "${backlog_snapshot}" "${item}" dod-cmd)"
  phase="$(item_field "${backlog_snapshot}" "${item}" phase)"
  block="$(item_block "${backlog_snapshot}" "${item}")"
  if [[ "${dry_run}" == 1 ]]; then echo "${item}"; return 0; fi
  CUR_ITEM="${item}"
  write_pid_file "${WORKER_PID_FILE}" "${RUN_ID}" "${item}"
  if ! claude_logged_in "${CLAUDE_BIN}"; then
    log_event "${RUN_ID}" - infra-error reason=claude-not-logged-in exit=1
    echo "claude CLI is not logged in (run: claude auth login); nothing claimed" >&2
    return 1
  fi

  if [[ -z "${dod}" ]]; then
    log_event "${RUN_ID}" "${item}" skipped reason=no-dod-cmd
    echo "item ${item} has no dod-cmd; the worker only runs machine-checkable items"; return 0
  fi

  log_event "${RUN_ID}" "${item}" start base="${base}"
  local branch="auto/${item}" wt="${WT_ROOT}/${item}" run_dir="${DATA_DIR}/runs/${RUN_ID}"
  mkdir -p "${WT_ROOT}" "${run_dir}"
  # select_item guarantees no auto/<id> branch existed, so from here it is ours to release.
  CUR_BRANCH="${branch}" CUR_WT="${wt}"
  git -C "${REPO_ROOT}" worktree add --quiet -b "${branch}" "${wt}" "${base}"

  # Claim: status → claimed on the branch; pushing the branch is the lock.
  run_interruptible bash -c 'cd "$1" && mkdir -p "$2" && flock "$2/graft-pnpm-install.lock" pnpm install --frozen-lockfile --offline --reporter=silent' \
    _ "${wt}" "${XDG_CACHE_HOME:-${HOME}/.cache}"
  set_item_status "${wt}/BACKLOG.md" "${item}" claimed "claimed-by: ${RUN_ID}"
  git -C "${wt}" add BACKLOG.md
  git -C "${wt}" commit --quiet -m "chore(backlog): claim ${item} (${RUN_ID})"
  local claim_sha; claim_sha="$(git -C "${wt}" rev-parse HEAD)"
  has_remote && git -C "${wt}" push --quiet -u "${REMOTE}" "${branch}"
  log_event "${RUN_ID}" "${item}" claimed sha="${claim_sha:0:12}"

  local attempt=0 outcome="" feedback="" verify_out
  while (( attempt < MAX_ATTEMPTS )); do
    # Soft pause: the previous attempt was allowed to finish; start no new one.
    if is_paused; then outcome="paused"; break; fi
    attempt=$(( attempt + 1 )); CUR_ATTEMPT="${attempt}"
    if (( $(date +%s) - start_epoch > RUN_DEADLINE )); then outcome="run-deadline"; break; fi
    local prompt_file="${run_dir}/prompt-${attempt}.md" transcript="${run_dir}/claude-${attempt}.json"
    render_prompt "${item}" "${block}" "${dod}" "${attempt}" "${feedback}" "${phase}" > "${prompt_file}"
    local rc=0
    run_interruptible run_claude "${wt}" "${prompt_file}" "${transcript}" || rc=$?
    log_event "${RUN_ID}" "${item}" attempt n="${attempt}" claude_exit="${rc}"
    [[ "${rc}" == 124 || "${rc}" == 137 ]] && log_event "${RUN_ID}" "${item}" timeout n="${attempt}" secs="${CLAUDE_TIMEOUT}"
    if [[ "${rc}" != 0 && "${rc}" != 124 && "${rc}" != 137 ]]; then
      # The session itself failed (auth, CLI crash, API outage) — that says nothing
      # about the item. Release the claim entirely and leave the item open.
      outcome="infra-error"; break
    fi

    mapfile -t touched < <(changed_paths "${wt}" "${claim_sha}")
    local violations
    if ! violations="$(exclusion_violations "${wt}" "${touched[@]}")"; then
      log_event "${RUN_ID}" "${item}" exclusion-violation paths="$(tr '\n' ',' <<< "${violations}")"
      printf '%s\n' "${violations}" > "${run_dir}/violations.txt"
      outcome="exclusion-violation"; break
    fi

    verify_out="${run_dir}/verify-${attempt}.txt"
    if run_interruptible verify "${wt}" "${dod}" "${verify_out}"; then outcome="green"; break; fi
    log_event "${RUN_ID}" "${item}" red n="${attempt}"
    feedback="## Previous attempt failed verification (attempt ${attempt})

The worker ran the gate and the DoD command after your last attempt. Last lines:

\`\`\`
$(tail -n 60 "${verify_out}")
\`\`\`

Fix the cause. Do not weaken tests or checks."
  done
  [[ -z "${outcome}" ]] && outcome="iteration-cap"

  if [[ "${outcome}" == "paused" ]]; then
    trap '' TERM INT
    release_claim "${REPO_ROOT}" "${wt}" "${branch}" "$(claim_remote)"
    CUR_WT=""
    log_event "${RUN_ID}" "${item}" end status=paused attempts="${attempt}" claim=released exit=0
    echo "paused: stopped before attempt $(( attempt + 1 )); claim on ${item} released"
    return 0
  fi

  # Past this point the run records a result; a stop signal waits for it (see on_signal).
  FINALIZING=1

  if [[ "${outcome}" == "infra-error" ]]; then
    release_claim "${REPO_ROOT}" "${wt}" "${branch}" "$(claim_remote)"
    CUR_WT=""
    log_event "${RUN_ID}" "${item}" end status=infra-error claude_exit="${rc}" attempts="${attempt}" claim=released exit=1
    echo "infra-error: headless session failed (exit ${rc}); claim on ${item} released" >&2
    return 1
  fi

  if [[ "${outcome}" == "green" ]]; then
    # Commit anything the session left uncommitted (the pre-commit hook re-gates it).
    if [[ -n "$(git -C "${wt}" status --porcelain)" ]]; then
      git -C "${wt}" add -A
      git -C "${wt}" commit --quiet -m "chore(${item}): commit remaining worker changes (${RUN_ID})"
    fi
    set_item_status "${wt}/BACKLOG.md" "${item}" done
    git -C "${wt}" add BACKLOG.md
    git -C "${wt}" commit --quiet -m "chore(backlog): ${item} done (${RUN_ID})"
    if has_remote; then
      git -C "${wt}" push --quiet "${REMOTE}" "${branch}"
      local body="${run_dir}/pr-body.md"
      {
        echo "**${item}: definition of done passes and the gate is green after ${attempt} attempt(s); safe to review — nothing merges without you.**"
        echo
        echo "- DoD command (run by worker.sh, exit 0): \`${dod}\`"
        echo "- Gate: \`ops/automation/gate.sh\` green (typecheck, lint, TS tests, Python tests)"
        echo "- Hard-exclusion check: passed"
        echo "- Run: \`${RUN_ID}\` · log: \`data/automation/runs/${RUN_ID}/\`"
        echo
        echo "### Files touched"
        git -C "${wt}" diff --name-only "${base}" HEAD | sed 's/^/- `/; s/$/`/'
        echo
        echo "### Test output (tail)"
        echo '```'
        tail -n 25 "${run_dir}/verify-${attempt}.txt"
        echo '```'
        echo
        echo "### Backlog item"
        echo '```'
        printf '%s\n' "${block}"
        echo '```'
        echo
        echo "🤖 Generated with [Claude Code](https://claude.com/claude-code)"
      } > "${body}"
      local pr_url
      pr_url="$("${GH_BIN}" pr create --base "${BASE}" --head "${branch}" \
        --title "${item}: $(item_block "${backlog_snapshot}" "${item}" | head -1 | sed 's/^### [^·]*· //')" \
        --body-file "${body}")"
      log_event "${RUN_ID}" "${item}" pr url="${pr_url}"
    fi
    log_event "${RUN_ID}" "${item}" end status=success attempts="${attempt}" exit=0
    echo "success: ${item}"
    return 0
  fi

  # Blocked: keep the evidence, drop the red/excluded working changes, record why.
  git -C "${wt}" diff "${claim_sha}" > "${run_dir}/abandoned.diff" 2>/dev/null || true
  git -C "${wt}" reset --quiet --hard "${claim_sha}"
  git -C "${wt}" clean -fdq
  local reason="${outcome} after ${attempt} attempt(s); evidence in data/automation/runs/${RUN_ID}/"
  set_item_status "${wt}/BACKLOG.md" "${item}" blocked "blocked: ${reason}"
  cat >> "${wt}/PROGRESS.md" <<EOF

## $(date -u +%Y-%m-%d) · worker ${RUN_ID} · Phase ${phase}
**Answer:** ${item} is BLOCKED — ${outcome}; no PR opened.
- Changed: nothing merged; item marked \`status: blocked\` on \`${branch}\`.
- Exit criteria: n/a (single item).
- Next action: Mark reviews \`data/automation/runs/${RUN_ID}/\` (prompts, transcripts, verify output, abandoned.diff) and re-grooms ${item}.
- Blockers: ${reason}
EOF
  git -C "${wt}" add BACKLOG.md PROGRESS.md
  git -C "${wt}" commit --quiet -m "chore(backlog): ${item} blocked — ${outcome} (${RUN_ID})"
  has_remote && git -C "${wt}" push --quiet "${REMOTE}" "${branch}"
  log_event "${RUN_ID}" "${item}" end status=blocked reason="${outcome}" attempts="${attempt}" exit=0
  echo "blocked: ${item} (${outcome})"
  return 0
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then main "$@"; fi
