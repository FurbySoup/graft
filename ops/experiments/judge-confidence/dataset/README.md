# Judge-confidence dataset (R-03)

A hand-authored, deterministic-ground-truth evaluation set for the ADR "judge confidence"
(backlog item R-03): it is used to compare ways of deriving the judge's (phi4-mini) confidence
that a candidate Python solution correctly solves its task. n=24, deliberately small.

- **Contents:** 6 micro-kata tasks (`tNN-<slug>/`), each with a spec (`task.md`), a hidden
  stdlib-only test (`test_hidden.py`, 10-13 cases incl. edge cases) and 4 candidate solutions
  (`candidates/c01.py`..`c04.py`). Candidates carry no comments; their order within a task was
  shuffled so position does not reveal correctness.
- **Labels (`labels.csv`):** derived only from the hidden test's exit code, never from opinion:
  `python3 tNN-<slug>/test_hidden.py tNN-<slug>/candidates/cNN.py` - exit 0 = `correct`,
  anything else = `incorrect` (import errors, exceptions and >5s calls count as failures).
- **Counts:** 12 `correct`, 12 `incorrect` (2 of each per task). Incorrect candidates carry
  plausible, subtle bugs (dropped final run, case folding, missing subtractive form, off-by-one
  comparison, unchecked leftover stack, tie-breaking by first occurrence, accepting lowercase
  `x`), not syntax errors.

Regenerate labels from this directory:

```sh
echo "item_id,task,candidate,label" > labels.csv
for t in t*/; do t=${t%/}; for c in $t/candidates/c*.py; do cn=$(basename $c .py)
  python3 $t/test_hidden.py $c >/dev/null && l=correct || l=incorrect
  echo "${t%%-*}-$cn,$t,$cn,$l" >> labels.csv; done; done
```

The judge must never see `test_hidden.py` or `labels.csv`; it receives only `task.md` and one
candidate.
