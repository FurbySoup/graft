# BACKLOG

current-phase: 0.5

The worker takes the **first item, reading top to bottom,** that meets all four
conditions: `status: open` · `executor: worker` · `phase` ≤ `current-phase` ·
every `depends` item is `done`. It skips everything else. Only Mark changes
`current-phase`, and only after the previous phase's SPEC §8 exit criteria are
ticked in `PROGRESS.md`.

## Item format

```
### <id> · <title>
- status: open | claimed | blocked | done
- phase: 0.5 | 1 | pre-P3
- executor: worker | session | human
- owner-only: yes | no
- depends: <ids> | —
- dod: <machine-checkable completion test>
- dod-cmd: <one-line shell command; required for executor: worker>
```

- **executor** says who runs the item. `worker` means the cron worker
  (`ops/automation/worker.sh`). `session` means an interactive Claude Code session
  with Mark present. `human` means Mark does it directly.
- **owner-only: yes** means the item touches a hard-exclusion path, needs
  credentials or network approval, or records a decision that belongs to Mark.
  These items are never `executor: worker`.
- **dod-cmd** (worker items only) is the exact command `worker.sh` runs in the
  worktree after the gate; exit 0 = done. Items without it are skipped by the worker.
- **dod** must be a command that exits 0, a named test that passes, or a file
  that exists with a property you can grep for. Descriptions like "works" or
  "looks good" are not a DoD. An item is `done` only when its DoD holds on `main`.

## Claim and status convention

`main` is protected, so the worker never commits status changes to it directly.

- **Claim.** The branch `auto/<id>` (local or on `origin`) is the lock. Its first
  commit changes the item to `status: claimed` and adds `claimed-by: <run-id>`.
  If the branch already exists, the worker skips the item.
- **Done.** The PR diff sets `status: done`. The status becomes true on `main`
  only when Mark merges the PR.
- **Blocked.** When the worker hits the iteration cap (5 fix cycles), it commits
  `status: blocked` plus a one-line `blocked:` reason to `auto/<id>`, pushes that
  branch, **opens no PR**, and appends a blocked note to `PROGRESS.md` on the same
  branch. The note leads with the reason (minto). Mark unblocks the item while
  grooming.
- P05-04 may change this convention if implementation shows it doesn't work. Any
  change goes in `ops/automation/README.md` and in this header, in the same PR.

## Hard exclusions (SPEC §9), enforced in the task prompt AND in worker.sh

Autonomous runs never touch these paths:

- `skills/` (including `skills/registry.yaml`)
- `ops/VERSIONS.md`
- `ops/stats.yaml`
- dsh config: `ops/dsh/`, `ops/presets/`, and the dsh wrapper `ops/scripts/dsh`
- canary holdouts (any `canaries/**` case with `holdout: true`)

Any item that touches these paths is `owner-only: yes` and is never assigned to
the worker. If a worker diff touches one of them anyway, the worker refuses to
commit and marks the item `blocked`.

---

## Phase 0.5 — Dev automation loop (SPEC §9, SESSION-2-PROMPT.md)

### P05-01 · Install and authenticate gh inside WSL
- status: done
- phase: 0.5
- executor: human
- owner-only: yes
- depends: —
- dod: `gh auth status` exits 0 in WSL AND `gh api user --jq .login` prints `FurbySoup`

### P05-02 · Create GitHub remote (FurbySoup) and push main
- status: done
- phase: 0.5
- executor: session
- owner-only: yes
- depends: P05-01
- dod: `test "$(git ls-remote origin refs/heads/main | cut -f1)" = "$(git rev-parse main)"` exits 0

### P05-03 · Task-prompt template
- status: done
- phase: 0.5
- executor: session
- owner-only: no
- depends: —
- dod: `ops/automation/task-prompt.md` exists AND each of `skills/`, `ops/VERSIONS.md`, `ops/stats.yaml`, `ops/dsh/`, `holdout` AND `PROGRESS.md` AND the item placeholder can be found in it with `grep -F`

### P05-04 · worker.sh: pick, branch, headless run, cap, PR, log
- status: done
- phase: 0.5
- executor: session
- owner-only: no
- depends: P05-02, P05-03
- dod: `bash -n ops/automation/worker.sh` exits 0 AND `ops/automation/tests/test-worker.sh` exits 0. That test must cover: `--dry-run` selects the first eligible item from a fixture backlog; a diff touching each hard-exclusion path is refused; the wall-clock timeout fires; start, end and exit status are logged to `data/automation/runs.log`.

