"""graft-stats — the deterministic statistics engine (SPEC §3.7, §6).

Statistics are code (CLAUDE.md principle 4): p-values, effect sizes and trend
claims come only from here, computed against the pre-registered
``ops/stats.yaml``. The consolidator (or any LLM) reads verdicts; it never
computes them.

Phase 0: signatures and docstrings only. No statistics are implemented.
"""

from collections.abc import Iterable, Mapping
from dataclasses import dataclass
from os import PathLike


@dataclass(frozen=True, slots=True)
class GateVerdict:
    """Machine-readable merge-gate verdict for one staged skill edit (SPEC §3.7).

    Fields: ``{edit_id, test, p, effect_size, median_delta, pass, config_sha}``.
    ``pass`` is a Python keyword, so it cannot be a dataclass field name; the
    attribute is ``pass_`` and serialises to the JSON key ``"pass"``.
    """

    edit_id: str
    test: str
    p: float
    effect_size: float
    median_delta: float
    pass_: bool
    config_sha: str

    def to_dict(self) -> dict[str, str | float | bool]:
        """Serialise with the exact SPEC §3.7 keys (``pass_`` -> ``"pass"``)."""
        return {
            "edit_id": self.edit_id,
            "test": self.test,
            "p": self.p,
            "effect_size": self.effect_size,
            "median_delta": self.median_delta,
            "pass": self.pass_,
            "config_sha": self.config_sha,
        }


def run_gate(
    replay_results: Iterable[Mapping[str, object]],
    stats_config_path: str | PathLike[str],
) -> GateVerdict:
    """Run the pre-registered merge gate over a complete paired replay batch.

    Input: paired canary replay results (same cases, old vs new skill, k runs
    each) and the path to the committed ``ops/stats.yaml``.

    Pre-registration refusal rules — the function refuses to run (raises, emits
    no verdict) if:
      * ``ops/stats.yaml`` has uncommitted changes (dirty working tree), or
      * its config SHA differs from the SHA committed before the replay batch
        started.
    This is what stops the test being chosen after seeing the data.

    Gate (SPEC §6.2): exact permutation test on paired per-case pass-rate deltas
    at the configured alpha (Benjamini–Hochberg across the cycle's edits) AND
    median delta >= the configured effect floor. Both must hold for ``pass_``.
    Wilcoxon signed-rank is reported alongside, with its caveats.

    Only the consolidation pipeline invokes this, and only on complete replay
    batches; LLMs never call it ad hoc.
    """
    raise NotImplementedError("Phase 1+/P2: graft-stats merge gate not implemented")
