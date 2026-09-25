# graft-replay — the frozen replay profile

**This profile never drifts.** Canary replays compare an old skill against a new one on
identical cases; the only variable allowed to change between arms is the skill text
(SPEC §2, §3.5 step 4). If this profile changes, every replay before the change stops
being comparable with every replay after it.

## Rules

1. **No edits during a consolidation cycle.** Ever.
2. **Any change is a deliberate, standalone, human-merged commit** — never bundled with a
   skill edit, never made by the worker loop (SPEC §9 hard exclusion: dsh config). The
   commit body explains why, and `ops/VERSIONS.md` records the new hashes. Treat it like
   a change to `ops/stats.yaml`: it starts a new comparability epoch.
3. **The doer is pinned by composition.** The single `ollama-local` route lists exactly
   one model; a replay driver asking for any other model fails with `UNKNOWN_MODEL`.
   The model id must match the tag + digest recorded in `ops/VERSIONS.md`.
4. **No user settings layer.** The tree has no `settings` / `credentials` rows, so a
   `settings.yaml` in `DSH_HOME` cannot override anything here.

## What it is

dsh 0.1.5-rc.3 has no "Minimal preset"; the nearest thing is the shipped `sdk-minimal`
profile — a complete standalone tree (no dsh-base, no skills plugin, no filesystem
tools, no workspace instructions, no telemetry). This profile inlines that tree
**verbatim** (Part 1 of `cordis.patch.yml`) and lists **no bundles** in `package.json`,
so a dsh upgrade cannot silently change which rows compose. Graft's deltas are
id-targeted in Part 2:

| Delta | Why |
|---|---|
| `llm-pi-ai` inserted with one Ollama route | Local doer only; enforces the model pin |
| DeepSeek adapter, API extensions, session-log upload, package inventory disabled | No cloud model, no upload path |
| `sandbox-policy` → `workspace-write` (upstream: `danger-full-access`) | Replays stay confined to their workspace (RISK-REGISTER #2) |
| session root → `data/dsh-sessions/replay` | Replay logs live beside, not inside, live-run logs |

`sdk-minimal` is driven over JSON-RPC stdio by an SDK client (the model is selected in
the client's initialisation request), not by a one-shot command line. The Phase 2 replay
driver is therefore an SDK client. Skill text reaches the doer through whatever
graft-trust injects — that is the sole experimental variable.

## Drift check

```bash
sha256sum ops/presets/graft-replay/package.json ops/presets/graft-replay/cordis.patch.yml ops/presets/graft-replay/cordis.yml
```

must equal the hashes recorded in `ops/VERSIONS.md`. The composed tree is inspectable
with `ops/scripts/dsh --profile graft-replay --dump-config` (resolved through the
`ops/dsh/home/profiles/graft-replay` symlink).
