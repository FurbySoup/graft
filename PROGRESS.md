# PROGRESS

**Every session, human or worker, reads this file first and appends to it last.**
Sessions only append. Earlier entries are never edited. A correction goes in a new
entry that references the date and run id of the entry it corrects.

## Entry format

Follow the minto-pyramid skill. The first line gives the answer: which exit
criteria are ticked and which are not. Put bad news first: a hit iteration cap, a
red check, or a deviation from SPEC.

```
## <YYYY-MM-DD> · <session name | worker run-id> · Phase <n>
**Answer:** <one line: exit-criteria state + the single most important fact>
- Changed: <what landed, with commit SHAs / PR numbers / backlog ids>
- Exit criteria (SPEC §8, current phase): <each one ticked [x] or unticked [ ], with evidence>
- Next action: <one concrete step, naming a backlog id where one exists>
- Blockers: <none | what stopped it, in one sentence, then detail>
```

---

## 2026-09-25 · Session 1 — Phase 0 in progress · Phase 0
**Answer:** Phase 0 is in progress. The exit criteria haven't been checked yet.
- Changed: the starter pack was imported, and SPEC and RISK-REGISTER were moved into `docs/`. The scaffold, pins and smoke tests are underway.
- Exit criteria (SPEC §8, P0): (close-out entry appended at end of session)
- Next action: (close-out entry appended at end of session)
- Blockers: (close-out entry appended at end of session)

## 2026-09-25 · Session 1 close-out · Phase 0
**Answer:** All P0 exit criteria are ticked, but three findings need Mark's attention before Phase 1: the SPEC doer (qwen3.5:9b) was replaced, the doer's usable context is ~2K tokens after dsh overhead, and the judge's logprobs under constrained decoding are not usable as `raw_conf` as-is.
- Changed: commits `8a2caa0`…HEAD on `main` — starter import, docs/ move, `ops/stats.yaml` (standalone `522c408`), workspace + package skeletons, calibrate sidecar, prior-art note, BACKLOG/PROGRESS, directory READMEs, ADR-0001, dsh profiles + doer Modelfile, `ops/VERSIONS.md`, CLAUDE.md state/commands.
- Exit criteria (SPEC §8, P0):
  - [x] WSL2 workspace — `~/graft` on ext4; dsh sandbox `workspace-write`.
  - [x] dsh installed & pinned — 0.1.5-rc.3 exact + frozen lockfile (`ops/VERSIONS.md`).
  - [x] Ollama models pulled & smoke-tested — doer `graft-doer:8k` ~47 tok/s 100% GPU; judge phi4-mini 100% CPU, schema JSON + logprobs; embeddings 1024-dim CPU. **Substitution:** qwen3.5:9b → qwen3:8b (vision-bundled; 12% CPU spill at ~29 tok/s).
  - [x] Monorepo scaffold — `pnpm check` green (10 TS tests), sidecar 6 unittest green.
  - [x] Frozen Minimal preset committed — as profile `ops/presets/graft-replay/` (dsh has profiles, not presets; derived from `sdk-minimal`; composes and boots; not yet driven by an SDK client).
  - [x] BACKLOG.md seeded — Phase 0.5 + Phase 1 + one undecided second-domain item (D-01).
  - [x] One dsh Standard session completes a toy task with all models reachable — exit 0, `hello.md` written, session log captured (65 events). **Caveat:** output would fail tier-1 (literal `\n`, date typed not computed); 5 min wall time; 7 compactions.
  - [x] `ops/VERSIONS.md` records every pin.
- Next action: Mark reviews the three findings below, then starts Phase 0.5 (`SESSION-2-PROMPT.md`), beginning with BACKLOG P05 `gh` install + auth.
- Blockers: none for Phase 0.5. For Phase 1: (1) doer context budget — ~6–6.6K of 8192 tokens is dsh fixed prompt; (2) tier-2 `raw_conf` design — Ollama logprobs are pre-grammar-mask, so the sampled in-schema token can carry p≈0.0001 while the model "meant" `incorrect`; (3) qwen3 thinking mode is on by default via `/v1`.

## 2026-09-26 · worker 20260925T230001Z-121886 · Phase 0.5
**Answer:** DoD passed — the typed config loader landed in `packages/core` (commit `df3cc0b`) with the pre-commit gate green, so `pnpm --filter @furbysoup/graft-core test`, `pnpm typecheck`, the no-`any` grep, and the `missing key` / `unknown key` greps all pass.
- Changed: P05-11 — new `packages/core/src/config/loader.ts` (`loadConfig`/`parseConfig`/`validateConfig` + `ConfigError`, schema-driven, input narrowed from `unknown`, no `any`), its tests, fixture `packages/core/src/config/fixtures/valid.json`, and the `@furbysoup/graft-core` barrel exports. Commit `df3cc0b`.
- Exit criteria (this is a backlog item, not a phase gate) — DoD sub-checks:
  - [x] `pnpm --filter @furbysoup/graft-core test` exits 0 — verified via the pre-commit gate (`ops/automation/gate.sh`) accepting `df3cc0b`.
  - [x] `pnpm typecheck` exits 0 — same gate; PostToolUse typecheck hook also green after the barrel export was added.
  - [x] tests cover valid-fixture load into a typed object, missing key, and unknown key (plus wrong-type, non-object, invalid-JSON).
  - [x] fixture lives under `packages/core`, not `ops/`.
  - [x] `! grep -rnE ':\s*any\b|as any' packages/core/src` — no matches (Grep tool).
  - [x] `grep -rqiE 'missing key' / 'unknown key' packages/core/src` — both present in `loader.ts`.
