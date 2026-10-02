"""Pure runner contracts. These tests never launch Godot or run the matrix."""

from __future__ import annotations

import copy
from pathlib import Path
import sys
import unittest


ART_SCRIPTS = Path(__file__).resolve().parents[1] / "art"
sys.path.insert(0, str(ART_SCRIPTS))

from run_movement_repeatability_matrix import first_divergence, make_slots, self_test, summarize  # noqa: E402
import run_movement_repeatability_matrix as matrix  # noqa: E402


def measurement(movements: list[tuple[list[float], list[float]]], deltas: list[float] | None = None) -> dict:
    deltas = deltas or [0.01] * len(movements)
    return {
        "initial": {"player": {"position": [0.0, 0.0], "dash_active": False}},
        "final": {"position": movements[-1][1] if movements else [0.0, 0.0]},
        "terminal": "step_budget", "sample_steps": len(movements), "physics_steps": len(movements),
        "simulated_seconds": sum(deltas), "wall_seconds": 10.0,
        "unscaled_step_seconds": len(movements) / 60.0,
        "health_loss": 18.0, "shield_loss": 4.0,
        "samples": [{
            "step": index, "position_before": before, "position": after,
            "input": [1.0, 0.0], "physics_delta": delta, "requested_motion_pixels": 10.0,
            "dash_requested": False, "dash_active": False,
        } for index, ((before, after), delta) in enumerate(zip(movements, deltas), 1)],
    }


