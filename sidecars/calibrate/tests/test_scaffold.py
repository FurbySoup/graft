"""Phase 0 scaffold tests: imports, constants, verdict shape, stubs raise."""

import dataclasses
import unittest

import graft_calibrate
from graft_calibrate import calibrate, stats

SPEC_VERDICT_KEYS = {"edit_id", "test", "p", "effect_size", "median_delta", "pass", "config_sha"}


class TestScaffold(unittest.TestCase):
    def test_package_imports(self) -> None:
        self.assertEqual(graft_calibrate.__version__, "0.0.0")
        self.assertIs(graft_calibrate.fit, calibrate.fit)
        self.assertIs(graft_calibrate.run_gate, stats.run_gate)

    def test_min_pairs_is_100(self) -> None:
        self.assertEqual(calibrate.MIN_PAIRS, 100)

    def test_gate_verdict_has_exactly_spec_fields(self) -> None:
        names = {f.name for f in dataclasses.fields(stats.GateVerdict)}
        self.assertEqual({"pass" if n == "pass_" else n for n in names}, SPEC_VERDICT_KEYS)
        v = stats.GateVerdict("e1", "exact_permutation", 0.01, 0.8, 20.0, True, "abc")
        self.assertEqual(set(v.to_dict()), SPEC_VERDICT_KEYS)
        self.assertIs(v.to_dict()["pass"], True)

    def test_gate_verdict_is_frozen(self) -> None:
        v = stats.GateVerdict("e1", "exact_permutation", 0.01, 0.8, 20.0, True, "abc")
        with self.assertRaises(dataclasses.FrozenInstanceError):
            v.p = 0.5  # type: ignore[misc]

    def test_fit_stub_raises(self) -> None:
        with self.assertRaises(NotImplementedError):
            calibrate.fit([(0.9, True)] * calibrate.MIN_PAIRS, "judge")

    def test_run_gate_stub_raises(self) -> None:
        with self.assertRaises(NotImplementedError):
            stats.run_gate([], "ops/stats.yaml")


if __name__ == "__main__":
    unittest.main()
