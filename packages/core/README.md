# @furbysoup/graft-core

Harness-agnostic Graft logic. SPEC §2: "all Graft logic harness-agnostic in
`packages/core`; only `packages/plugins/*` may import dsh/Cordis APIs." Plugins are
thin shims that adapt dsh events into calls on this package (CLAUDE.md principle 8).

Currently contains the ledger schema (SPEC §3.3): row types in
`src/ledger/schema.ts`, SQL in `migrations/`, and `migrate` / `openLedger` in
`src/ledger/migrate.ts` (Node built-in `node:sqlite`, no runtime dependencies).

## May

- Hold the logic that plugins and offline tools share: types, ledger schema and
  access, validation, pure decision functions.
- Read and append to the ledger. Durable data is plain files (`data/ledger.sqlite`).
- Read calibrated probabilities and graft-stats verdicts produced elsewhere, and
  gate on them.
- Mechanically validate blame citations (section ID + quote found in the trace, and
  the section was actually injected) — CLAUDE.md principle 9.

## Never

- Import `@deepseek-ai/*`, Cordis, or any other harness API. That belongs in
  `packages/plugins/*`.
- Update or delete ledger rows. The ledger is append-only; corrections are new rows
  (SPEC §3.3). The migration installs triggers that abort any UPDATE or DELETE.
- Compute p-values, effect sizes, or trend claims. graft-stats owns them against the
  pre-registered `ops/stats.yaml` (SPEC §6.1, CLAUDE.md principle 4).
- Fit calibration curves. graft-calibrate (Python sidecar) owns them (SPEC §3.6).
- Write to `skills/`, trust states, canaries, or calibration from runtime code paths
  (online observes, offline mutates — CLAUDE.md principle 1).
- Block, retry, or modify a run from verification code (SPEC §3.2).
- Use `any`, `@ts-ignore`, or unjustified non-null assertions (strict TypeScript).

## Commands

From the repo root:

```sh
pnpm --filter @furbysoup/graft-core test   # vitest
npx tsc -b packages/core                   # typecheck + build (includes tests)
npx eslint packages/core
```
