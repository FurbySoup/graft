# graft-calibrate (sidecar)

Offline Python sidecar holding two components: **graft-calibrate** (SPEC §3.6) and
**graft-stats** (SPEC §3.7). It is the only place in Graft where calibrated
probabilities, p-values, effect sizes and gate verdicts are produced.

**Phase 0: stubs only.** Public entry points (`fit`, `run_gate`) have signatures
and docstrings and raise `NotImplementedError`. No statistics are implemented.
Zero third-party dependencies; numpy/scipy are added only after Mark approves
PyPI access (tracked in `BACKLOG.md`).

## Responsibility

- `graft_calibrate.calibrate.fit(pairs, context) -> CalibrationCurve` — Platt
  scaling + isotonic regression over `(raw_conf, outcome)` pairs per context;
  emits `data/calibration/{judge,router}.json` `{method, params, fitted_at, n, brier}`.
- `graft_calibrate.stats.run_gate(replay_results, stats_config_path) -> GateVerdict` —
  deterministic merge gate over paired canary replays against the committed
  `ops/stats.yaml`; verdict `{edit_id, test, p, effect_size, median_delta, pass, config_sha}`
  (`pass` is `pass_` on the dataclass, `"pass"` via `to_dict()`).

## May

- Read paired replay results, calibration pairs, and the committed `ops/stats.yaml`.
- Write `data/calibration/*.json` and machine-readable gate verdicts.
- Be invoked by the consolidation pipeline (SPEC §3.5), on complete replay batches only.

## Never

- Never computes statistics outside the consolidation pipeline; LLMs (including the
  consolidator) never call these functions ad hoc — they read verdicts, never compute them.
- Never runs on a dirty `ops/stats.yaml`, or one whose SHA differs from the SHA
  committed before the replay batch started (pre-registration enforcement).
- `calibrate` never emits a curve below n=100 pairs (`MIN_PAIRS`, cold-start guard).
- Never passes an edit on significance alone or effect size alone — both gates must hold.
- Never runs on partial replay batches.
- Never writes to `skills/`, trust states, canaries, or `ops/stats.yaml`.

## Tests

Run from the repo root (`/home/mark/graft`), using the existing venv — no install step:

```sh
# all
sidecars/calibrate/.venv/bin/python -m unittest discover -s sidecars/calibrate/tests -t sidecars/calibrate
# one file
sidecars/calibrate/.venv/bin/python -m unittest discover -s sidecars/calibrate/tests -t sidecars/calibrate -p test_scaffold.py
```
