"""graft-calibrate — calibration curves over (raw_conf, outcome) pairs (SPEC §3.6).

Raw logprobs are inputs, not truths (CLAUDE.md principle 5). This module fits
Platt scaling and isotonic regression per context and emits
``data/calibration/{judge,router}.json`` with fields
``{method, params, fitted_at, n, brier}``.

Phase 0: signatures and docstrings only. No fitting is implemented.
"""

from collections.abc import Iterable, Mapping
from dataclasses import dataclass
from typing import Literal

MIN_PAIRS: int = 100
"""Cold-start guard: ``fit`` refuses to emit a curve from fewer than this many pairs."""

CalibrationContext = Literal["judge", "router"]
CalibrationMethod = Literal["platt", "isotonic"]


@dataclass(frozen=True, slots=True)
class CalibrationCurve:
    """A fitted calibration curve, serialised to ``data/calibration/<context>.json``.

    Fields mirror SPEC §3.6: ``{method, params, fitted_at, n, brier}``.
    """

    method: CalibrationMethod
    params: Mapping[str, float | list[float]]
    fitted_at: str  # ISO-8601 UTC timestamp
    n: int
    brier: float


def fit(pairs: Iterable[tuple[float, bool]], context: CalibrationContext) -> CalibrationCurve:
    """Fit a calibration curve for ``context`` from ``(raw_conf, outcome)`` pairs.

    Fits both Platt scaling and isotonic regression and records the Brier score
    of the emitted curve.

    Refusal rule: raises (and emits nothing) when fewer than ``MIN_PAIRS`` (100)
    pairs are supplied — the cold-start guard. Below that threshold, decisions
    must not gate on a calibrated probability at all.

    Only the consolidation pipeline calls this; LLMs never call it ad hoc.
    """
    raise NotImplementedError("Phase 1+/P2: calibration fitting (Platt + isotonic) not implemented")