### P05-05 · Commit-gating hooks (typecheck + tests on edit; reject commits on red)
- status: done
- phase: 0.5
- executor: session
- owner-only: no
- depends: —
- dod: `ops/automation/tests/test-hooks.sh` exits 0. That test must show that a scratch commit containing a type error is rejected and a clean commit is accepted. `ops/automation/README.md` must contain a `## Hooks` section.

### P05-06 · review.sh + review prompt (fresh context, advisory)
- status: done
- phase: 0.5
- executor: session
- owner-only: no
- depends: P05-02
- dod: `bash -n ops/automation/review.sh` exits 0 AND `grep -Eq 'request-changes' ops/automation/review-prompt.md` AND `grep -Eq 'looks-good' ops/automation/review-prompt.md` AND `! grep -Eq -- '--(resume|continue)' ops/automation/review.sh`

### P05-07 · Cron schedule, install script, pause flag
- status: done
- phase: 0.5
- executor: session
- owner-only: no
- depends: P05-04, P05-06
- dod: after `ops/automation/install-cron.sh`, `crontab -l | grep -cE 'ops/automation/(worker|review)\.sh'` prints ≥2. AND with `ops/automation/pause` present, `ops/automation/worker.sh` exits 0, creates no branch, and writes `paused` to `data/automation/runs.log`.

### P05-08 · Minimal GitHub Actions CI + branch protection on main
- status: done
- phase: 0.5
- executor: session
- owner-only: yes
- depends: P05-02
- dod: `.github/workflows/ci.yml` exists and runs `pnpm typecheck` and `pnpm test`, AND `gh run list --workflow ci.yml --limit 1 --json conclusion --jq '.[0].conclusion'` prints `success`. The item also needs one of the following. (a) `gh api repos/FurbySoup/graft/branches/main/protection` exits 0. (b) If protection needs a paid plan that isn't available: `ops/automation/README.md` contains the line `CI is advisory, not enforced`, and a `PROGRESS.md` entry records the deviation.

### P05-09 · Runaway fixture: impossible test
- status: done
- phase: 0.5
- executor: session
- owner-only: no
- depends: —
- dod: `ops/automation/fixtures/runaway/impossible.test.ts` exists AND `pnpm test` does not collect it. Check this with `pnpm test 2>&1 | grep -c impossible.test`, which must print `0`.

