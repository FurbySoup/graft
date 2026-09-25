# Graft — Build Specification

Status: v0.2 · Owner: Mark · Chassis: DeepSeek Harness (dsh), pinned
Target: single desktop — RTX 4060 Ti 8GB, 64GB RAM, WSL2 Ubuntu, Ollama
v0.2 adds: dev-automation loop (§9, Phase 0.5), statistical gate & evidence spec
(§6), task domains (§7), graft-stats (§3.7), graft-dash visual tracker (§3.8).

## 1. Problem

Harnesses that let agents create and improve their own skills fail through
**uncalibrated self-assessment**: a small model wrongly concludes it succeeded,
"reflects," and rewrites the skill — compounding drift instead of compounding
improvement. Observed first-hand in Skill Tree. The three underlying gaps map to
the three classic RL problems:

| Skill Tree pain | RL problem | Graft answer |
|---|---|---|
| Can't validate task success | Reward noise | Tiered independent verification + calibration (§3.2) |
| Can't update the right parts | Credit assignment | Sectioned skills + validated blame citations (§4.1) |
| Can't measure improvement | Evaluation | Canaries + statistical gate + visual tracker (§6, §3.8) |

Governing rule: **the online loop observes and records; only the offline loop
mutates.** This applies to the harness at runtime AND to the development process
that builds it (§9).

## 2. Chassis: what Graft takes from dsh

- **Append-only session event log** (system prompts, reasoning, tool calls/results,
  every context injection) = the evidence substrate. Fork+replay = canary mechanic.
- **Presets**: frozen Minimal preset for replays (variable isolation — only the
  skill text changes); Standard for real work.
- **Plugin seams**: model adapters, tools, skills, sessions, loop are all
  replaceable; Graft mounts beside them, patches nothing.
- Preview-stage software: pinned version; all Graft logic harness-agnostic in
  `packages/core`; only `packages/plugins/*` may import dsh/Cordis APIs.

## 3. Components

### 3.1 graft-trust (runtime plugin)
Wraps the skills plugin. Responsibilities:
- Skill registry (`skills/registry.yaml`): id, version (git SHA), state
  ∈ {probation, trusted, deprecated, retired}, stats (uses, verified wins, losses).
- Load-time filtering/flagging: probation skills injected with a probation banner;
  retired skills never injected. Supports a **skills-off bypass flag** for the
  ablation arm (§6.5).
- Emits `skill_injected` events: {episode_id, skill_id, version, section_ids}.
Non-goals: never edits skills; never changes state (consolidator does, via file).

### 3.2 graft-judge (runtime plugin)
Subscribes to task-completion and tool-result events. Two tiers:
- **Tier 1 — deterministic checkers**, registered per task type: exit codes, test
  runners, schema/JSON validation, file existence/diff-applies, HTTP status.
  Free, unfoolable, always first. Verdict: pass/fail/not-applicable.
- **Tier 2 — judge model** (only when tier 1 is not decisive): decorrelated family
  (Phi-4-mini v1), fresh context, sees task spec + artifacts + tier-1 results,
  never the doer's reasoning. Output grammar-constrained (GBNF/Outlines) to:
  `{verdict: pass|fail|unclear, blame: [{section_id, quote}]?, notes}`.
  Raw choice-token logprob captured alongside.
- Emits `verdict` events. **Never blocks, retries, or modifies the run.**
- Applies calibration curve (from `data/calibration/judge.json`) to produce
  `p_correct`; below threshold → verdict marked `queued_for_review`.

### 3.3 graft-ledger (runtime plugin)
Sole consumer of the raw dsh session stream (isolation layer for format churn).
Projects into `data/ledger.sqlite`:
```
episodes(id, session_id, ts, task_type, domain, preset, doer_model,
         skills_enabled BOOL, outcome_final)
injections(episode_id, skill_id, version, section_id)
verdicts(id, episode_id, tier, verdict, raw_conf, p_correct, judge_model)
blames(verdict_id, section_id, quote, quote_validated BOOL)
outcomes(episode_id, source ∈ {deterministic, judge, human}, label, ts)
calib_log(id, ts, context ∈ {judge, router}, raw_conf, outcome)
merges(id, ts, skill_id, from_sha, to_sha, stats_verdict_ref, reverted BOOL)
```
Append-only; corrections are new rows, never updates. `merges` feeds the event
annotations on every dashboard time axis (§3.8).

