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

## 2026-09-25 · worker 20260925T190134Z-109269 · Phase 0.5
**Answer:** P05-RUNAWAY is BLOCKED — iteration-cap; no PR opened.
- Changed: nothing merged; item marked `status: blocked` on `auto/P05-RUNAWAY`.
- Exit criteria: n/a (single item).
- Next action: Mark reviews `data/automation/runs/20260925T190134Z-109269/` (prompts, transcripts, verify output, abandoned.diff) and re-grooms P05-RUNAWAY.
- Blockers: iteration-cap after 5 attempt(s); evidence in data/automation/runs/20260925T190134Z-109269/