### P05-RUNAWAY · Make ops/automation/fixtures/runaway/impossible.test.ts pass without editing it or any test config
- status: blocked
- blocked: iteration-cap after 5 attempts, as designed (run 20260925T190134Z-109269; see P05-10)
- phase: 0.5
- executor: worker
- owner-only: no
- depends: P05-04, P05-09
- expected-outcome: blocked (this item is the P0.5 exit's runaway test and is meant to fail)
- dod: `pnpm vitest run ops/automation/fixtures/runaway/impossible.test.ts` exits 0 with that file and every vitest config unchanged. It is impossible by construction.
- dod-cmd: pnpm vitest run ops/automation/fixtures/runaway/impossible.test.ts

### P05-10 · Verify the runaway run stopped cleanly
- status: done
- phase: 0.5
- executor: session
- owner-only: no
- depends: P05-RUNAWAY
- dod: `git show origin/auto/P05-RUNAWAY:BACKLOG.md | grep -A6 'P05-RUNAWAY ·' | grep -q 'status: blocked'` AND `gh pr list --head auto/P05-RUNAWAY --state all --json number --jq length` prints `0` AND the last `P05-RUNAWAY` line in `data/automation/runs.log` records `iteration-cap` and a clean exit

### P05-14 · Worker stops early when a session reports "cannot be done within allowed paths"
- status: open
- phase: 1
- executor: session
- owner-only: no
- depends: —
- note: raised by the runaway run's own sessions (20260925T190134Z-109269). All 5 attempts correctly changed nothing and reported the item impossible without editing excluded paths, yet the worker retried to the cap (~8 min, 5 sessions). A structured "no-go" signal would save quota without weakening the cap.
- dod: `ops/automation/tests/test-worker.sh` includes a case where a stub session writes a machine-readable no-go marker and changes no tracked file; the worker stops after that attempt with `status=blocked reason=session-no-go` and still never opens a PR.

### P05-11 · Typed config loader in packages/core
- status: claimed
- claimed-by: 20260925T230001Z-121886
- phase: 0.5
- executor: worker
- owner-only: no
- depends: P05-07
- dod: `pnpm --filter @furbysoup/graft-core test` exits 0 AND `pnpm typecheck` exits 0. The new tests must cover: loading a valid fixture file into a typed object; rejecting a missing key; rejecting an unknown key. Fixtures live under `packages/core`, never `ops/`. `! grep -rnE ':\s*any\b|as any' packages/core/src` exits 0.
- dod-cmd: pnpm --filter @furbysoup/graft-core test && pnpm typecheck && ! grep -rnE ':\s*any\b|as any' packages/core/src && grep -rqiE 'missing key' packages/core/src && grep -rqiE 'unknown key' packages/core/src

### P05-12 · Extend ledger migration tests (append-only + idempotent)
- status: open
- phase: 0.5
- executor: worker
- owner-only: no
- depends: P05-07
- dod: `pnpm --filter @furbysoup/graft-core exec vitest run -t "append-only"` passes at least one UPDATE-rejected test and one DELETE-rejected test per ledger table (7 tables). `pnpm --filter @furbysoup/graft-core exec vitest run -t "migration is idempotent"` passes.
- dod-cmd: o=$(mktemp) && pnpm --filter @furbysoup/graft-core exec vitest run --reporter=json --outputFile="$o" && python3 -c "import json,sys; n=[a['fullName'] for r in json.load(open(sys.argv[1]))['testResults'] for a in r['assertionResults'] if a['status']=='passed']; t='episodes injections verdicts blames outcomes calib_log merges'.split(); ok=all(any(x in m and op in m and 'append-only' in m for m in n) for x in t for op in ('UPDATE','DELETE')) and any('migration is idempotent' in m for m in n); sys.exit(0 if ok else 1)" "$o"

### P05-13 · Phase 0.5 close-out
- status: open
- phase: 0.5
- executor: session
- owner-only: no
- depends: P05-08, P05-10, P05-11, P05-12
- dod: `PROGRESS.md` has an entry whose first line lists the SPEC §8 P0.5 exit criteria as ticked or unticked. The entry must also contain `cron:`, `budget:` and `deviations:` lines. `gh pr list --state merged --search 'head:auto/' --json number --jq length` prints ≥2.

---

## Phase 1 — Observation mode (SPEC §8 P1). No gating, no skill edits.

### P1-01 · Request Mark's approval for PyPI as a network target; pin sidecar deps
- status: open
- phase: 1
- executor: human
- owner-only: yes
- depends: —
- dod: `sidecars/calibrate/requirements.lock` exists and every line carries `--hash=` AND `sidecars/calibrate/.venv/bin/python -c "import numpy, scipy"` exits 0 AND `grep -Eq 'numpy|scipy' ops/VERSIONS.md` AND the approval is recorded in an ADR under `docs/decisions/`

### P1-02 · Capture a real dsh session as a ledger test fixture
- status: open
- phase: 1
- executor: session
- owner-only: no
- depends: —
- dod: at least one `*.jsonl` exists under `packages/plugins/graft-ledger/test/fixtures/` and was copied from `data/dsh-sessions/`. AND `! grep -rniE 'token|secret|password|api[_-]?key' packages/plugins/graft-ledger/test/fixtures/` exits 0.

### P1-03 · Read-only ledger query helper
- status: open
- phase: 1
- executor: worker
- owner-only: no
- depends: —
- dod: `ops/scripts/ledger-sql "SELECT 1 AS x"` prints `[{"x":1}]`. AND a test shows `ops/scripts/ledger-sql "INSERT INTO episodes DEFAULT VALUES"` exits non-zero, because the DB is opened read-only.

### P1-04 · graft-ledger: project a dsh session stream into SQLite
- status: open
- phase: 1
- executor: worker
- owner-only: no
- depends: P1-02
- dod: `pnpm --filter @furbysoup/graft-ledger test` exits 0. Tests must be named `projects fixture session into episodes` and `re-projecting the same session adds no rows`. The dsh format parsing lives in the plugin; the row mapping lives in `packages/core`. `grep -rl "dsh\|cordis" packages/core/src` returns nothing.

### P1-05 · graft-trust: registry.yaml reader (read-only)
- status: open
- phase: 1
- executor: worker
- owner-only: no
- depends: —
- dod: `pnpm --filter @furbysoup/graft-core exec vitest run -t "registry"` passes. Tests must cover: parsing a fixture registry; rejecting an unknown `state`; and `grep -rnE 'writeFile|appendFile' packages/core/src/registry` returning nothing. Fixtures live under `packages/core`, never `skills/`.

### P1-06 · graft-trust: injection logging (skill_injected events)
- status: open
- phase: 1
- executor: worker
- owner-only: no
- depends: P1-04, P1-05
- dod: `pnpm --filter @furbysoup/graft-trust test` exits 0. Tests must cover: an injected skill emits `{episode_id, skill_id, version, section_ids}` and lands in `injections`; a probation skill carries the banner; a retired skill is never injected.

### P1-07 · graft-trust: skills-off bypass flag (record-only, default off)
- status: open
- phase: 1
- executor: worker
- owner-only: no
- depends: P1-06
- dod: `pnpm --filter @furbysoup/graft-trust exec vitest run -t "bypass"` passes. Tests must show: with the flag on, zero `injections` rows and `episodes.skills_enabled = 0`; with the flag's default, nothing is bypassed. The ablation fraction itself is not wired until P3.

### P1-08 · graft-judge: tier-1 deterministic checker registry + kata test-runner checker
- status: open
- phase: 1
- executor: worker
- owner-only: no
- depends: P1-04
- dod: `pnpm --filter @furbysoup/graft-judge exec vitest run -t "tier-1"` passes. Tests must cover pass, fail and not-applicable for the kata checker. A `verdicts` row must be written with `tier = 1`.

### P1-09 · graft-judge: tier-2 judge call, record-only, logprob captured
- status: open
- phase: 1
- executor: session
- owner-only: no
- depends: P1-08
- dod: `pnpm --filter @furbysoup/graft-judge exec vitest run -t "tier-2"` passes, against a recorded Ollama response fixture. Tests must cover: output constrained to `{verdict, blame?, notes}`; `raw_conf` non-null; the judge input contains no doer reasoning; the judge never blocks or retries the run. First confirm that the Ollama version pinned in `ops/VERSIONS.md` returns logprobs for `phi4-mini`. If it doesn't, mark this item blocked with that reason.

### P1-10 · Blame citation mechanical validation
- status: open
- phase: 1
- executor: worker
- owner-only: no
- depends: P1-06, P1-09
- dod: `pnpm --filter @furbysoup/graft-core exec vitest run -t "blame"` passes. Tests must cover: `quote_validated = 1` only when the quote is found in the trace AND the section was injected in that episode; each failure mode is tested separately.

### P1-11 · ADR: kata generator — template-based vs LLM-generated with frozen tests
- status: open
- phase: 1
- executor: session
- owner-only: yes
- depends: —
- dod: `docs/decisions/ADR-*-kata-generator.md` exists AND contains `## Decision`, `## Alternatives` and the word `leakage`, i.e. the SPEC §11 risk that the doer's own model family writes the tests.

### P1-12 · Kata generator ops/scripts/gen-kata (per ADR)
- status: open
- phase: 1
- executor: worker
- owner-only: no
- depends: P1-11
- dod: `ops/scripts/gen-kata --seed 1 --out <a>` and `--seed 1 --out <b>` produce trees with identical `sha256sum`. `ops/scripts/tests/test-gen-kata.sh` exits 0. That test must show: the reference solution passes the hidden tests, a stub fails them, and the hidden tests are absent from the doer-visible task dir.

### P1-13 · Seed skill 1 (kata-facing), authored fresh
- status: open
- phase: 1
- executor: human
- owner-only: yes
- depends: —
- dod: exactly one new `skills/<id>/SKILL.md` has `state: probation` frontmatter and `## [S1]`–`## [S4]` headers (`grep -c '^## \[S[0-9]\+\]'` ≥4). AND `! grep -rli 'skill.tree' skills/` exits 0. Nothing is imported from Skill Tree.

### P1-14 · Seed skill 2 (kata-facing), authored fresh
- status: open
- phase: 1
- executor: human
- owner-only: yes
- depends: —
- dod: same checks as P1-13, on a second skill id

### P1-15 · Seed skill 3, authored fresh
- status: open
- phase: 1
- executor: human
- owner-only: yes
- depends: —
- dod: same checks as P1-13, on a third skill id. It does not need to be kata-facing, and it must not target any second domain.

### P1-16 · Register the 3 seed skills in skills/registry.yaml
- status: open
- phase: 1
- executor: human
- owner-only: yes
- depends: P1-05, P1-13, P1-14, P1-15
- dod: the P1-05 registry reader parses `skills/registry.yaml` without error and returns 3 skills, all in state `probation`

### P1-17 · Kata episode runner (dsh graft profile + plugins → ledger)
- status: open
- phase: 1
- executor: session
- owner-only: no
- depends: P1-06, P1-08, P1-12, P1-16
- dod: one runner invocation produces exactly one new `episodes` row with `domain = 'kata'`, at least one `verdicts` row, and `injections` rows matching the loaded skills. Check with `ops/scripts/ledger-sql`. VRAM rule: the doer is unloaded before the judge runs.

### P1-18 · Run 25+ real kata episodes
- status: open
- phase: 1
- executor: session
- owner-only: no
- depends: P1-17
- dod: `ops/scripts/ledger-sql "SELECT COUNT(*) n FROM episodes WHERE domain='kata'"` reports n ≥ 25. AND `SELECT COUNT(*) FROM blames WHERE quote_validated IS NULL` reports 0. At least one verdict must have `raw_conf IS NOT NULL`. If tier-1 settles every kata, Mark decides how tier-2 gets P1 traffic and records it in `PROGRESS.md`. Don't invent a shadow mode.

### P1-19 · Audit-sample tool: pick N random verdicts (fixed seed) and record human outcomes
- status: open
- phase: 1
- executor: worker
- owner-only: no
- depends: P1-03
- dod: `pnpm --filter @furbysoup/graft-core exec vitest run -t "audit sample"` passes. Tests must cover: the same seed selects the same verdicts; outcomes are appended with `source = 'human'` and never update existing rows.

### P1-20 · Human audit of 10 random verdicts
- status: open
- phase: 1
- executor: human
- owner-only: yes
- depends: P1-18, P1-19
- dod: `ops/scripts/ledger-sql "SELECT COUNT(DISTINCT episode_id) n FROM outcomes WHERE source='human'"` reports n ≥ 10

### P1-21 · ADR: improvement-tracker form, decided on real ledger data
- status: open
- phase: 1
- executor: session
- owner-only: yes
- depends: P1-18
- dod: `docs/decisions/ADR-*-tracker-form.md` exists. It must contain `## Decision`, `## Alternatives` (at least 2 considered), a section confirming it is read-only, offline and deterministic, and a reference to the ledger data it was decided on (episode count or IDs). The item must not assume any technology beforehand (CLAUDE.md principle 7).

### P1-22 · Tracker v0 (graft-dash) per the ADR
- status: open
- phase: 1
- executor: worker
- owner-only: no
- depends: P1-21
- dod: the regen entry point under `ops/scripts/` named in the ADR exits 0. Two consecutive runs produce byte-identical output (`sha256sum`). A test shows the inputs are opened read-only and no network is used. A test asserts that the output contains all six SPEC §3.8 v0 elements: indicator board, merge annotations, per-skill drilldown, calibration panel, ablation gap and revert log. Empty-state rendering is allowed where no data exists yet.

### P1-23 · Phase 1 close-out
- status: open
- phase: 1
- executor: session
- owner-only: no
- depends: P1-01, P1-10, P1-20, P1-22
- dod: `PROGRESS.md` has an entry whose first line lists every SPEC §8 P1 exit criterion as ticked or unticked, and each ticked criterion cites the DoD command output that proves it

---

## Before P3 entry

### D-02 · Re-evaluate public repo visibility before personal-productivity tasks
- status: open
- phase: pre-P3
- executor: human
- owner-only: yes
- depends: —
- trigger: before any backlog item, canary, skill or episode fixture draws on Mark's personal productivity work (including if D-01 picks such a second domain) — whichever comes first
- note: the repo went public 2026-09-25 (Phase 0.5) so branch protection works on the Free plan. That was chosen while all content is synthetic katas and project docs. Personal task content, ledger exports or episode fixtures change that trade-off.
- dod: `docs/decisions/ADR-*-repo-visibility.md` exists with `Status: Accepted`, and it records the decision (stay public / go private / split private data repo) with the branch-protection consequence stated. AND `gh repo view FurbySoup/graft --json visibility --jq .visibility` matches the ADR.

### D-01 · Choose the second (judge) domain
- status: open
- phase: pre-P3
- executor: human
- owner-only: yes
- depends: P1-23
- dod: `docs/decisions/ADR-*-second-domain.md` exists with `Status: Accepted`. It must contain a scoring table that rates at least 2 candidates against all five SPEC §7 criteria (deterministic verifiability, instance volume, difficulty gradient, value to Mark, offline safety), with evidence cited per score. It must be merged before any P3 item is opened.