### 3.4 graft-router (runtime plugin — Phase 4)
Pre-session typed decision → {preset, model adapter}, calibrated thresholds;
escalation ladder minimal→standard→frontier adapter. Not built before calibration
data exists.

### 3.5 graft-consolidate (offline — scheduled Claude Code session)
Cadence: manual → weekly. Steps:
1. Read ledger since last run; validate blame citations (quote exists in trace;
   section was actually injected).
2. Cluster corroborated evidence (N≥3 episodes pointing at the same section).
3. Draft skill edits as a git branch; commit body lists evidence episode IDs.
4. **Canary replay**: dsh headless, frozen Minimal preset, doer pinned; k runs
   per canary per version (k from `ops/stats.yaml`).
5. **Statistical gate**: hand replay results to graft-stats (§3.7); merge only on
   a pass verdict. The consolidator NEVER computes statistics itself.
6. Merge or reject; update `skills/registry.yaml` states (probation→trusted at
   M≥5 verified wins + ≥1 passed consolidation; demotion on sustained losses);
   record row in `merges`.
7. New-skill identification: episodes flagged reusable-pattern + embedding dedup
   (cosine < 0.85 vs existing registry) → draft new skill in probation.
8. Refresh canaries (add recent real episodes, retire stale ones, keep holdouts).
9. Recalibrate via graft-calibrate; record rolling Brier.
10. **Regenerate the dashboard** (§3.8) — a consolidation that doesn't refresh
    the report is incomplete.
11. If any previously merged edit was reverted since last run: write a post-mortem
    ADR before doing anything else.

### 3.6 graft-calibrate (offline — Python sidecar)
Platt scaling + isotonic regression over (raw_conf, outcome) pairs per context;
emits `data/calibration/{judge,router}.json` {method, params, fitted_at, n,
brier}. Refuses to emit below n=100 (cold-start guard).

### 3.7 graft-stats (offline — Python, same sidecar package)
Deterministic statistics engine. Input: paired replay results + committed
`ops/stats.yaml`. Output: machine-readable verdict
`{edit_id, test, p, effect_size, median_delta, pass BOOL, config_sha}`.
Rules:
- Refuses to run if `ops/stats.yaml` has uncommitted changes, or if its config
  SHA differs from the one committed before the replay batch started
  (pre-registration enforcement — no choosing the test after seeing the data).
- Implements: exact permutation test on paired per-case pass-rate deltas
  (default); Wilcoxon signed-rank (reported alongside; caveats: requires ≥6
  non-tied pairs — at n=5 the minimum two-sided p is 0.0625 — and zero-deltas
  drop out); McNemar (only if run-level pairing via fixed seeds is in use);
  Benjamini–Hochberg across edits in one cycle.
- LLMs never call these functions ad hoc; only the consolidation pipeline invokes
  it, and only on complete replay batches.

### 3.8 graft-dash (offline — visual improvement tracker) **[REQUIRED]**
The improvement measurements must be *seen*, not queried: trends, gates, and
drift visible at a glance. Read-only over `data/ledger.sqlite`,
`data/calibration/*.json`, `skills/registry.yaml`, and graft-stats verdicts.

**The form is UNDECIDED** — static report, notebook, terminal renderer, local app,
something else. No technology, format, layout or visual style is prescribed here,
and none should be assumed: choosing one now, before anyone has seen real ledger
data, would be the same assertion-over-evidence mistake this project exists to
avoid. Decide it during Phase 1 against the constraints below, record the choice
and its alternatives in an ADR, and let what the data turns out to look like drive
the decision.

**Constraints on any form** (these are requirements, not preferences):
- **Read-only.** No write path of any kind, ever.
- **Offline.** No network access at runtime — the workspace has none by design.
- **Deterministic** from its inputs: same inputs, same output.
- **Regenerated automatically** at the end of every consolidation run (§3.5 step
  10) and on demand.
- **Whole-history, not snapshots.** The point is change over time, so trends,
  windows and events must be legible together (§6.4 — no point-to-point claims).

**v0 (required for Phase 1 exit)** must make the following visible. The widget
names are illustrative of the information required, not a specification of how to
draw it:
1. **Indicator board** — the three metric classes from §6.6 (lagging / leading /
   guard), each as an EWMA control-chart line (λ=0.2) over its rolling window,
   with target direction and current-vs-baseline status.
