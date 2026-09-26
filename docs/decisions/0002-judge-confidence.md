# 0002 — How tier-2 judge confidence (`raw_conf`) is derived

- Status: **Proposed**. R-03 is owner-only, so Mark accepts or amends this ADR.
- Date: 2026-09-26
- Deciders: Mark. Evidence gathered in the Phase 1 readiness session.
- Evidence: `ops/experiments/judge-confidence/` (dataset, `eval.py`, `results.json`)

## Decision (proposed)

**On this evidence, no derivation of `raw_conf` is worth choosing. The judge itself,
phi4-mini, cannot tell correct from incorrect kata code: AUROC is 0.44–0.56 across all
five methods, which is chance.** So:

1. **Reject the SPEC §3.2 status quo.** That is the probability of the sampled verdict
   token under grammar constraint (method A). It is pre-grammar-mask (Phase 0 finding),
   and here it is also uninformative (AUROC 0.48).
2. **Plumb `raw_conf` for P1-09 as a renormalised option likelihood (method A2).** This
   is the same single grammar-constrained call SPEC §3.2 already makes,
   `{verdict, blame?, notes}`. `raw_conf` is the pass-token mass divided by the pass+fail
   mass among `top_logprobs` at the verdict position. It keeps SPEC's output contract and
   adds no extra model call. It is **plumbing, not a validated signal**. P1-09 stays
   record-only, and nothing may gate on `raw_conf` until calibration shows discrimination.
3. **Re-open the judge-model choice before P3.** The new backlog item R-08 evaluates at
   least one stronger CPU-resident, non-Qwen judge on this dataset plus judged-domain data
   once D-01 exists.

## Why

1. **Discrimination is the binding constraint, not the readout.** Every method's AUROC
   sits within about one null standard error of 0.5. A rough null-variance approximation
   for 12 vs 12 gives an SE of about 0.12. No method is distinguishable from another, or
   from chance, at n=24. Choosing between them now would be choosing on noise.
2. **The failure is systematic, not random.** Under both grammar orders (A, D), phi4-mini
   says `pass` on 10 of 12 incorrect candidates. With free analysis first (C) it flips to
   heavy scepticism: 7 of 12 correct candidates get p<0.05. The model reports its prior
   about code, not the code.
3. **This does not undermine Phase 1.** Katas are the tier-1 domain (CLAUDE.md, SPEC §7).
   Their verdicts come from hidden tests, and tier-2 only runs where tier-1 is not
   decisive. The finding matters for P3 calibration and for the second domain (D-01). It
   is cheap to learn now and expensive later.

## Results (n=24: 12 correct / 12 incorrect; `results.json`)

Setup:
- **Judge:** `graft-judge:cpu` (phi4-mini, CPU), temperature 0, seed 7, `num_ctx` 4096,
  `top_logprobs` 20.
- **What the judge sees:** the task spec and one candidate only. No tests, no tier-1
  results, no labels.
- **Labels:** hidden-test exit codes. Six micro-katas × 4 candidates, two subtly buggy
  per task.

| Method | Derivation | Accuracy @0.5 | AUROC | Brier | ECE (5 bins) | Mean s / item |
|---|---|---|---|---|---|---|
| A | grammar, verdict first, sampled-token prob (SPEC §3.2 status quo) | 0.458 | 0.479 | 0.426 | 0.449 | 9.8 |
| A2 | same call, pass/(pass+fail) renormalised over `top_logprobs` | 0.458 | 0.472 | 0.466 | 0.472 | (same call) |
| D | grammar, `notes` before `verdict`, renormalised | 0.458 | 0.465 | 0.510 | 0.521 | 9.2 |
| B | unconstrained one-token yes/no likelihood | 0.417 | 0.444 | 0.416 | 0.384 | 0.4 |
| C | free analysis (≤300 tokens), then B's question | 0.583 | 0.556 | 0.400 | 0.395 | 30.6 |

- D produced no pass/fail mass at the verdict position for one item, scored as 0.5.
- The metrics were computed by `eval.py`, deterministically. No model computed them.
- Each method ran once. That is deterministic at temperature 0, so there was no need to
  run k samples.

## Alternatives considered

- **Pick C (best point estimate).** Rejected: 0.556 is within noise, it triples judge
  latency, and its errors are a scepticism bias, not a signal.
- **Pick B (cheapest).** Rejected as the primary readout: it produces no `notes` or
  `blame`, which SPEC §3.2 requires for blame citation. It remains an option alongside a
  grammar call.
- **Keep A as SPEC wrote it.** Rejected: pre-mask, and uninformative here.
- **Give the judge the tier-1 results or the tests.** Not evaluated. SPEC lets tier-2 see
  tier-1 results. On katas that makes tier-2 redundant, not better calibrated, which says
  nothing about domains where tier-1 is silent.

## Consequences

- P1-09 implements A2 as record-only and captures the full `top_logprobs` at the verdict
  position, so any later derivation can be recomputed from the ledger without re-running
  the judge.
- R-08 is added: evaluate a stronger CPU-resident, non-Qwen judge before P3, using the same
  harness (`eval.py --model …`).
- The dataset is deliberately small. It can be grown, but calibration curves are fitted
  on real episodes (P3), not on it.

## Limitations

- n=24 across six katas, one judge prompt wording, and temperature 0.
- The prompt wording was not tuned. A better prompt might move the numbers, but an
  untuned 3.8B judge at chance is the finding.
- The candidates were written by a Claude subagent, and a model from the same family
  wrote the tasks. They carry no hints (comments were stripped and order shuffled), but
  they are not doer output.
