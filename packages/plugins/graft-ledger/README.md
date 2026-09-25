# @furbysoup/graft-ledger

Runtime plugin that projects the dsh session stream into the evidence ledger,
`data/ledger.sqlite` (SPEC §3.3).

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

## Responsibility (SPEC §3.3)

- **Sole consumer of the raw dsh session stream** — the isolation layer for
  session-format churn. Nothing else in Graft reads the raw stream.
- Project episodes, injections, verdicts, blames, outcomes, calibration log and
  merges into `data/ledger.sqlite` (schema in SPEC §3.3; owned by
  `packages/core`).

## May

- Consume the raw session stream.
- Append rows to `data/ledger.sqlite`.

## Never

- Update or delete rows — **append-only; corrections are new rows**.
- Let any other component depend on the raw session format.
- Write to `skills/`, trust states, canaries, or calibration.