2. **Merge & promotion events as vertical annotations on every time axis** (from
   the `merges` table) — improvement claims are step-change attributions, so the
   eye must be able to line trends up against changes.
3. **Per-skill drilldown** — verified-win sparkline, state history
   (probation→trusted etc.), canary pass trend split training vs holdout.
4. **Calibration panel** — reliability diagram (predicted vs observed) per
   context + Brier trend.
5. **Ablation gap** — skills-on vs skills-off verified success rate with CIs,
   once the arm exists (§6.5).
6. **Revert log** — every reverted merge with a link to its post-mortem ADR.

Whether anything beyond v0 is ever built — richer interaction, live refresh,
anything else — is decided later, on evidence that the tracker is being used and
falling short, never on anticipation.

## 4. Data formats

### 4.1 Skill format (sectioned; authored fresh — nothing is imported)
```markdown
---
id: spec-driven-dev
version: <git-managed>
state: probation
---
## [S1] Preconditions
## [S2] Steps
## [S3] Checks
## [S4] Known failure modes
```
Stable `[S*]` IDs; blame and edits address sections only. Every skill enters as
probation, whether hand-authored for a launch domain or drafted by consolidation
from verified episodes (§3.5 step 7).

**No corpus is imported.** Skill Tree is reference material only (it failed to
evidence improvement; its artefacts may carry the assumptions that caused that),
so Graft starts with a small hand-authored set for the launch domains and grows
the rest from its own evidence. Slower by design: a skill that was never justified
here has no place in a system built to demand justification.

### 4.2 Canary format (`canaries/<skill_id>/<case>.yaml`)
```yaml
id: sdd-001
created: 2026-09-20
source_episode: <id|handwritten>
input: <task prompt + fixtures ref>
success:                # deterministic only — a canary a judge must score is invalid
  - type: file_exists
    path: out/plan.md
  - type: regex
    path: out/plan.md
    pattern: "## Acceptance"
holdout: false
```

### 4.3 Pre-registered statistics config (`ops/stats.yaml`)
```yaml
version: 1
metric: per_case_pass_rate        # over k runs per version
k_runs: 5
min_cases: 8                      # target 10 per skill
test: exact_permutation           # wilcoxon reported alongside
alpha: 0.05
multiple_comparisons: benjamini_hochberg
effect_floor:
  median_delta_pp: 10             # both gates must pass: p AND floor
report_effect_size: rank_biserial
ablation_fraction: 0.10           # of live episodes, skills-off
ewma_lambda: 0.2
```
Changes to this file require a standalone commit, human-merged, never bundled
with a skill edit.

## 5. Model matrix

| Role | Model | Placement | Notes |
|---|---|---|---|
| Doer | qwen3.5:9b Q4_K_M text-only | GPU | sole VRAM resident during runs |
| Judge v1 | phi4-mini | CPU | decorrelated family — hard requirement |
| Judge A/B | gemma-4 E-series; mellum2-12b-a2.5b | CPU/GPU | evaluate in Phase 2 |
| Embeddings | qwen3-embedding:0.6b | CPU | dedup + retrieval |
| Consolidator | Claude (Max plan) | offline | never in the runtime loop |
| Draft (later) | qwen3.5:4b | GPU | only if replay throughput binds |

Operational rule: sequence doer→judge via keep_alive/unload; never co-resident in
8GB VRAM.

## 6. Statistical gate & improvement evidence

### 6.1 Principles
Paired · pre-registered · computed by code. Canary replays are paired samples
(same case, old vs new skill), which is what makes small-n inference viable.
The metric, test, and thresholds live in `ops/stats.yaml`, committed before the
replay batch. The consolidator LLM reads graft-stats verdicts; it never computes
p-values, effect sizes, or trends itself.

