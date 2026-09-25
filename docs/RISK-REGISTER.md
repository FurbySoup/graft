# Graft — Risk Register

Review cadence: at every phase gate, and after any dsh upgrade.

| # | Risk | Sev / Likelihood | Mitigation | Trigger to revisit |
|---|---|---|---|---|
| 1 | dsh preview churn — breaking changes promised by the project itself | High / Certain | Exact version pin; thin shims (`packages/plugins` only may import dsh APIs); ledger is sole session-format consumer; budget an adapter-repair day per upgrade | Any dsh release note; any plugin API deprecation |
| 2 | dsh has no security audit; agent has shell access | High / Medium | WSL2 only; dedicated non-admin workspace; no credentials in reach; localhost-only model endpoints; hard wall: no employer data ever | Before adding any network-capable tool or MCP server |
| 3 | Correlated judge failure — judge shares the doer's systematic blind spots | High / Medium | Enforced different model family; deterministic tier always first; standing 5% random human audit of verdicts logged as outcomes | Audit disagreement rate > 15% |
| 4 | Canary Goodharting — skills evolve to pass the set, not the job | Med / Medium | Rotate canaries; age cap; holdout cases; refresh from recent real episodes each consolidation | Canary pass-rate rising while human audit satisfaction flat/falling |
| 5 | Calibration cold start — no curves before ~100 outcomes | Med / Certain early | Phase 1 is observation-only; promotion manual until curves exist; calibrate sidecar refuses n<100 | Automatic at P3 entry |
| 6 | Calibration drift as task mix shifts | Med / Slow | Rolling Brier score in ledger; recalibration is a standing consolidation step | Brier degrades 2 consecutive consolidations |
| 7 | Noise-driven promotions (n too small) | Med / Medium | N≥3 corroboration; k=5 replays; no-regress gate; accept slow learning as the design | Any merged edit later reverted — do a post-mortem |
| 8 | Skill sprawl / duplicates | Low / Medium | Embedding dedup (cosine <0.85) at creation; consolidation merges near-dupes; probation caps blast radius | Registry >50 skills |
| 9 | Solo-dev scope creep across the project portfolio | High / High | Phase gates with written exit criteria; P1 delivers standalone value (observable evidence ledger) even if the project stops there | Starting any P(n+1) work before P(n) exit checklist is ticked |
| 10 | VRAM contention / PCIe spill collapse (30× slowdowns reported on 8GB cards) | Med / Medium | One model resident in VRAM; judge on CPU; text-only doer GGUF; watch tokens/sec in smoke tests | Doer <25 tok/s on P0 smoke test |
| 11 | Unattended worker loop wanders, burns quota, or commits junk | Med / Medium | PR-only, never merges; protected main; iteration cap ≤5; hooks gate commits on green tests; hard-exclusion paths enforced in script AND prompt; per-run timeout; runaway test in P0.5 exit | Any auto PR with failing CI; weekly quota review |
| 12 | Improvement tracker becomes its own project | Med / High | Required content fixed by SPEC §3.8 while its form stays an explicit ADR decision — so scope is bounded by information needed, not by how good it could look; anything beyond v0 requires evidence of use; at most one tracker backlog item per cycle | Tracker work exceeding ~10% of merged PRs |
| 13 | Statistical gate gamed — consolidator LLM p-hacks or reinterprets results | High / Low | Pre-registered ops/stats.yaml committed before replay batch; graft-stats deterministic and refuses stale/uncommitted config; stats.yaml changes are standalone human-merged commits | Any stats.yaml change bundled with a skill edit |
