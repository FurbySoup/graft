# 0001 — Build on dsh, pinned exactly, behind thin shims

- Status: Accepted
- Date: 2026-09-25
- Deciders: Mark (SPEC v0.2), recorded in Session 1 / Phase 0

## Decision

**Use DeepSeek Harness (dsh) as Graft's runtime chassis, pinned to one exact version
(`@deepseek-ai/dsh@0.1.5-rc.3`, lockfile-frozen), and keep every dsh/Cordis-facing line
of code in `packages/plugins/*` as adaptation only — all Graft logic lives in the
harness-agnostic `packages/core`, and all durable data lives in plain files Graft owns.**

## Why

1. **dsh already supplies the evidence substrate Graft would otherwise have to build.**
   Its append-only JSONL session log records system prompts, reasoning, tool calls and
   results, and every context injection — exactly what blame citations must be validated
   against (SPEC §2, principle 9). Profiles give a frozen replay configuration and a
   standard working one; Cordis plugin seams let Graft mount *beside* the skills,
   session and model plugins without patching them.
2. **The risks are known and boundable.** dsh is pre-1.0 and RC-tagged, with breaking
   changes promised (RISK-REGISTER #1) and no security audit (#2). An exact pin plus a
   committed lockfile removes incidental churn (dsh's own internal deps use `^` ranges,
   so the top-level pin alone would not); thin shims cap the repair cost of a deliberate
   upgrade; graft-ledger as the *sole* consumer of the raw session stream confines format
   churn to one package.
3. **The exit is cheap by construction.** Because the ledger, skills, canaries, stats
   config and calibration are plain files (SQLite, YAML, Markdown, JSON), replacing the
   chassis means rewriting `packages/plugins/*` — not migrating data.

## Alternatives considered

| Alternative | Why not |
|---|---|
| **Bespoke agent loop over the Ollama API** | Full control and no preview-software risk, but Graft would have to build and maintain its own tool sandbox, session persistence, replay/fork mechanics and event log — the substrate is most of the work, and a home-grown log is exactly the kind of unaudited evidence source Graft exists to avoid trusting. Remains the fallback if dsh proves unrepairable. |
| **Claude Code as the doer harness** | Mature, but the doer must be a local open model (SPEC §5); Claude is the offline consolidator and must never be in the runtime loop. Using the consolidator's harness as the doer's harness also blurs the doer/consolidator separation. |
| **Another open agent harness** | Not evaluated against Graft's needs on evidence; none was named in SPEC. Revisit only with a concrete defect in dsh that another harness demonstrably lacks. |
| **dsh unpinned / tracking a dist-tag** | Rejected outright: tags move (on 2026-09-25 `latest`=0.1.5-rc.3, `next`=0.1.7-rc.2, `alpha`=0.1.7-alpha.2), and an incidental upgrade mid-cycle would invalidate replay comparability. |

## Consequences

- **Upgrades are deliberate tasks** with an adapter-repair budget, recorded in
  `ops/VERSIONS.md`, and trigger a RISK-REGISTER review (#1). Never incidental.
- **Only `packages/plugins/*` may import `@deepseek-ai/*`.** `packages/core` stays
  harness-agnostic and is tested without dsh.
- **dsh's defaults are not Graft's defaults.** Observed in 0.1.5-rc.3 and overridden in
  the committed profiles: OTel session upload (`FEEDBACK_ONLY` to a DeepSeek endpoint),
  web search/fetch tools, DeepSeek API session-log/package-inventory enrichments, the
  DeepSeek cloud adapter, and LLM-generated session titles. `ops/scripts/dsh` is the only
  sanctioned entry point. Every override is listed in `ops/VERSIONS.md`.
- **SPEC vocabulary diverges from dsh's.** SPEC says "presets" (Minimal / Standard); dsh
  0.1.5-rc.3 has *profiles*. Standard ≈ profile `graft` (headless over dsh-base); Minimal
  ≈ frozen `graft-replay`, derived from the shipped `sdk-minimal` tree, which is an SDK
  (JSON-RPC) surface rather than a one-shot CLI. The ledger keeps the SPEC column name
  `preset`.