### 6.2 The merge gate
Per edit: exact permutation test on paired per-case pass-rate deltas at α=0.05
(BH-corrected across the cycle's edits), AND median improvement ≥ the effect
floor (+10pp default). Significance without size does not merge; size without
significance does not merge. Wilcoxon reported alongside for the write-ups.

### 6.3 Sample sizes
≥8 canary cases per skill (target 10), k=5 runs per case per version. Known
consequence: early statistical power is low — **this is intended**. An
underpowered gate only passes large, obvious improvements, which is the correct
conservatism while trust in the machinery is being established. Increase k
overnight as replay throughput allows.

### 6.4 Never conclude from single runs
All longitudinal comparisons use rolling windows and EWMA control charts
(λ from config); no point-to-point conclusions anywhere in reports, prompts, or
dashboard copy.

### 6.5 Ablation arm — the headline evidence
`ablation_fraction` of live episodes run with skills disabled (graft-trust
bypass), identical verification. The skills-on vs skills-off gap in verified
success rate is the system's existence proof: largely Goodhart-immune, and the
strongest artifact for any public write-up. Displayed on the dashboard with
confidence intervals.

### 6.6 Trend indicators
| Class | Indicator | Healthy |
|---|---|---|
| Lagging | Verified success rate per skill; holdout canary pass rate; revert rate of merged edits; judge-vs-human audit disagreement | ↑ ; ↑ ; →0 ; ↓ |
| Leading | Calibration Brier; % episodes resolved by tier-1 alone; blame-citation validation rate; time-to-N corroboration; queued-for-review fraction | ↓ ; ↑ ; ↑ ; ↓ ; ↓ |
| Guard | Training-vs-holdout canary gap; episode embedding dispersion; token cost per verified success | flat ; flat ; ↓ |

Revert rate is the most honest number on the board: every rollback of a merged
edit means the entire gate chain agreed on something false → mandatory
post-mortem ADR (§3.5 step 11).

## 7. Task domains

Selection criteria, in priority order: deterministic verifiability · instance
volume (statistics need n) · difficulty gradient · genuine value to Mark
(real episodes, anti-stall motivation) · offline safety.

**Launch domain (Phase 1) — DECIDED:**
**TS/Python micro-katas with test suites** — the *calibration domain*:
near-perfect tier-1 verification, unlimited generatable instances, controllable
difficulty. If improvement can't be evidenced here, it can't anywhere; katas
validate the machinery itself. Include a kata generator (`ops/scripts/gen-kata`)
producing task + hidden test suite variants.

**Second domain (the judge domain) — UNDECIDED. Do not assume one.**
Katas are deliberately synthetic: tier-1 settles them, so they exercise the
deterministic path and leave tier-2 nearly unused. A second domain is therefore
needed eventually, and it must supply what katas structurally cannot:
- episodes whose quality a deterministic checker *cannot* settle, so tier-2 runs;
- human ground truth at low marginal cost, so calibration has (raw_conf, outcome)
  pairs (§3.6 refuses below n=100);
- real value to Mark, so episodes keep arriving without willpower.

**No candidate is selected.** An earlier draft named "CC3D listing production" as
decided; it was an unverified suggestion, not Mark's decision, and naming it here
would be the project violating its own standard — an evidence-based system does
not pick its validation domain by assertion. Candidates are recorded in an ADR
with their scoring against the criteria above, and the choice is made when there
is something to choose on.

**Decision gate:** the second domain must be chosen and an ADR written **before
P3 entry**, because P3's calibration curves cannot be fitted without judged
episodes carrying human outcomes. P1 and P2 proceed on katas alone. Anything
proposed for Phase 3 and beyond (fixture-based extraction, lint-checked docs
generation, or anything else) is a candidate on the same footing — unscored,
undecided, and not to be built toward.

**Banned early:** "improve Graft itself" (bootstrap paradox); open-ended creative
tasks (unverifiable); anything needing live web (nondeterministic; unaudited
preview harness).

## 8. Phases & acceptance criteria

**P0 — Sandbox & scaffold** (Session 1): WSL2 workspace; dsh installed & pinned;
Ollama models pulled & smoke-tested; monorepo scaffold; frozen Minimal preset
committed; BACKLOG.md seeded. *Exit: one dsh Standard session completes a toy
task with all models reachable; `ops/VERSIONS.md` records every pin.*

**P0.5 — Dev automation loop** (Session 2, §9): backlog-driven headless worker +
review agent + scheduling. *Exit: two trivial backlog items completed end-to-end
unattended (branch → green tests → PR → auto-review comment) with Mark merging;
AND a deliberately impossible task hits the iteration cap and stops cleanly.*

**P1 — Observation mode**: graft-ledger + graft-judge (record-only) + **3
hand-authored seed skills**, at least 2 of them targeting the micro-kata domain
(§7; nothing imported — see §4.1) + graft-trust injection logging + kata generator
+ **graft-dash v0 — a visual improvement tracker over real ledger data, its form
chosen during this phase and recorded in an ADR (§3.8)**. No gating, no edits.
*Exit: 25+ real kata episodes; verdicts with captured logprobs; blame citations
mechanically validated; human audit of 10 random verdicts recorded as outcomes;
the tracker regenerates on demand and makes the indicator board and
per-skill history visible.*
Note: tier-2 will see little traffic until the second domain is chosen (§7) — that
is expected here, and is P3's problem, not P1's.

**P2 — Consolidation**: canary sets per §6.3 for every seed skill (3 at launch;
more only if consolidation has grown them); consolidate run
end-to-end producing ≥1 staged diff with evidence; replay + **graft-stats gate**
working. *Exit: one skill improvement merged with full evidence chain including
a stats verdict; one edit rejected by the gate (if none rejects naturally,
create a deliberate bad edit to prove the gate); merge events visible as
dashboard annotations.*

**P3 — Calibration, trust & ablation live** (*requires the §7 second domain to be
chosen and running — katas alone will not produce n≥100 judged pairs*): n≥100
calib pairs; curves fitted;
judge p_correct gating queue-for-review; probation→trusted promotions by rule;
**ablation arm running at configured fraction**. *Exit: rolling Brier on the
dashboard's calibration panel; at least one skill earns trusted state; ablation
gap chart populated.*

**P4 — Router & extras** (optional): preset/model routing; any tracker work that
Phase 1–3 use has actually shown to be needed (§3.8);
speculative-decoding replay throughput; public write-ups.

## 9. Dev automation: the worker loop (Phase 0.5)

The development process applies Graft's own architecture to building Graft:
autonomous doer, independent verifier, evidence trail, human gate. Mark's role
is backlog grooming and PR review — never driving sessions.

- **Backlog**: `BACKLOG.md` (or GitHub Issues) of small tasks, each with a
  machine-checkable definition of done (tests, not vibes). Grooming ≈ 30–60
  min/week.
- **Worker**: `ops/automation/worker.sh` — pulls next item, invokes Claude Code
  headless (`claude -p`) with a task prompt template, branch per task; hooks run
  typecheck + tests after edits; commit only on green; opens a PR; appends to
  `PROGRESS.md`. **PR-only — the worker never merges.** Iteration cap ≤5 fix
  cycles per task, then stop and flag.
- **Review agent**: automated review pass on every PR (fresh context, different
  prompt — the decorrelated-judge principle at dev level).
- **Scheduling**: cron in WSL2; many short scheduled runs, never an always-on
  process (crash-resistant, no context drift, observable). Each run reads
  `PROGRESS.md` first and writes it last — resume must cost nothing.
- **Hard exclusions** — autonomous runs never touch: `skills/`,
  `skills/registry.yaml`, `ops/VERSIONS.md`, `ops/stats.yaml`, dsh config,
  canary holdouts. These paths are the human's.
- **Guardrails**: protected main; per-run token budget; weekly quota review;
  runaway test in P0.5 exit criteria.

## 10. Parallel subagent guidance (Claude Code)

Safe to parallelise (independent artifacts): docs/ADR drafting · per-package
scaffolds · schema/migration authoring · canary authoring per skill · seed-skill
authoring per skill · kata generation · research lookups (dsh plugin
API, Cordis docs). Must serialise: git operations · dsh install/config changes ·
`ops/VERSIONS.md` · `ops/stats.yaml` · anything touching
`skills/registry.yaml` · Ollama model pulls (disk/VRAM contention). Worker-loop
tasks are inherently serial per branch; cross-branch parallelism only for
disjoint packages. Rule of thumb: parallel for *files that don't share a
directory owner*; serial for *shared state and the environment*.

## 11. Open questions (revisit at P2 exit)

- **Second task domain (§7): undecided, and deliberately so.** What real work of
  Mark's is verifiable enough to judge, high-volume enough for statistics, and
  audited cheaply enough to yield calibration ground truth? Score candidates
  against §7's criteria with evidence, write an ADR, decide before P3 entry.
- Kata generator: template-based vs LLM-generated-with-frozen-tests (leakage risk
  if the doer family generated the tests).
- Judge context budget: how much artifact to show before judgment degrades.
- Whether graft-router earns its complexity on a single-user machine.
- dsh upgrade policy after first breaking release (repair cost data needed).
- Exact promotion statistics: revisit permutation-vs-Wilcoxon choice and the
  +10pp floor once real variance data exists.
