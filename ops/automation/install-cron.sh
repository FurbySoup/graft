#!/usr/bin/env bash
# Install (or refresh) Graft's automation cron block. Idempotent: replaces the block
# between the BEGIN/END markers and leaves every other crontab line untouched.
#   install-cron.sh            install / refresh
#   install-cron.sh --remove   remove the block
# Schedule (local time): worker every 30 min 00:00–06:30 (one item per run, many
# short runs, no daemon); review pass at :15/:45 00:15–07:45. Pause without
# uninstalling: `touch ops/automation/pause` (both scripts exit immediately).
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
begin="# BEGIN graft-automation"
end="# END graft-automation"
current="$(crontab -l 2>/dev/null || true)"
stripped="$(printf '%s\n' "${current}" | awk -v b="${begin}" -v e="${end}" '$0==b{skip=1;next} $0==e{skip=0;next} !skip')"
if [[ "${1:-}" == "--remove" ]]; then
  printf '%s\n' "${stripped}" | sed '/^$/N;/^\n$/D' | crontab -
  echo "graft automation cron block removed"; exit 0
fi
mkdir -p "${root}/data/automation"
block="${begin}
*/30 0-6 * * * cd ${root} && timeout 3h ops/automation/worker.sh >> data/automation/cron.log 2>&1
15,45 0-7 * * * cd ${root} && timeout 1h ops/automation/review.sh >> data/automation/cron.log 2>&1
${end}"
printf '%s\n%s\n' "${stripped}" "${block}" | sed '/./,$!d' | crontab -
crontab -l | awk -v b="${begin}" -v e="${end}" '$0==b{p=1} p{print} $0==e{p=0}'
