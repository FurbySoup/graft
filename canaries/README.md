# canaries/

Per-skill regression cases, `canaries/<skill_id>/<case>.yaml` (SPEC §4.2). **Empty in
Phase 0.**

- **Deterministic success criteria only.** A canary a judge has to score is an invalid
  canary.
- ≥8 cases per skill (target 10), replayed k times per version on the frozen
  `graft-replay` profile (SPEC §6.3, `ops/stats.yaml`).
- Cases with `holdout: true` are human-owned (SPEC §9 hard exclusion) and are never
  used to draft edits.
