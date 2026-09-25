#!/usr/bin/env bash
# Commit gating: in a throwaway clone with the committed hooks installed, a commit
# containing a type error is rejected and a clean commit is accepted. Also checks the
# Claude Code post-edit hook reports a type error back (exit 2) and passes clean edits.
set -uo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo="$(cd "${here}/../../.." && pwd)"
tmp="$(mktemp -d)"; trap 'rm -rf "${tmp}"' EXIT
fails=0
ok()   { printf 'ok   - %s\n' "$1"; }
fail() { printf 'FAIL - %s\n' "$1"; fails=$((fails + 1)); }

clone="${tmp}/clone"
git clone -q "${repo}" "${clone}"
git -C "${clone}" config user.name "Graft Test"; git -C "${clone}" config user.email test@example.invalid
"${clone}/ops/automation/install-hooks.sh" >/dev/null
(cd "${clone}" && pnpm install --frozen-lockfile --offline --reporter=silent) || fail "clone install"

[[ "$(git -C "${clone}" config core.hooksPath)" == "ops/automation/githooks" ]] && ok "install-hooks sets core.hooksPath" || fail "install-hooks sets core.hooksPath"

# red commit is rejected
printf 'export const broken: number = "not a number";\n' > "${clone}/packages/core/src/broken.ts"
git -C "${clone}" add -A
if git -C "${clone}" commit -q -m "test: red" >/dev/null 2>&1; then fail "type error commit rejected"; else ok "type error commit rejected"; fi
[[ "$(git -C "${clone}" rev-list --count HEAD)" == "$(git -C "${repo}" rev-list --count HEAD)" ]] && ok "no commit was created" || fail "no commit was created"

# clean commit is accepted
printf 'export const fine: number = 1;\n' > "${clone}/packages/core/src/broken.ts"
git -C "${clone}" add -A
if git -C "${clone}" commit -q -m "test: green" >/dev/null 2>&1; then ok "clean commit accepted"; else fail "clean commit accepted"; fi

# Claude Code PostToolUse hook
f="${clone}/packages/core/src/broken.ts"
printf 'export const broken: number = "x";\n' > "${f}"
rc=0; printf '{"tool_input":{"file_path":"%s"}}' "${f}" | "${clone}/ops/automation/hooks/post-edit.sh" >/dev/null 2>&1 || rc=$?
[[ "${rc}" == 2 ]] && ok "post-edit hook returns 2 on a type error" || fail "post-edit hook returns 2 on a type error (got ${rc})"
printf 'export const fine: number = 1;\n' > "${f}"
rc=0; printf '{"tool_input":{"file_path":"%s"}}' "${f}" | "${clone}/ops/automation/hooks/post-edit.sh" >/dev/null 2>&1 || rc=$?
[[ "${rc}" == 0 ]] && ok "post-edit hook passes a clean edit" || fail "post-edit hook passes a clean edit (got ${rc})"
grep -q '"PostToolUse"' "${repo}/.claude/settings.json" && ok ".claude/settings.json registers the hook" || fail ".claude/settings.json registers the hook"

echo
if (( fails > 0 )); then echo "${fails} check(s) failed"; exit 1; fi
echo "all checks passed"
