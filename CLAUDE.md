# CLAUDE.md — Graft

This file provides guidance to Claude Code (claude.ai/code) when working with code
in this repository.

Graft is a harness for **skill self-improvement without self-corruption**: agents
execute tasks with versioned skills, an independent calibrated judge validates
outcomes, evidence accumulates in an append-only ledger, and skill changes happen
only through an offline, replay-gated, statistically-tested consolidation pass.
Built as thin plugins on DeepSeek Harness (dsh) over local open models, on a
single desktop (RTX 4060 Ti 8GB / 64GB RAM / WSL2 Ubuntu).

## Current state — read before acting

**Phases 0 and 0.5 are complete (2026-09-25). The Phase 1 readiness items (`R-*` in
`BACKLOG.md`) are in progress. `current-phase` stays 0.5 until Mark sets it to 1.**

- **Built:**
  - git repo on GitHub (`FurbySoup/graft`, public, branch-protected, CI `gate` check).
  - pnpm workspace:
    - `packages/core`: ledger schema, append-only SQLite migration, config loader.
    - `packages/plugins/graft-{trust,judge,ledger}`: Cordis stubs, mounted nowhere.
  - `sidecars/calibrate`: stdlib-only stubs.
  - dsh 0.1.5-rc.3 pinned, with profiles `graft` and frozen `graft-replay`.
  - Ollama models pinned via committed Modelfiles.
  - `ops/stats.yaml` pre-registered.
  - The Phase 0.5 dev loop in `ops/automation/` (cron worker → PR, review pass, hooks,
    pause/resume via `ops/scripts/graft`).
  - ADR-0001; ADR-0002 (judge confidence, **Proposed**); `docs/prior-art-skill-tree.md`.
- **Read `ops/VERSIONS.md` before touching dsh or models.** It records every pin and
  every place dsh diverges from SPEC. The most important:
  - dsh has **profiles, not presets**.
  - The doer is **`graft-doer:8k` (qwen3:8b), not qwen3.5:9b**, with 8192 real
    context tokens. The `graft` profile's first request uses ~2.0–2.2K (R-01: trimmed to
    6 tools). The pi-ai route **declares 11264 on purpose**, because pi-ai reserves a
    fixed 4096; do not "correct" it to 8192.
  - Doer thinking is **on**, sent explicitly (R-04: off returns empty responses).
  - The doer samples at T=1.0 because dsh cannot set it (R-06, open).
  - Judge and embeddings are **`graft-judge:cpu` / `graft-embed:cpu`**, never the base
    tags.
- **Judge finding (ADR-0002, proposed):** phi4-mini is at chance on kata code
  correctness under every `raw_conf` derivation tried. Treat tier-2 as record-only
  plumbing; nothing gates on it (R-08 re-opens the judge model before P3).
- **Absent until later phases:** `skills/registry.yaml`, any skills or canaries,
  `ops/scripts/gen-kata`, `ops/scripts/ledger-sql`, the tracker.
- `SPEC.md` and `RISK-REGISTER.md` live in `docs/`.

## Core principles — enforce these in every change

1. **Online observes, offline mutates.** Runtime plugins may append events and read
   config. They never write to `skills/`, trust states, canaries, or calibration.
2. **The doer never grades its own work.** Verification = deterministic checks
   first, then a judge model from a *different model family*, fresh context, no
   access to the doer's reasoning.
3. **Skill edits are pull requests.** Staged git diffs with evidence attached,
   N≥3 corroborating episodes, canary replay + statistical gate pass — then
   merge. Never in-place.
4. **Statistics are code.** p-values, effect sizes and trend claims come only
   from graft-stats against the pre-registered `ops/stats.yaml`; the consolidator
   (or any LLM) reads verdicts, never computes them.
5. **Calibration over confidence.** Raw logprobs are inputs, not truths. Decisions
   gate on calibrated probabilities; curves are refit on a schedule.
6. **Comparisons need k runs.** Never conclude anything from a single sampled run;
   longitudinal claims use EWMA over rolling windows.
7. **Measurements must be visible.** A visual improvement tracker is a required
   deliverable, not decoration: every consolidation regenerates it, and change
   over time must be legible against the merges that caused it. Its *form* is an
   open decision (SPEC §3.8) — do not assume a technology, format or style.
8. **Thin shims.** dsh-facing plugin code contains adaptation only; all logic lives
   in `packages/core` (harness-agnostic). Durable data is plain files.
9. **Blame must cite.** A skill-section blame requires the section ID and a quoted
   trace line, both mechanically validated against the ledger.
