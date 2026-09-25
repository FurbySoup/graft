#!/usr/bin/env bash
# The single definition of "green" for Graft: the same checks gate git commits
# (githooks/pre-commit), worker iterations, CI and the review pass.
# Usage: gate.sh [--install]   (--install runs a frozen, offline pnpm install first)
set -euo pipefail
export PATH="${HOME}/.local/bin:/usr/local/bin:/usr/bin:/bin:${PATH:-}"
root="$(git rev-parse --show-toplevel)"
cd "${root}"
if [[ "${1:-}" == "--install" ]]; then
  # Concurrent offline installs race on the shared pnpm store (observed: worker and
  # reviewer overlapping). Serialise them machine-wide.
  lock="${XDG_CACHE_HOME:-${HOME}/.cache}/graft-pnpm-install.lock"
  mkdir -p "$(dirname "${lock}")"
  flock "${lock}" pnpm install --frozen-lockfile --offline --reporter=silent
fi
pnpm typecheck
pnpm lint
pnpm test
py="sidecars/calibrate/.venv/bin/python"
if [[ ! -x "${py}" ]]; then
  # Worktrees do not carry the gitignored venv; the sidecar is stdlib-only, so the
  # system interpreter is equivalent until third-party deps are approved.
  py="python3"
fi
"${py}" -m unittest discover -s sidecars/calibrate/tests -t sidecars/calibrate
