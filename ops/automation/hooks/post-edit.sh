#!/usr/bin/env bash
# Claude Code PostToolUse hook (Edit|Write|MultiEdit): after a file edit, typecheck
# and test the package that owns the file, and feed failures straight back to the
# session (exit 2 → stderr is shown to Claude). Commit-time gating is separate
# (githooks/pre-commit runs the full gate). Non-package files are ignored.
set -uo pipefail
export PATH="${HOME}/.local/bin:/usr/local/bin:/usr/bin:/bin:${PATH:-}"
input="$(cat)"
file="$(python3 -c 'import json,sys; d=json.load(sys.stdin); print((d.get("tool_input") or {}).get("file_path",""))' <<< "${input}" 2>/dev/null)"
[[ -z "${file}" ]] && exit 0
root="$(git -C "$(dirname "${file}")" rev-parse --show-toplevel 2>/dev/null)" || exit 0
rel="${file#"${root}"/}"
cd "${root}"
pkg_dir=""
case "${rel}" in
  packages/core/*) pkg_dir="packages/core" ;;
  packages/plugins/*/*) pkg_dir="$(cut -d/ -f1-3 <<< "${rel}")" ;;
  sidecars/calibrate/*)
    py="sidecars/calibrate/.venv/bin/python"; [[ -x "${py}" ]] || py=python3
    if ! out="$("${py}" -m unittest discover -s sidecars/calibrate/tests -t sidecars/calibrate 2>&1)"; then
      printf 'post-edit: sidecar tests failed after editing %s\n%s\n' "${rel}" "$(tail -n 30 <<< "${out}")" >&2; exit 2
    fi
    exit 0 ;;
  *) exit 0 ;;
esac
[[ -f "${pkg_dir}/package.json" ]] || exit 0
if ! out="$(npx tsc -b "${pkg_dir}" 2>&1)"; then
  printf 'post-edit: typecheck failed for %s after editing %s\n%s\n' "${pkg_dir}" "${rel}" "$(tail -n 30 <<< "${out}")" >&2; exit 2
fi
if ! out="$(pnpm vitest run --root "${pkg_dir}" 2>&1)"; then
  printf 'post-edit: tests failed for %s after editing %s\n%s\n' "${pkg_dir}" "${rel}" "$(tail -n 30 <<< "${out}")" >&2; exit 2
fi
exit 0