10. **Autonomous dev runs are PR-only.** The worker loop never merges and never
    touches the hard-exclusion paths (SPEC §9).

## Architecture (full detail: `docs/SPEC.md`)

Runtime (dsh/Cordis plugins): `graft-trust` (skill registry, lifecycle states,
injection logging, ablation bypass) · `graft-judge` (tiered verification, verdict
events) · `graft-ledger` (sole session-stream consumer → SQLite projection) ·
`graft-router` (Phase 4).
Offline: `graft-consolidate` (scheduled Claude Code session: evidence → staged
diffs → canary replays → graft-stats gate → promotion → dashboard regen) ·
`graft-calibrate` + `graft-stats` (Python sidecar: calibration curves; the
deterministic statistics engine) · `graft-dash` (visual improvement tracker;
required content, undecided form — SPEC §3.8).

## The evidence chain (the part that spans files)

One arrow, end to end — every component exists to keep one link honest:

```
episode (dsh session)
  → skill_injected events         graft-trust    which skill/version/sections were in context
  → tier-1 deterministic check    graft-judge    exit codes/tests/schema — always first, decisive when it fires
  → tier-2 judge verdict + logprob graft-judge   different model family, fresh context, never sees doer reasoning
  → calibrated p_correct          data/calibration/judge.json — low ⇒ queued_for_review
  → ledger rows                   graft-ledger   episodes/injections/verdicts/blames/outcomes (append-only)
  ⇢ OFFLINE ⇢
  → N≥3 corroborated blames on one section_id   (quote must be found in the trace AND the section must
                                                 actually have been injected, or the blame is discarded)
  → staged skill diff on a branch, evidence episode IDs in the commit body
  → paired canary replay: same cases, old vs new skill, frozen Minimal preset, k runs each
  → graft-stats verdict against the pre-committed ops/stats.yaml  (permutation p AND ≥+10pp median delta)
  → merge + `merges` row  → dashboard regen with merge annotations on every time axis
```

Invariants that only make sense with the whole chain in view:

- `ops/stats.yaml` is **pre-registered**: committed before the replay batch, and
  graft-stats refuses to run if it is dirty or its SHA changed since. This is what
  stops the test being chosen after seeing the data — so never edit it mid-cycle.
- Canary success criteria must be deterministic. *A canary a judge has to score is
  an invalid canary.*
- The ablation arm (fraction of live episodes with skills bypassed) is the headline
  evidence, not a debug switch — graft-trust's bypass flag exists for it.
- Sample sizes are deliberately underpowered early (≥8 cases, k=5). Low power is the
  intended conservatism; do not "fix" it by loosening the gate.
- Models are sequenced, never co-resident: doer on GPU, judge on CPU, unload between
  (8GB VRAM). Replay throughput is bounded by this, by design.

## Repo layout

```
graft/
  CLAUDE.md                  # this file
  BACKLOG.md                 # groomed dev tasks with machine-checkable DoD
  PROGRESS.md                # worker-loop handoff: read first, write last
  docs/                      # SPEC.md, RISK-REGISTER.md, decisions/ (ADRs)
  packages/
    core/                    # harness-agnostic logic (TS)
    plugins/                 # graft-trust, graft-judge, graft-ledger, graft-router
  sidecars/calibrate/        # Python: calibration fitting + graft-stats
  skills/                    # skill git worktree: sectioned SKILL.md files
  canaries/                  # per-skill regression cases (YAML)
  data/                      # ledger.sqlite, calibration/*.json, dash/ output (gitignored)
  ops/                       # dsh config, presets, stats.yaml, VERSIONS.md,
                             # automation/ (worker loop), scripts/ (gen-kata, tracker regen)
```

## Environment

- WSL2 Ubuntu; dedicated non-admin workspace; dsh sandboxed to this repo.
- Workspace path: `~/graft` (`/home/mark/graft`), on the WSL ext4 filesystem —
  **not** `/mnt/c`. Moved here 2026-09-25, pre-Phase-0, for SPEC sandbox compliance
  and because `C:` was at 95% capacity; the old Desktop folder holds only a
  `MOVED.md` pointer. Open every session at the WSL path.
- dsh **pinned** to the exact version recorded in `ops/VERSIONS.md`. Upgrades are a
  deliberate task with an adapter-repair budget, never incidental.
