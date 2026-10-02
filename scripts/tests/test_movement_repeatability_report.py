"""Measurement integrity contract, not gameplay/balance or real-clock acceptance.

Run: python -B -m unittest discover -s scripts/tests -p test_movement_repeatability_report.py
The checker is deliberately implemented separately from this test fixture.
"""

from __future__ import annotations

import copy
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest


ART_SCRIPTS = Path(__file__).resolve().parents[1] / "art"
sys.path.insert(0, str(ART_SCRIPTS))

from check_movement_repeatability_report import check_report  # noqa: E402


def make_report(count: int = 4, track: str = "D", mode: str = "walk") -> dict:
    """Synthetic observations with two real physics callbacks per render frame."""
    directions = ([1.0, 0.0], [0.0, 1.0], [-1.0, 0.0], [0.0, -1.0])
    samples = []
    simulated = 0.0
    for step in range(1, count + 1):
        direction = list(directions[((step - 1) // 75) % 4])
        dash = mode == "dash" and step in (180, 360, 540, 720, 900, 1080)
        delta = 1.0 / 60.0 if track == "D" or step % 2 else 0.2 / 60.0
        simulated += delta
        samples.append({
            "step": step, "physics_frame": 100 + step,
            "pre_physics_frame": 100 + step, "post_physics_frame": 100 + step,
            "process_frame": 10 + (step - 1) // 2,
            "physics_delta": delta, "pre_physics_delta": delta,
            "simulated_seconds": simulated, "wall_seconds": step / 60.0,
            "input_pre": direction.copy(), "input": direction.copy(),
            "fire_pressed_pre": True, "dash_pressed_pre": dash, "dash_requested": dash,
            "mouse_injected_physics_frame": 100 + step, "actual_aim": direction.copy(), "aim_validated": True,
            "scale_before_physics": delta * 60.0, "scale_after_physics": delta * 60.0,
            "position": [float(step), 0.0], "health": 100.0,
        })
    wall_seconds = count / 60.0
    return {
        "schema_version": 2, "sampling_method": "pre_post_physics_callbacks",
        "physics_hz": 60, "first_physics_frame": 100,
        "run": {"seed": 20260908, "track": track, "mode": mode,
                "run": "unit-synthetic", "steps": count, "clock": "unknown"},
        "sampling_valid": True, "acceptance": "measurement_only", "terminal": "step_budget", "terminal_phase": "after_callbacks",
        "formal_step_budget": count == 1200, "sample_steps": count, "physics_steps": count,
        "simulated_seconds": simulated, "wall_seconds": wall_seconds,
        "unscaled_step_seconds": count / 60.0, "samples": samples,
        "initial": {"player": {"position": [0.0, 0.0], "health": 100.0}},
        "final": {"position": [float(count), 0.0], "health": 100.0},
        "clock": {
            "clock_declaration": "unknown", "declaration_source": "user_argument_or_unknown_default",
            "observed_cmdline_args": [], "observed_args_complete": False,
            "automatic_clock_verification": "unavailable", "real_clock_pass": False,
            "wall_to_unscaled_step_ratio": 1.0 if count else None,
            "wall_to_simulated_ratio": wall_seconds / simulated if simulated else None,
            "fidelity": "not_applicable_D" if track == "D" else "sampling_smoke_clock_unknown",
        },
    }


class MovementRepeatabilityReportTests(unittest.TestCase):
    def assert_valid(self, report: dict) -> dict:
        untouched = copy.deepcopy(report)
        result = check_report(report)
        self.assertTrue(result["valid"], result["errors"])
        self.assertEqual(result["errors"], [])
        self.assertIs(result["clock_assessment"]["real_clock_verified"], False)
        self.assertEqual(report, untouched, "checker must not repair or mutate source evidence")
        return result

    def assert_invalid(self, report: dict) -> None:
        result = check_report(report)
        self.assertFalse(result["valid"], "invalid evidence was accepted")
        self.assertTrue(result["errors"], "rejection needs an actionable diagnostic")
        self.assertTrue(all(isinstance(error, str) and error for error in result["errors"]))

    def test_multiple_physics_steps_in_one_render_are_valid(self) -> None:
        report = make_report()
        self.assertEqual(report["samples"][0]["process_frame"], report["samples"][1]["process_frame"])
        self.assert_valid(report)

    def test_scaled_r_clock_is_measurement_only_even_with_complete_samples(self) -> None:
        self.assert_valid(make_report(track="R"))

    def test_dropped_middle_step_is_not_hidden_by_claimed_validity(self) -> None:
        report = make_report()
        report["samples"].pop(1)
        report["sample_steps"] -= 1
        self.assert_invalid(report)

    def test_frame_gap_with_consistent_array_length_is_invalid(self) -> None:
        report = make_report()
        for field in ("physics_frame", "pre_physics_frame", "post_physics_frame", "mouse_injected_physics_frame"):
            report["samples"][2][field] += 1
        self.assert_invalid(report)

    def test_duplicate_physics_step_cannot_count_as_a_new_sample(self) -> None:
        report = make_report()
        report["samples"][2] = copy.deepcopy(report["samples"][1])
        self.assert_invalid(report)

    def test_sample_index_and_frame_baseline_must_match(self) -> None:
        for key in ("step", "physics_frame"):
            with self.subTest(key=key):
                report = make_report()
                report["samples"][0][key] += 1
                self.assert_invalid(report)
        report = make_report()
        report["first_physics_frame"] -= 1
        self.assert_invalid(report)

    def test_pre_post_and_mouse_injection_belong_to_same_physics_step(self) -> None:
        for key in ("pre_physics_frame", "post_physics_frame", "mouse_injected_physics_frame"):
            with self.subTest(key=key):
                report = make_report()
                report["samples"][1][key] -= 1
                self.assert_invalid(report)

    def test_render_frame_must_not_go_backwards(self) -> None:
        report = make_report()
        report["samples"][2]["process_frame"] = 9
        self.assert_invalid(report)

    def test_observed_input_must_match_actual_scheduled_direction(self) -> None:
        for key in ("input_pre", "input"):
            with self.subTest(key=key):
                report = make_report(76)
                report["samples"][75][key] = [1.0, 0.0]  # Must turn down at step 76.
                self.assert_invalid(report)

    def test_actual_fire_and_dash_presses_are_not_inferred_from_requests(self) -> None:
        report = make_report(180, mode="dash")
        self.assert_valid(report)
        report["samples"][179]["dash_pressed_pre"] = False
        self.assert_invalid(report)
        report = make_report()
        report["samples"][1]["fire_pressed_pre"] = False
        self.assert_invalid(report)

    def test_walk_must_not_inject_unscheduled_dash(self) -> None:
        report = make_report()
        report["samples"][1]["dash_pressed_pre"] = True
        report["samples"][1]["dash_requested"] = True
        self.assert_invalid(report)

    def test_aim_observation_must_agree_with_the_injected_direction(self) -> None:
        report = make_report()
        report["samples"][0]["actual_aim"] = [0.0, 1.0]
        self.assert_invalid(report)

    def test_same_step_delta_is_observed_twice_and_must_agree(self) -> None:
        report = make_report(track="R")
        report["samples"][1]["pre_physics_delta"] *= 2
        self.assert_invalid(report)

    def test_nonpositive_or_nonfinite_deltas_are_invalid(self) -> None:
        for value in (0.0, -0.01, float("nan"), float("inf")):
            with self.subTest(value=value):
                report = make_report()
                report["samples"][0]["physics_delta"] = value
                report["samples"][0]["pre_physics_delta"] = value
                self.assert_invalid(report)

    def test_cumulative_simulation_time_and_summary_are_recomputed(self) -> None:
        report = make_report(track="R")
        report["samples"][2]["simulated_seconds"] += 0.1
        self.assert_invalid(report)
        report = make_report(track="R")
        report["simulated_seconds"] = report["unscaled_step_seconds"]
        self.assert_invalid(report)

    def test_summary_counts_and_unscaled_time_cannot_hide_lost_steps(self) -> None:
        for key in ("sample_steps", "physics_steps", "unscaled_step_seconds"):
            with self.subTest(key=key):
                report = make_report()
                report[key] += 1
                self.assert_invalid(report)

    def test_wall_clock_and_reported_ratios_are_evidence_not_assertions(self) -> None:
        report = make_report(track="R")
        report["samples"][2]["wall_seconds"] = 0.001
        self.assert_invalid(report)
        for key in ("wall_to_unscaled_step_ratio", "wall_to_simulated_ratio"):
            with self.subTest(key=key):
                report = make_report(track="R")
                report["clock"][key] += 0.5
                self.assert_invalid(report)

    def test_declared_realtime_ratio_one_and_missing_fixed_flag_do_not_prove_realtime(self) -> None:
        report = make_report(track="R")
        report["run"]["clock"] = "realtime"
        report["clock"]["clock_declaration"] = "realtime"
        report["clock"]["fidelity"] = "declared_realtime_unverified"
        self.assert_valid(report)
        report["clock"]["real_clock_pass"] = True
        self.assert_invalid(report)

    def test_fixed_r_run_is_valid_sampling_smoke_not_a_real_clock_failure(self) -> None:
        report = make_report(track="R")
        report["run"]["clock"] = "fixed"
        report["clock"]["clock_declaration"] = "fixed"
        report["clock"]["fidelity"] = "sampling_smoke_declared_fixed"
        report["clock"]["observed_cmdline_args"] = ["--fixed-fps", "60"]
        self.assert_valid(report)

    def test_d_track_must_not_hide_time_scale_changes(self) -> None:
        report = make_report()
        report["samples"][0]["scale_after_physics"] = 0.2
        self.assert_invalid(report)

    def test_real_death_can_end_before_requested_step_budget(self) -> None:
        report = make_report(2)
        report["run"]["steps"] = 1200
        report["formal_step_budget"] = True
        report["terminal"] = "death"
        report["samples"][-1]["health"] = report["final"]["health"] = 0.0
        self.assert_valid(report)
        report["terminal"] = "step_budget"
        self.assert_invalid(report)

    def test_death_before_first_pre_has_no_fabricated_measurement(self) -> None:
        report = make_report(0)
        report["run"]["steps"] = 1200
        report["formal_step_budget"] = True
        report["terminal"] = "death"
        report["terminal_phase"] = "before_input"
        report["final"]["health"] = 0.0
        report["wall_seconds"] = 0.002
        self.assert_valid(report)
        report["final"]["health"] = 100.0
        self.assert_invalid(report)

    def test_only_final_after_callback_death_may_leave_aim_unvalidated(self) -> None:
        report = make_report(track="R")
        report["run"]["steps"] = 1200
        report["terminal"] = "death"
        report["samples"][-1]["health"] = report["final"]["health"] = 0.0
        report["samples"][-1]["aim_validated"] = False
        report["samples"][-1]["actual_aim"] = [0.0, -1.0]
        self.assert_valid(report)
        report["samples"][0]["aim_validated"] = False
        self.assert_invalid(report)

    def test_death_before_input_cannot_excuse_previous_step_aim(self) -> None:
        report = make_report(track="R")
        report["run"]["steps"] = 1200
        report["terminal"] = "death"
        report["terminal_phase"] = "before_input"
        report["final"]["health"] = 0.0
        self.assert_valid(report)
        report["samples"][-1]["aim_validated"] = False
        self.assert_invalid(report)

    def test_final_after_callbacks_must_match_last_observation_before_cleanup(self) -> None:
        report = make_report(track="R")
        report["terminal"] = "death"
        report["final"]["health"] = 0.0
        self.assert_invalid(report)  # The last callback observed a live player.
        report = make_report()
        report["final"]["position"] = [1000.0, 0.0]
        self.assert_invalid(report)

    def test_legacy_or_self_rejected_report_cannot_be_upgraded_by_checker(self) -> None:
        report = make_report()
        del report["schema_version"]
        self.assert_invalid(report)
        report = make_report()
        report["sampling_valid"] = False
        self.assert_invalid(report)
        report = make_report()
        report["acceptance"] = "balance_pass"
        self.assert_invalid(report)

    def test_missing_required_step_evidence_is_rejected_without_exception(self) -> None:
        for key in ("input_pre", "pre_physics_frame", "pre_physics_delta", "process_frame", "dash_pressed_pre", "aim_validated"):
            with self.subTest(key=key):
                report = make_report()
                del report["samples"][0][key]
                self.assert_invalid(report)

    def test_cli_returns_machine_readable_measurement_result_and_nonzero_on_failure(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            path = Path(temporary) / "measurement.json"
            for invalid in (False, True):
                report = make_report()
                if invalid:
                    report["samples"][1]["pre_physics_frame"] -= 1
                path.write_text(json.dumps(report), encoding="utf-8")
                process = subprocess.run(
                    [sys.executable, "-B", str(ART_SCRIPTS / "check_movement_repeatability_report.py"), str(path)],
                    text=True, capture_output=True, timeout=10, check=False,
                )
                self.assertEqual(process.returncode, 2 if invalid else 0, process.stderr)
                result = json.loads(process.stdout)
                self.assertIs(result["valid"], not invalid)
                self.assertIs(result["clock_assessment"]["real_clock_verified"], False)


if __name__ == "__main__":
    unittest.main()