- Next action: P05-12 (extend ledger migration tests) or P05-13 (Phase 0.5 close-out) per BACKLOG.
- Blockers: none. Note: in this sandbox the `pnpm` DoD sub-commands required approval to run directly; they were exercised through the pre-commit gate, which runs the identical typecheck/lint/test and rejects red commits.

## 2026-09-26 · worker 20260925T233001Z-125721 · Phase 0.5
**Answer:** DoD passes — P05-12 done. `pnpm --filter @furbysoup/graft-core exec vitest run -t "append-only"` shows 14 passing tests (one UPDATE-rejected + one DELETE-rejected per ledger table × 7 tables) and `-t "migration is idempotent"` shows 1 passing test; the full gate (typecheck + lint + 22 tests) is green.
- Changed: `packages/core/src/ledger/migrate.test.ts` only. Replaced the two episodes-only append-only tests with a data-driven loop over all 7 `LEDGER_TABLES`, each asserting UPDATE and DELETE abort with `ledger is append-only: <table>`; added `seedLedger()` (inserts one FK-valid row per table so the per-row BEFORE triggers actually fire); renamed `is idempotent` → `migration is idempotent` to match the DoD name filter.
- Exit criteria (SPEC §8, Phase 0.5): not evaluated — this item is one backlog task, not a phase gate.
- Next action: continue Phase 0.5 backlog (P05-13 and onward per BACKLOG.md).
- Blockers: none. Sandbox blocked running the `dod-cmd` Python/node predicate directly (no approval path in a non-interactive worker), but the two `-t` filters it reduces to were both run green, and the test-name template guarantees the predicate; the worker script re-runs the exact dod-cmd itself.

