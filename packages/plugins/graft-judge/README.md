# @furbysoup/graft-judge

Runtime plugin that verifies episode outcomes independently of the doer and
emits verdicts (SPEC §3.2).

## Status

**Phase 0: stub — logs mount/unmount only.** No other behaviour. Not mounted into
any dsh profile or config. Phase 1 internals are deliberately not designed here.

## Shape

Cordis module-namespace plugin (`export const name`, `export function apply(ctx)`),
the same convention dsh's own plugins use. Depends on `@deepseek-ai/cordis`
pinned exactly to the version dsh uses (`4.0.2`, recorded in `ops/VERSIONS.md`).

## Rules shared by all Graft runtime plugins

- **Thin shim** (CLAUDE.md principle 8). This package contains dsh/Cordis
  adaptation only; all logic lives in `packages/core` (harness-agnostic).
  Only `packages/plugins/*` may import dsh/Cordis APIs (SPEC §2).
- **Online observes, offline mutates** (principle 1). May append events and read
  config. Never writes to `skills/`, trust states, canaries, or calibration.
- Mounts beside dsh's plugin seams; patches nothing (SPEC §2).
- Autonomous dev runs never touch dsh config, `skills/`, or `skills/registry.yaml`
  (SPEC §9).

## Responsibility (SPEC §3.2)

- Subscribe to task-completion and tool-result events.
- **Tier 1 — deterministic checkers first**, registered per task type (exit codes,
  test runners, schema validation, file existence/diff-applies, HTTP status).
  Verdict: pass / fail / not-applicable. Decisive when it fires.
- **Tier 2 — judge model** only when tier 1 is not decisive: a *different model
  family* from the doer, fresh context, sees task spec + artifacts + tier-1
  results. Grammar-constrained output `{verdict, blame?, notes}`; raw
  choice-token logprob captured.
- Apply the calibration curve (`data/calibration/judge.json`) to produce
  `p_correct`; below threshold ⇒ verdict marked `queued_for_review`.
- Emit `verdict` events.

## May

- Observe task-completion and tool-result events.
- Run tier-1 checks, then (only if not decisive) the tier-2 judge.
- Read the calibration curve.
- Emit `verdict` events, including blames of the form {section_id, quote}
  (principle 9: blames must cite; validation happens against the ledger).

## Never

- **Block, retry, or modify the run.**
- See the doer's reasoning (principle 2: the doer never grades its own work).
- Use a judge from the doer's model family.
- Skip tier 1 or let tier 2 override a decisive tier-1 result.
- Write calibration data (refit is offline, graft-calibrate).