- Ollama at `http://localhost:11434`. Models (also in `ops/VERSIONS.md`):
  - Doer: `graft-doer:8k` = `qwen3:8b` Q4_K_M text-only + `num_ctx 8192`
    (`ops/models/graft-doer.Modelfile`) — GPU. SPEC §5's `qwen3.5:9b` was rejected:
    vision-bundled and spills 12% to CPU (evidence in `ops/VERSIONS.md`). One model
    resident in VRAM at a time.
  - Judge: `graft-judge:cpu` = `phi4-mini` + `num_gpu 0` (`ops/models/graft-judge.Modelfile`) —
    CPU/RAM (decorrelated family; do not swap to a Qwen judge).
  - Embeddings: `graft-embed:cpu` = `qwen3-embedding:0.6b` + `num_gpu 0` — CPU.
  - Consolidator: Claude (this tool), offline sessions only.
- TypeScript throughout `packages/`: **strict mode, no `any`** — enforced by
  `tsconfig.base.json` + `pnpm lint` (the strict-typescript-mode skill is not installed
  in this environment). Debugging: apply the systematic-debugging skill
  before proposing fixes. Tracker work: pick the appropriate skill once its form
  is decided (SPEC §3.8) — nothing is prescribed in advance.

## Commands

All commands run from the repo root (`/home/mark/graft`). pnpm comes from a corepack
shim in `~/.local/bin` — make sure it is on `PATH` (`export PATH=$HOME/.local/bin:$PATH`
in non-login shells such as cron). These are the contract the commit-gating hooks and
the worker loop execute; every one was run green at the end of Phase 0.

| Purpose | Command |
|---|---|
| Install (reproducible) | `pnpm install --frozen-lockfile` |
| Typecheck (all packages + tests) | `pnpm typecheck` (= `tsc -b`) |
| Lint (no explicit `any`) | `pnpm lint` |
| Test all (TS) | `pnpm test` (= `vitest run`) |
| Test one package | `pnpm --filter @furbysoup/graft-core test` (or `graft-trust` / `graft-judge` / `graft-ledger`) |
| Test one file | `pnpm vitest run packages/core/src/ledger/migrate.test.ts` |
| Everything | `pnpm check` (typecheck → lint → test) |
| Python: test all | `sidecars/calibrate/.venv/bin/python -m unittest discover -s sidecars/calibrate/tests -t sidecars/calibrate` |
| Python: test one file | `sidecars/calibrate/.venv/bin/python -m unittest discover -s sidecars/calibrate/tests -t sidecars/calibrate -p test_scaffold.py` |
| dsh (only entry point) | `ops/scripts/dsh --profile graft "<task>"` — run from the workspace the task is confined to |
| dsh composed config | `ops/scripts/dsh --profile graft --dump-config` (or `graft-replay`) |
| Pause project activity | `ops/scripts/graft pause [--hard] [--reason "text"]` — blocks new worker/review/dsh runs, unloads Ollama models; `--hard` also stops an in-flight run |
| Resume project activity | `ops/scripts/graft resume` — removes the pause flag; does not preload models |
| Pause status | `ops/scripts/graft status` — exit 0 active, **exit 3 when paused** |

Notes: the venv has no third-party packages (PyPI not yet approved — BACKLOG). Node
prints an `ExperimentalWarning` for `node:sqlite`; it is expected. New install scripts
in dependencies are blocked by pnpm until reviewed and added to `allowBuilds` in
`pnpm-workspace.yaml`.

Interfaces already fixed by SPEC, whatever the runner turns out to be:

| What | Where | Note |
|---|---|---|
| Ollama endpoint | `http://localhost:11434` | doer/judge/embeddings; verify reachable before any run |
| Replay profile | `ops/presets/graft-replay/` | frozen, derived from dsh `sdk-minimal` — must never drift (dsh has profiles, not presets) |
| Improvement tracker | regeneration entry point under `ops/scripts/`, named when its form is chosen (SPEC §3.8) | must be read-only, offline, deterministic |
| Kata generator | `ops/scripts/gen-kata` | task + hidden test-suite variants |
| Worker loop | `ops/automation/worker.sh` | branch → green → PR; never merges; iteration cap 5 |
| Review pass | `ops/automation/review.sh` | fresh context, no worker transcript |
| Automation kill switch | `ops/automation/pause` | flag file both scripts respect |

## Parallel vs serial work (SPEC §10)

Rule of thumb: parallel for *files that don't share a directory owner*; serial for
*shared state and the environment*.

- Safe to fan out to subagents: docs/ADR drafting · per-package scaffolds · schema
  and migration authoring · canary authoring per skill · seed-skill authoring
  per skill · kata generation · research lookups.
- Must be serial: git operations · dsh install/config · `ops/VERSIONS.md` ·
  `ops/stats.yaml` · anything touching `skills/registry.yaml` · Ollama model pulls
  (disk and VRAM contention).