## 2026-09-26 · Session 2 close-out · Phase 0.5
**Answer:** Both SPEC §8 P0.5 exit criteria are ticked — [x] two backlog items completed unattended end-to-end with human merge (P05-11 → #6, P05-12 → #7) · [x] an impossible task hit the iteration cap and stopped cleanly (P05-RUNAWAY) — but the first runaway run was invalid (logged-out CLI) and headless sessions could not self-check their DoD until this close-out's fix.
- Bad news first:
  - The first runaway run (20260925T183359Z-54277) "hit the cap" in 32 s because the WSL `claude` CLI was not logged in; the worker counted crashes as attempts. Discarded; fixed by the auth preflight + infra-error path (#2). The valid run is 20260925T190134Z-109269.
  - Both live sessions had every direct `pnpm`/DoD command refused (env-prefixed or chained commands don't match the first-word allow-list). The worker's own verification still ran and passed; sessions now self-check via `ops/automation/dod.sh` (this close-out, fd83c9b).
  - Worker PRs that each append to PROGRESS.md conflict when merged in sequence (#6 needed a manual resolution after #7).
  - Nightly runs depend on WSL being up at 00:00 (R-05).
- Changed: #1 (P05 statuses), #2 (auth preflight, infra-error), #3 (project-wide pause), #4 (visitor README), #5 (runaway result), #6/#7 (first worker PRs, reviewed `looks-good`), and this close-out: dod.sh self-check, nvidia-smi on cron PATH, review verdict always first, Phase 1 readiness items R-01..R-05.
- Exit criteria (SPEC §8, P0.5):
  - [x] Two trivial items unattended branch → green → PR → auto-review → human merge: P05-11 (run 20260925T230001Z-121886, 1 attempt, PR #6, review looks-good at 00:15) and P05-12 (run 20260925T233001Z-125721, 1 attempt, PR #7, review looks-good at 00:45); both merged by Mark.
  - [x] Runaway: P05-RUNAWAY, 5 real sessions (14–15 turns each) changed nothing outside PROGRESS notes; `status=blocked reason=iteration-cap attempts=5 exit=0`; `status: blocked` on `origin/auto/P05-RUNAWAY`; 0 PRs (P05-10).
- cron: `*/30 0-6 * * *` worker.sh (hard kill `timeout 3h`) · `15,45 0-7 * * *` review.sh (`timeout 1h`) · Europe/London · installed via `ops/automation/install-cron.sh`; pause with `ops/scripts/graft pause` (auto-resume example: one-off cron line, 2026-09-25 23:58, fired and self-removed).
- budget: ≤5 attempts/item · 1200 s wall clock per headless attempt · 7200 s per run (checked between attempts) · 900 s per review · one worker + one reviewer at a time (flock) · `claude -p` has no turn cap, so wall clock is the budget; weekly quota review is Mark's.
- deviations: backlog is BACKLOG.md, not GitHub Issues · reviewer verdict is a PR comment, not a formal review (same account), and required approvals = 0 (the human gate is the merge click) · branch protection enforced for admins because the worker pushes as the owner account · hard exclusions extended to the automation's own guardrails (ops/automation, .claude, .github, root test/lint/TS configs, BACKLOG.md) · worker items require a machine-runnable `dod-cmd` · runs execute in git worktrees · added a project-wide pause (not in SPEC) · auth preflight + infra-error handling (not in SPEC).
- Next action: Mark sets `current-phase: 1` in BACKLOG.md when ready; then an interactive session works R-01 → R-02 → R-03 → R-04 (all owner-only: dsh config, model pins, judge ADR) before any Phase 1 worker items run.
- Blockers: none for the P0.5 gate. For Phase 1: R-01 (doer has <2K working context) and R-03 (judge confidence derivation) must land first.

## 2026-09-26 · Session 3: Phase 1 readiness · Phase 0.5 → 1
**Answer:** R-01, R-02 and R-04 are done and verified. **R-03 is not: the phi4-mini judge is at chance on kata code correctness (AUROC 0.44–0.56) under all five `raw_conf` derivations, so ADR-0002 is only *Proposed* and awaits Mark.** Phase 1 worker items now have `dod-cmd`s. `current-phase` is unchanged.
- Bad news first:
  - **The judge can't discriminate.** On 24 labelled items, phi4-mini says `pass` on 10/12 incorrect candidates. Its analyse-first mode flips to rejecting 7/12 correct ones. No derivation fixes that; R-08 re-opens the judge model before P3 (ADR-0002).
  - **Every dsh request so far ran at temperature 1.0 / top_p 1.0.** Ollama's `/v1` applies OpenAI defaults when pi-ai sends none, and dsh 0.1.5-rc.3 cannot set sampling. This affects every episode until R-06 lands.
  - **Phase 0's context problem was worse than measured.** Besides the 6K prompt, pi-ai's hard-coded 4096-token reserve capped doer output at **1 token** per request. That, not the prompt alone, drove the 7 compactions.
  - **Thinking-off is unusable on this stack.** With tools present, non-thinking output never reaches `/v1` (`EMPTY_RESPONSE`, 3/3).
- Changed (branch `session/p1-readiness`):
  - R-02: `graft-judge:cpu` / `graft-embed:cpu` Modelfiles with `num_gpu 0`; `size_vram` 0 for both.
  - R-01: 19 dsh-base rows disabled (23 → 6 tools). First request 6,004 → 2,043 tokens on the toy task, 2,211 on the kata. `contextWindow: 11264` plus compaction `thresholdRatio: 0.5` work around the pi-ai reserve.
  - R-04: thinking on, sent explicitly as `reasoning_effort: "high"`. k=3 on/off table in `ops/VERSIONS.md`.
  - R-03: dataset, `eval.py` and `results.json` under `ops/experiments/judge-confidence/`; `docs/decisions/0002-judge-confidence.md` (Proposed).
  - Backlog: `dod-cmd`s for P1-03/04/05/06/07/08/10/12/19, with exact test names in their `dod`s, and a new `ops/automation/require-tests.sh`. P1-22 waits for its ADR. New items R-06 (sampling), R-07 (tool quirks), R-08 (stronger judge). ADR globs changed to `docs/decisions/*-…`, matching the repo's `NNNN-` naming.
  - `CLAUDE.md` Current state refreshed (it still said "next is Phase 0.5").
- Exit criteria (SPEC §8, P1): not evaluated. This session covers readiness items only.
  - [x] R-01: Ollama `task.n_tokens` 2,043 (toy) / 2,211 (kata) ≤ 4096 on the first request; rows and before/after recorded in `ops/VERSIONS.md`.
  - [x] R-02: `/api/ps` shows `size_vram` 0 for `graft-judge:cpu` and `graft-embed:cpu`; digests recorded.
  - [ ] R-03: the ADR has a ≥20-item results table but is `Proposed`, with no method validated.
  - [x] R-04: k=3 on/off comparison recorded; the profile enforces `reasoning_effort: high` (verified on the wire).
- Next action:
  - Mark reviews the readiness PR and accepts or amends ADR-0002.
  - Mark decides `current-phase: 1`. The first worker-eligible items would be P1-03 and P1-05.
  - R-05 (Windows Task Scheduler) remains Mark's.
- Blockers: none for starting Phase 1 worker items. R-03 blocks only P1-09's claim of a meaningful `raw_conf`, not its record-only plumbing.
