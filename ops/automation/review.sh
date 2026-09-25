#!/usr/bin/env bash
# Graft review pass (SPEC §9): for each open auto/* PR whose current head has no
# graft review yet, run an independent headless review — fresh context, a
# review-specific prompt, read-only tools, never the worker's transcript — and post
# the findings as a PR comment with a looks-good / request-changes verdict.
# Advisory only: it never approves, merges, or pushes.
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

CLAUDE_BIN="${CLAUDE_BIN:-claude}"
GH_BIN="${GH_BIN:-gh}"
REVIEW_TIMEOUT="${REVIEW_CLAUDE_TIMEOUT:-900}"
WT_ROOT="${DATA_DIR}/review-wt"
MARKER_PREFIX="<!-- graft-review head="

render_review_prompt() {
  GRAFT_PR="$1" GRAFT_HEAD_REF="$2" GRAFT_DIFF="$3" GRAFT_GATE="$4" python3 -c '
import os, sys
t = open(sys.argv[1], encoding="utf-8").read()
e = os.environ
for k, v in {"{{PR_NUMBER}}": e["GRAFT_PR"], "{{HEAD_REF}}": e["GRAFT_HEAD_REF"],
             "{{DIFF}}": e["GRAFT_DIFF"], "{{GATE_OUTPUT}}": e["GRAFT_GATE"]}.items():
    t = t.replace(k, v)
sys.stdout.write(t)
' "${AUTOMATION_DIR}/review-prompt.md"
}

review_one() {
  local number="$1" head_ref="$2" head_sha="$3" run_id="$4"
  local wt="${WT_ROOT}/pr-${number}" out_dir="${DATA_DIR}/reviews/${run_id}-pr${number}"
  mkdir -p "${WT_ROOT}" "${out_dir}"
  git -C "${REPO_ROOT}" fetch --quiet origin "${head_ref}"
  git -C "${REPO_ROOT}" worktree add --quiet --detach "${wt}" "${head_sha}"
  trap 'git -C "'"${REPO_ROOT}"'" worktree remove --force "'"${wt}"'" >/dev/null 2>&1 || true' RETURN

  local gate_rc=0
  ( cd "${wt}" && ops/automation/gate.sh --install ) > "${out_dir}/gate.txt" 2>&1 || gate_rc=$?
  local diff; diff="$("${GH_BIN}" pr diff "${number}")"
  printf '%s\n' "${diff}" > "${out_dir}/pr.diff"
  render_review_prompt "${number}" "${head_ref}" "$(head -c 150000 <<< "${diff}")" \
    "exit=${gate_rc}
$(tail -n 40 "${out_dir}/gate.txt")" > "${out_dir}/prompt.md"

  local rc=0
  ( cd "${wt}" && run_with_timeout "${REVIEW_TIMEOUT}" "${CLAUDE_BIN}" -p "$(cat "${out_dir}/prompt.md")" \
      --permission-mode default \
      --allowedTools Read Glob Grep "Bash(git diff:*)" "Bash(git log:*)" "Bash(git show:*)" \
      --disallowedTools Edit Write WebFetch WebSearch "Bash(git push:*)" "Bash(gh:*)" "Bash(curl:*)" \
      --output-format text < /dev/null > "${out_dir}/review.md" 2> "${out_dir}/stderr.txt" ) || rc=$?

  local verdict
  verdict="$(grep -m1 -oE '^Verdict: (looks-good|request-changes)' "${out_dir}/review.md" || true)"
  local body="${out_dir}/comment.md"
  {
    echo "${MARKER_PREFIX}${head_sha} -->"
    if [[ -n "${verdict}" ]]; then
      cat "${out_dir}/review.md"
    else
      echo "Verdict: request-changes"
      echo
      echo "The automated review produced no valid verdict (claude exit ${rc}); treat this PR as unreviewed. Output kept in \`data/automation/reviews/$(basename "${out_dir}")/\`."
    fi
    echo
    echo "_Automated review by \`ops/automation/review.sh\` (fresh context, read-only, advisory). Gate at head: exit ${gate_rc}._"
  } > "${body}"
  "${GH_BIN}" pr comment "${number}" --body-file "${body}" >/dev/null
  log_event "${run_id}" "pr-${number}" reviewed verdict="${verdict#Verdict: }" claude_exit="${rc}" gate_exit="${gate_rc}" head="${head_sha:0:12}"
}

main() {
  local run_id; run_id="review-$(new_run_id)"
  if is_paused; then log_event "${run_id}" - paused; echo "paused"; return 0; fi
  if ! claude_logged_in "${CLAUDE_BIN}"; then
    log_event "${run_id}" - infra-error reason=claude-not-logged-in exit=1; return 1
  fi
  mkdir -p "${DATA_DIR}"
  exec 8> "${DATA_DIR}/review.lock"
  if ! flock -n 8; then log_event "${run_id}" - busy; return 0; fi

  local prs
  prs="$("${GH_BIN}" pr list --state open --json number,headRefName,headRefOid \
    --jq '.[] | select(.headRefName | startswith("auto/")) | "\(.number)\t\(.headRefName)\t\(.headRefOid)"')"
  [[ -z "${prs}" ]] && { log_event "${run_id}" - idle; return 0; }

  local number head_ref head_sha
  while IFS=$'\t' read -r number head_ref head_sha; do
    if "${GH_BIN}" pr view "${number}" --json comments --jq '.comments[].body' | grep -qF "${MARKER_PREFIX}${head_sha}"; then
      continue
    fi
    review_one "${number}" "${head_ref}" "${head_sha}" "${run_id}" || log_event "${run_id}" "pr-${number}" review-error
  done <<< "${prs}"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then main "$@"; fi
