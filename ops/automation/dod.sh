#!/usr/bin/env bash
# Run the current backlog item's definition-of-done command exactly as worker.sh
# will. worker.sh exports GRAFT_DOD_CMD to the headless session, so the session can
# self-check with one allow-listed call: `ops/automation/dod.sh` (no env prefixes,
# no chaining — the permission allow-list matches on the command's first word).
set -euo pipefail
export PATH="${HOME}/.local/bin:/usr/local/bin:/usr/bin:/bin:${PATH:-}"
cd "$(git rev-parse --show-toplevel)"
if [[ -z "${GRAFT_DOD_CMD:-}" ]]; then
  echo "dod.sh: GRAFT_DOD_CMD is not set (only meaningful inside a worker run)" >&2
  exit 2
fi
bash -euo pipefail -c "${GRAFT_DOD_CMD}"
echo "dod.sh: DoD command exited 0"
