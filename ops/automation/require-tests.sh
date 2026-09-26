#!/usr/bin/env bash
# Usage: ops/automation/require-tests.sh "<test name>" ["<test name>" ...]
# Runs the whole TS suite once (vitest, JSON reporter) and exits 0 only if no test
# failed AND every given name is a substring of at least one PASSED test's full name
# (describe blocks + test title, space-joined). `vitest -t <name>` alone cannot prove a
# named test exists — a filter matching nothing is not evidence — so backlog dod-cmds
# use this instead.
set -euo pipefail
(( $# > 0 )) || { echo "usage: $0 \"<test name>\" ..." >&2; exit 2; }
out="$(mktemp)"; trap 'rm -f "$out"' EXIT
rc=0; pnpm vitest run --reporter=json --outputFile="$out" >/dev/null 2>&1 || rc=$?
python3 - "$out" "$rc" "$@" <<'PY'
import json, sys
path, rc, names = sys.argv[1], int(sys.argv[2]), sys.argv[3:]
try:
    res = json.load(open(path))
except (OSError, ValueError):
    print(f"require-tests: vitest produced no JSON report (exit {rc})"); sys.exit(1)
tests = [a for r in res["testResults"] for a in r["assertionResults"]]
passed = [a["fullName"] for a in tests if a["status"] == "passed"]
failed = [a["fullName"] for a in tests if a["status"] == "failed"]
missing = [n for n in names if not any(n in p for p in passed)]
for f in failed: print(f"FAILED  {f}")
for n in names: print(("MISSING " if n in missing else "ok      ") + n)
sys.exit(0 if rc == 0 and not failed and not missing else 1)
PY
