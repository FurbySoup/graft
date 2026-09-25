# @furbysoup/graft-trust

Runtime plugin that wraps the dsh skills plugin: owns the view of which skill,
at which version, with which sections, was put in context for an episode
(SPEC §3.1).

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

## Responsibility (SPEC §3.1)

- Read the skill registry (`skills/registry.yaml`): id, version (git SHA),
  state ∈ {probation, trusted, deprecated, retired}, stats.
- Load-time filtering/flagging: probation skills injected with a probation
  banner; retired skills never injected.
- Honour the **skills-off bypass flag** for the ablation arm (SPEC §6.5) — headline
  evidence, not a debug switch.
- Emit `skill_injected` events: {episode_id, skill_id, version, section_ids}.

## May

- Read `skills/registry.yaml` and skill files.
- Emit `skill_injected` events.
- Honour the skills-off bypass flag.

## Never

- Edit skills (skill edits are pull requests, produced offline — principle 3).
- Change a skill's lifecycle state or stats — only the consolidator does, via file.
- Write to canaries or calibration data.
