# ops/

| Path | What | Owner |
|---|---|---|
| `VERSIONS.md` | Every pin: dsh, Node, pnpm, Ollama, model tags + digests, profile hashes | human (hard exclusion) |
| `stats.yaml` | Pre-registered statistics config (SPEC §4.3); standalone human-merged commits only | human (hard exclusion) |
| `dsh/home/` | `DSH_HOME` for every Graft dsh run. Profiles committed; state/secrets gitignored | human (dsh config) |
| `presets/graft-replay/` | Frozen replay profile — never drifts (see its README) | human (dsh config) |
| `scripts/dsh` | The only sanctioned dsh entry point (sets `DSH_HOME`, disables telemetry) | human (dsh config) |
| `automation/` | Phase 0.5 worker loop (not yet built) | — |

Run dsh only as `ops/scripts/dsh --profile <graft|graft-replay> …`, from the workspace
the task should be confined to (dsh's sandbox root is the invoking directory).
