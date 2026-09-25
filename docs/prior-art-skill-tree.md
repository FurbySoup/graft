# Prior art: Skill Tree — why its improvement claim never arrived

**Skill Tree failed to evidence skill improvement because its measuring instrument
was broken, not because it lacked data: the doer graded its own work on a saturated
rubric that changed four times mid-experiment, and no comparison was pre-registered,
paired against a fixed holdout, or ablated at the level that mattered.** Its best
powered run (N=224 paired tasks) returned a null result. Graft's SPEC is, point by
point, a set of constraints that make each of those breaks structurally impossible.

This note is analysis, written in Graft's terms. Nothing from Skill Tree — skills,
canaries, code, configs, prompts, schemas, dashboards — is imported into Graft, and
nothing here should be read as a template (CLAUDE.md, "Skill Tree — reference only").
Sources were read-only: the Skill Tree tree (`ST/` below =
`/mnt/c/Users/Mark/Desktop/Solo Dev Projects/skill-tree/`) and the project's research
notes in Mark's vault. Surveyed 2026-09-25.

## 1. The evidence chain broke at the grader, and everything downstream inherited it

- **Self-grading, same model.** For nearly the whole project the doer
  (`qwen3-coder:30b`) scored its own output on a 1–5 rubric. The project's own lessons
  table records the bias: self-scores for one agent ran 0.60–1.00 where an independent
  model scored 0.50–0.69 (`ST/CLAUDE.md`, lessons table).
- **The instrument was saturated.** A third of outputs scored a perfect rubric, and in
  43% of the N=224 A/B pairs treatment and control scored *identically* — the grader
  could not see the differences the experiment existed to detect (vault research note,
  "Evaluation redesign").
- **The instrument drifted mid-programme.** The scoring system changed at least four
  times during the measurement period, each change resetting what a score meant; the
  final switch (to a cross-family grader with pass/fail criteria) came *after* the
  N=224 null and was only piloted at N=6 before a re-architecture.
- **One agent was never judged at all** — it received a hard-coded score.

**Graft consequence:** the doer never grades its own work (principle 2). Judge tier-1
is deterministic and always first (SPEC §3.2); tier-2 is a *different model family*
with a fresh context and no view of doer reasoning; raw judge confidence is an input
to a calibration curve, never a truth (principle 5, §3.6). Canary success criteria
must be deterministic — "a canary a judge has to score is an invalid canary" (§4.2).

## 2. The comparisons could not have produced a defensible claim even with a good grader

- **No pre-registration.** No hypothesis, minimum effect size, or stopping rule was
  fixed in advance; after results arrived the success criterion was relaxed to "delta
  ≥ 0" with p<0.10 as "nice-to-have" (`ST/alignment-steps/GATE-STATUS.md`).
- **Underpowered and diluted.** The measured noise floor implied ~150+ pairs to detect
  a 0.05 effect; typical runs were N=48–84. The treatment (pattern injection) actually
  fired in only about a third of treatment tasks, and ~30% of pairs went to agents
  that could not be affected.
- **Wrong ablation level, no holdout.** Tests toggled one feature off against ten-plus
  interacting features; there was no skills-on vs skills-off arm on live work. The same
  scenarios tuned the calibration fixes and then tested them.
- **Confounds and missing provenance.** Treatment always ran before control until late
  fixes; no multiple-comparison correction across agents/domains; no model version,
  git SHA or config hash per ledger row; timeouts, parse failures and bad output all
  collapsed into the same zero score.
- **The headline number had no measurement behind it.** The project vision claimed a
  42% learning-speed improvement; it traces only to early READMEs.

**Graft consequence:** statistics are code (principle 4). `ops/stats.yaml` is committed
*before* a replay batch and graft-stats refuses to run if it is dirty or its SHA moved
(§3.7) — this is the direct answer to post-hoc criterion relaxation. Replays are
**paired** (same case, old vs new skill, frozen profile, k runs each — §6.1), gated on
permutation p **and** an effect floor (§6.2). Low early power is accepted as
conservatism rather than rationalised away (§6.3). The ablation arm is the headline
evidence, not a debug switch (§6.5). Canaries keep holdouts (§3.5 step 8). Every
ledger row carries doer model and preset/profile (§3.3); the pinned `ops/VERSIONS.md`
supplies the rest.

## 3. Learning happened in side channels with blanket credit, so nothing was attributable

- **Skills themselves never changed.** The 11 hand-written YAML skills were static;
  "learning" was appending reflection text to a vector store and moving-average
  effectiveness scores. The project's own assessment summarised the policy update as
  prompt concatenation (`ST/alignment-steps/00-ASSESSMENT-SUMMARY.md`).