## Communication

Apply the **minto-pyramid** skill (`.claude/skills/minto-pyramid/SKILL.md`) to every
artifact that carries a conclusion: PR bodies, session close-outs, consolidation
write-ups, ADRs, blocked-item notes, and dashboard copy. Answer first, then 2–4
grouped supporting claims, then the evidence (episode IDs, stats verdicts, test
output) underneath. Improvement claims cite a graft-stats verdict; trends are EWMA
over rolling windows, never point-to-point; bad news leads.

## Task domains (SPEC §7)

**Launch domain — decided:** TS/Python micro-katas (calibration domain, tier-1
heavy, unlimited generatable instances). Phase 1 runs **3 hand-authored seed
skills**, at least 2 of them kata-facing.

**Second domain (the judge domain) — UNDECIDED, and not to be assumed.** Katas are
settled by tier-1, so they barely exercise the judge; a second domain is needed
before P3 to produce judged episodes with cheap human ground truth for
calibration. No candidate has been chosen. An earlier draft asserted "CC3D listing
production" — that was an unverified suggestion, never Mark's decision, and
picking a validation domain by assertion is precisely what this project exists not
to do. Score candidates against SPEC §7's criteria, write an ADR, decide on
evidence. Until then, do not build toward any specific second domain, and do not
reintroduce one into docs, backlog items, or prompts.

Banned early: improving Graft itself, open-ended creative tasks, anything needing
live web.

## Dev automation (SPEC §9)

Backlog-driven headless worker (`claude -p`) on cron: branch per task, hooks gate
commits on green tests, PR-only, iteration cap ≤5, automated review pass on every
PR, human merges. Hard exclusions for autonomous runs: `skills/`,
`skills/registry.yaml`, `ops/VERSIONS.md`, `ops/stats.yaml`, dsh config, canary
holdouts.

## Skill Tree — reference only, never a source of artefacts

Source: `/mnt/c/Users/Mark/Desktop/Solo Dev Projects/skill-tree/` — **read-only, and
read rarely**. Skill Tree was Mark's first iteration of this project's ethos. It
failed at exactly the thing Graft exists to do: it could not demonstrate skill
improvement statistically. Its research, project vision, and the anatomy of that
failure are valuable. Its artefacts are not.

**Do not copy, convert, import, vendor, or adapt anything from it** — not skills,
canaries, code, configs, prompts, schemas, or dashboards. Its files may carry the
same errors, assumptions, and oversights that produced the failure, and importing
them would smuggle unexamined priors into a system whose entire premise is that
claims must be evidenced. This holds even when a file looks obviously reusable.

Legitimate uses, all read-only:
- **Prior art on what not to repeat** — above all self-graded updates (Reflexion /
  PatternRetriever), the direct motivation for Graft's independent-judge design.
- **Failure anatomy** — why statistical proof of improvement never arrived there.
- **Pitfalls already paid for**: qwen thinking-mode field quirks, UTF-8 BOM in
  PowerShell-written JSON, Qdrant embedded single-client limit, context overhead
  budget (the "~37%" figure is unconfirmed — see `docs/prior-art-skill-tree.md` §4;
  Graft measures its own: dsh used ~6K of the doer's 8K context before R-01, ~2K after).
- **Concepts worth re-deriving from scratch** — e.g. guard patterns
  (InputGuard/OutputGuard/PermissionGuard) as inspiration for judge tier-1 checks.

Anything carried across is re-derived and re-justified in Graft's own terms, in
Graft's own format, and cited as a lesson rather than inherited as an asset.

Graft's skills are therefore **authored fresh or grown from its own verified
episodes** — there is no seed corpus to convert. (For the record: the corpus there
is 11 `*.skill.yaml` + 5 `claude-code/*.md` + 2 `.claude/skills/` entries, not the
"25 skills in `claude-skills/` + `SKILL-REGISTRY.md`" an earlier draft of this file
claimed. Both the count and the intent were wrong.)

## Boundaries

- Nothing employer-related in this repo, its prompts, or its test data. Ever.
- No credentials in the workspace; dsh has no network write access beyond localhost
  model endpoints unless a task explicitly requires and Mark approves.
- Do not build ahead of the current phase gate (SPEC §8). Phase exit
  criteria are checked before starting the next phase.
- Commits: conventional commits; every consolidation-produced change references its
  evidence (episode IDs) in the commit body; `ops/stats.yaml` changes are
  standalone commits, human-merged, never bundled with a skill edit.
