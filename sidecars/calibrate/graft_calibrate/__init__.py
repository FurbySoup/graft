"""graft-calibrate sidecar: calibration fitting (SPEC §3.6) and graft-stats (SPEC §3.7).

Offline only. Invoked by the consolidation pipeline, never ad hoc by an LLM.
Phase 0: public entry points are stubs that raise NotImplementedError.
"""

from graft_calibrate.calibrate import MIN_PAIRS, CalibrationCurve, fit
from graft_calibrate.stats import GateVerdict, run_gate

__all__ = ["MIN_PAIRS", "CalibrationCurve", "GateVerdict", "fit", "run_gate"]
__version__ = "0.0.0"
