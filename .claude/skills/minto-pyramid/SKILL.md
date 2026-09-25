---
name: minto-pyramid
description: Structure any Graft communication that carries a conclusion — PR bodies, session close-outs, consolidation write-ups, ADRs, blocked-item notes, dashboard copy — answer first, then grouped support, then evidence. Use when writing or reviewing these artifacts; not needed for code comments or commit subject lines.
---

# Minto Pyramid for Graft communication

Readers of this project are one person with limited review time and an automated
review agent. Both need the conclusion before the reasoning.

## The shape

1. **Answer first.** One sentence: what is true, or what you want. Never open with
   background, chronology, or what you attempted.
2. **Then 2–4 grouped supporting points**, MECE (mutually exclusive, collectively
   exhaustive) — each a claim, not a topic label. "Canary pass rate rose on holdout
   too" is a claim; "Canary results" is a label.
3. **Then evidence under each point**: numbers, episode IDs, stats verdicts, file
   paths, test output. Detail lives at the bottom, where it can be skipped.

Every level answers the question the level above provokes ("why?" / "how?").

## Graft-specific rules

- **Claims about improvement cite a graft-stats verdict** (`edit_id`, test, p,
  effect size, `config_sha`) or they are not claims. Never compute or characterise
  statistics in prose yourself.
- **No point-to-point conclusions** anywhere — trends are EWMA over rolling
  windows (SPEC §6.4). "Up from last run" is not a finding.
- **Evidence means IDs.** Episode IDs, section IDs, canary case IDs, commit SHAs.
  A supporting point with no ID under it belongs in the open-questions list.
- **Lead with the bad news** when there is bad news: a failed gate, a hit iteration
  cap, a reverted merge, a deviation from SPEC. Do not bury it under what worked.
- **Uncertainty is stated, not implied.** "Underpowered: n=5, min two-sided
  p=0.0625" beats hedging adverbs.

## Per-artifact openers

| Artifact | First line answers |
|---|---|
| PR body | What this changes and why it is safe to merge |
| Session close-out | Which phase exit criteria are ticked, which are not |
| Consolidation write-up | Which edits merged, which were rejected, by which verdict |
| ADR | The decision, in the imperative |
| Revert post-mortem | Which gate agreed on something false, and where it broke |
| Blocked backlog item | What stopped it, in one sentence, before the attempt log |

## Check before sending

- Could the reader stop after line 1 and still act correctly?
- Do the supporting points survive on their own, without the narrative order?
- Is anything at level 2 actually level 3 detail?
- Is every number traceable to a file, row, or verdict?
