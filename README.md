# Graft — starter pack

A harness for skill self-improvement without self-corruption, built as thin plugins on
DeepSeek Harness (dsh), running on local open models. Successor to the Skill Tree
project's learning loop, with the missing piece supplied: independent, calibrated
validation between "the agent thinks it succeeded" and "the skill gets changed."

> Naming: "Graft" — a candidate shoot (scion) joined to proven rootstock; the union
> must take before it grows. Rename is a find-and-replace across this pack if a
> better name wins. Publish npm packages scoped: `@furbysoup/graft-*`.

## What's in this pack

| File | Purpose |
|---|---|
| `README.md` | This file. |
| `CLAUDE.md` | Project memory for Claude Code. Copy to the new repo root as-is. |
| `SPEC.md` | Full build specification: architecture, data model, phases, acceptance criteria. |
| `SESSION-1-PROMPT.md` | Paste-ready kickoff prompt for the first Claude Code session (Phase 0). |
| `SESSION-2-PROMPT.md` | Paste-ready prompt for Session 2: the Phase 0.5 autonomous worker loop. |
| `RISK-REGISTER.md` | Known risks, mitigations, and review triggers. |

**v0.2 additions:** Phase 0.5 dev-automation loop (worker + review agent + cron;
you groom the backlog and review PRs instead of driving sessions) · statistical
merge gate (pre-registered `ops/stats.yaml`, paired permutation/Wilcoxon tests,
effect floor, ablation arm) · launch task domain (micro-katas; the second domain
is an open decision — see SPEC §7) ·
**graft-dash**, a required visual improvement tracker (SPEC §3.8): what it must
make visible is fixed — EWMA trends, merge events lined up against them,
calibration, ablation gap, revert log — while its form is an open decision, taken
in Phase 1 once there is real data to look at.

## How to use it

The pack is unpacked; this repo *is* the project. It lives at `~/graft` in WSL2
Ubuntu (moved there 2026-09-25, pre-Phase-0 — see CLAUDE.md, Environment).

1. Open Claude Code in WSL2 at `~/graft` and paste the contents of
   `SESSION-1-PROMPT.md`. It opens with the prerequisites and the verified
   environment facts — read those before running anything.
2. Session 1 is Phase 0 only: prerequisites, sandbox, scaffold, pinned dsh install,
   model verification. Resist building ahead of the phase gates.
3. Session 2 (`SESSION-2-PROMPT.md`) is Phase 0.5, and only once the Phase 0 exit
   checklist is ticked.

Skill Tree is reference material only — the failed first iteration of this ethos,
valuable for its research and the anatomy of its failure. Nothing is copied out of
it into Graft. See CLAUDE.md, "Skill Tree — reference only".

## Ground rules (also in CLAUDE.md — the short version)

- The online loop observes and records. Only the offline loop mutates.
- The doer never grades its own work.
- Skill edits are staged diffs with evidence, never live commits.
- Everything durable lives in plain files (git, SQLite, YAML, JSON) — dsh is a
  replaceable chassis, not a dependency of record.
- Personal project, personal kit. Nothing employer-related enters this environment.