- **Credit was blanket or forced.** Every injected skill received the same
  success/failure outcome; pattern attribution asked the model which pattern was "most
  useful" for a task it was *told* had succeeded, with no "none" option — so credit
  always landed somewhere, whether or not anything helped.
- **Reflections were scored by regex** on specificity/actionability wording, not by
  task outcome.
- **Dead wiring went unnoticed for months** — e.g. 57 teacher calls producing zero
  stored patterns; a phase that passed all tests but never fired in production.

**Graft consequence:** skills are sectioned with stable `[S*]` IDs (§4.1); a blame must
cite a section ID *and* a quote mechanically found in the trace, and the section must
have actually been injected, or the blame is discarded (principle 9, §3.5 step 1).
Edits need N≥3 corroborating episodes, go through a staged diff with evidence IDs in
the commit, and merge only on a graft-stats pass (principle 3). The runtime loop cannot
write skills at all (principle 1). The P1 exit requires 25+ *real* episodes with
verdicts and validated citations — "live proof", not passing unit tests.

## 4. Pitfalls already paid for

| Pitfall | Status in Skill Tree | Graft handling |
|---|---|---|
| Qwen thinking mode: Ollama returns reasoning in a separate `thinking` field; content can come back empty | Confirmed (`ST/.planning/research/PITFALLS-MODEL-SWAP.md`; `ST/skill-tree-agents/llm/ollama_client.py` fallback) | Doer smoke tests read both fields; ledger projection must treat empty content as its own outcome, not a zero |
| Cross-family judge also needed thinking disabled to return content | Confirmed (a Skill Tree ADR on the Gemini grader) | Judge requests pin thinking off explicitly; tier-2 output is grammar-constrained |
| UTF-8 BOM in PowerShell-written JSON breaks parsers | Confirmed (`ST/_ARCHIVE/COMPREHENSIVE_BUG_REPORT.md`) | Graft runs in WSL bash on ext4; nothing is written by PowerShell. Parsers should still reject/strip BOM explicitly |
| Qdrant embedded mode is single-process; tests collide with a running service | Confirmed (Skill Tree foundation phase summary; testing notes) | Graft durable data is plain files + SQLite (principle 8); no vector DB in the design |
| ~37% context overhead | **Not confirmed.** The nearest source says ~50–70K of ~200K tokens (25–35%) for Claude Code sessions. CLAUDE.md's "~37%" should be treated as an estimate | Measure context overhead from Graft's own session logs before relying on any figure |
| VRAM spill on the 8 GB card: 30B MoE ran 72% CPU at ~17 tok/s; a dense 24B timed out at ~3 tok/s | Confirmed (Skill Tree session memory) | One model resident; doer ≤9B Q4_K_M; <25 tok/s treated as spill (RISK-REGISTER #10) |
| Inline post-processing LLM calls without timeouts grew from 5 s to 300 s per task unnoticed | Confirmed (`ST/CLAUDE.md`) | Judge runs after the episode, never blocks it (§3.2); worker loop has hard wall-clock timeouts (§9) |
| In-process counters reset every CLI run; rotating log handlers silently drop history | Confirmed / inferred | Ledger is append-only SQLite; nothing durable lives in process memory or rotating logs |
| Skills injected in the lowest-attention prompt position | Reported in vault research | Injection position is an explicit, logged property of `skill_injected` — a candidate for measurement, not an assumption |

## 5. Concepts worth re-deriving (ideas only — to be re-justified in Graft's terms)

- **Guard layers** (input normalisation/classification; output scanning for
  credentials/PII/prompt leakage; per-role operation permissions). The lesson that
  role-based exemptions were needed to control false positives is worth keeping in
  mind when designing judge tier-1 checkers.
- **Deterministic pre-checks before any LLM grader** — Skill Tree arrived at this late;
  in Graft it is tier-1 by construction.
- **A noise-control arm** (identical config in both groups, same session) to measure
  the per-case noise floor empirically. Candidate input to the SPEC §11 open question
  on revisiting the permutation-vs-Wilcoxon choice once real variance exists.
- **"Live proof before complete"** — a feature is not done until a ledger field shows
  it firing on real episodes.
- **A findings-corrections log** ("previously believed / actually true") — Graft's
  equivalents are post-mortem ADRs on reverts (§3.5 step 11) and PROGRESS.md.

## 6. Corpus — for the record, and not Graft's seed

Verified by file count: 11 `*.skill.yaml` (in `ST/skill-tree-agents/skills/`), 5
`claude-code/*.md`, 2 `.claude/skills/` entries — matching CLAUDE.md. A 32-entry
`ST/_ARCHIVE/claude-skills/` archive is the likely source of an earlier draft's "25
skills" claim. None of it is imported: Graft's three Phase 1 seed skills are authored
fresh (§4.1, BACKLOG), and the rest are grown from Graft's own verified episodes.
