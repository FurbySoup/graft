#!/usr/bin/env bash
# Point this clone (and all its worktrees) at the committed git hooks.
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
git -C "${root}" config core.hooksPath ops/automation/githooks
echo "core.hooksPath=$(git -C "${root}" config core.hooksPath)"