class MovementRepeatabilityMatrixTests(unittest.TestCase):
    def save_report(self) -> dict:
        hashes = {base + suffix: "absent" for base in (
            "user://five_minute_overdrive_run_v1.json", "user://five_minute_overdrive_run_test_v1.json"
        ) for suffix in ("", ".tmp", ".bak")}
        hashes["user://five_minute_overdrive_run_v1.json"] = "ab" * 32
        return {"initial": {"save_path_isolated": True}, "real_save_hashes_before": hashes,
                "real_save_hashes_after": hashes.copy()}

    def save_errors(self, report: dict) -> list[str]:
        validate = getattr(matrix, "validate_save_evidence", None)
        self.assertTrue(callable(validate), "runner must expose the pure validate_save_evidence gate")
        errors = validate(report)
        self.assertIsInstance(errors, list)
        self.assertTrue(all(isinstance(error, str) and error for error in errors))
        return errors

    def test_save_evidence_accepts_complete_unchanged_hash_and_absent_observations(self) -> None:
        report = self.save_report()
        untouched = copy.deepcopy(report)
        self.assertEqual(self.save_errors(report), [])
        self.assertEqual(report, untouched)

    def test_equal_empty_or_partial_save_maps_are_not_safety_evidence(self) -> None:
        report = self.save_report()
        report["real_save_hashes_before"] = report["real_save_hashes_after"] = {}
        self.assertTrue(self.save_errors(report))
        for field in ("real_save_hashes_before", "real_save_hashes_after"):
            with self.subTest(field=field):
                report = self.save_report()
                del report[field]["user://five_minute_overdrive_run_test_v1.json.bak"]
                self.assertTrue(self.save_errors(report))

    def test_save_hash_values_must_be_sha256_or_explicit_absence(self) -> None:
        for value in (None, "", "missing", "a" * 63, "z" * 64, True):
            with self.subTest(value=value):
                report = self.save_report()
                for field in ("real_save_hashes_before", "real_save_hashes_after"):
                    report[field]["user://five_minute_overdrive_run_v1.json"] = value
                self.assertTrue(self.save_errors(report))

    def test_changed_saves_or_missing_isolation_are_rejected(self) -> None:
        report = self.save_report()
        report["real_save_hashes_after"]["user://five_minute_overdrive_run_v1.json"] = "cd" * 32
        self.assertTrue(self.save_errors(report))
        for flag in (False, None, "true", 1):
            with self.subTest(flag=flag):
                report = self.save_report()
                report["initial"]["save_path_isolated"] = flag
                self.assertTrue(self.save_errors(report))
        self.assertTrue(self.save_errors({}))

    def test_builtin_pure_self_test_is_in_normal_discovery(self) -> None:
        self_test()

    def test_36_unique_slots_cover_every_track_seed_mode_repeat_and_d_first(self) -> None:
        slots = make_slots("unit")
        expected = {(track, seed, mode, repeat) for track in ("D", "R")
                    for seed in (20260908, 20260909, 20260910)
                    for mode in ("walk", "dash") for repeat in (1, 2, 3)}
        self.assertEqual(len(slots), 36)
        self.assertEqual(len({slot["run"] for slot in slots}), 36)
        self.assertEqual({(slot["track"], slot["seed"], slot["mode"], slot["repeat"]) for slot in slots}, expected)
        self.assertTrue(all(slot["track"] == "D" for slot in slots[:18]))
        self.assertTrue(all(slot["track"] == "R" for slot in slots[18:]))

    def test_smoke_is_one_explicit_case_not_a_selected_formal_repeat(self) -> None:
        self.assertEqual(make_slots("unit", True, "R", 20260910, "dash"), [
            {"run": "unit-R-20260910-dash-1", "track": "R", "seed": 20260910, "mode": "dash", "repeat": 1}
        ])

    def test_callback_stops_use_simulation_deltas_not_wall_duration(self) -> None:
        report = measurement([([0, 0], [0, 0]), ([0, 0], [0, 0])], [0.002, 0.016])
        result = summarize(report)
        self.assertAlmostEqual(result["longest_low_progress_sim_seconds"], 0.018)
        self.assertEqual((result["low_progress_start_step"], result["low_progress_end_step"]), (1, 2))

    def test_sideways_distance_is_not_forward_progress(self) -> None:
        result = summarize(measurement([([0, 0], [0, 100])]))
        self.assertEqual(result["path_pixels"], 100)
        self.assertAlmostEqual(result["longest_low_progress_sim_seconds"], 0.01)

    def test_ten_percent_boundary_and_zero_budget_reset_low_progress_streak(self) -> None:
        report = measurement([([0, 0], [0, 0]), ([0, 0], [1, 0]), ([1, 0], [1, 0]), ([1, 0], [1, 0])], [0.01, 0.01, 0.02, 0.1])
        report["samples"][3]["requested_motion_pixels"] = 0.0
        result = summarize(report)
        self.assertAlmostEqual(result["longest_low_progress_sim_seconds"], 0.02)
        self.assertEqual((result["low_progress_start_step"], result["low_progress_end_step"]), (3, 3))

    def test_dash_request_is_not_an_observed_dash_start(self) -> None:
        report = measurement([([0, 0], [0, 0])] * 5)
        for sample, requested, active in zip(report["samples"], [True, False, True, False, True], [False, True, True, False, True]):
            sample["dash_requested"], sample["dash_active"] = requested, active
        result = summarize(report)
        self.assertEqual(result["dash_requested_count"], 3)
        self.assertEqual(result["actual_dash_started_count"], 2)
        self.assertEqual(result["motion_budget_basis"], "walk_speed_even_during_dash")

    def test_damage_is_cumulative_observed_loss_not_initial_minus_final(self) -> None:
        report = measurement([([0, 0], [0, 0])])
        report["initial"]["player"]["health"] = report["final"]["health"] = 100.0  # Healing hides the net change.
        result = summarize(report)
        self.assertEqual(result["health_loss"], 18.0)
        self.assertEqual(result["shield_loss"], 4.0)

    def test_path_includes_observed_position_changes_between_callbacks(self) -> None:
        report = measurement([([0, 0], [1, 0]), ([10, 0], [11, 0])])
        report["travelled_pixels"] = 11.0
        result = summarize(report)
        self.assertEqual(result["net_pixels"], 11.0)
        self.assertEqual(result["path_pixels"], 11.0, "a callback-only distance must not be named whole-run path")

    def test_curved_path_and_net_displacement_are_distinct(self) -> None:
        result = summarize(measurement([([0, 0], [3, 0]), ([3, 0], [3, 4]), ([3, 4], [0, 0])]))
        self.assertEqual(result["path_pixels"], 12.0)
        self.assertEqual(result["net_pixels"], 0.0)

    def test_empty_real_death_remains_a_zero_sample_death(self) -> None:
        report = measurement([])
        report["terminal"] = "death"
        result = summarize(report)
        self.assertEqual(result["terminal"], "death")
        self.assertEqual(result["path_pixels"], 0.0)
        self.assertEqual(result["longest_low_progress_sim_seconds"], 0.0)
        self.assertIsNone(result["low_progress_start_step"])

    def test_repeat_comparison_excludes_absolute_clocks_but_reports_first_behavior_divergence(self) -> None:
        baseline = measurement([([0, 0], [1, 0]), ([1, 0], [2, 0])])
        repeat = copy.deepcopy(baseline)
        repeat["samples"][0].update(physics_frame=500, process_frame=700, wall_seconds=0.3)
        self.assertIsNone(first_divergence(baseline, repeat))
        repeat["samples"][1]["position"] = [2.5, 0]
        result = first_divergence(baseline, repeat)
        self.assertEqual((result["step"], result["field"]), (2, "position"))

    def test_repeat_tolerance_is_absolute_not_looser_at_large_coordinates(self) -> None:
        baseline = measurement([([0, 0], [1000, 0])])
        repeat = copy.deepcopy(baseline)
        repeat["samples"][0]["position"][0] += 0.0000005
        self.assertIsNone(first_divergence(baseline, repeat))
        repeat["samples"][0]["position"][0] += 0.00001
        self.assertEqual(first_divergence(baseline, repeat)["field"], "position")

    def test_early_death_is_divergence_not_a_discarded_repeat(self) -> None:
        baseline = measurement([([0, 0], [1, 0]), ([1, 0], [2, 0])])
        repeat = copy.deepcopy(baseline)
        repeat["samples"] = repeat["samples"][:1]
        repeat["terminal"] = "death"
        divergence = first_divergence(baseline, repeat)
        self.assertEqual((divergence["step"], divergence["field"]), (2, "terminal_or_length"))


if __name__ == "__main__":
    unittest.main()
