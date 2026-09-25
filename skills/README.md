# skills/

Sectioned `SKILL.md` files (SPEC §4.1) and `registry.yaml` (SPEC §3.1). **Empty in
Phase 0.**

- **Human-owned.** A hard-exclusion path (SPEC §9): autonomous runs never write here.
- **Offline mutation only.** Runtime plugins read; only the consolidation pass changes
  skills, via staged diffs with evidence episode IDs, N≥3 corroboration, canary replay
  and a graft-stats pass (CLAUDE.md principles 1 and 3).
- **Nothing imported.** Phase 1 seeds 3 hand-authored skills (≥2 kata-facing); every
  later skill is grown from Graft's own verified episodes and enters as `probation`.
  Skill Tree is reference only (`docs/prior-art-skill-tree.md`).
