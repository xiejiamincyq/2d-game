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


def make_natural_report(count: int = 4, mode: str = "walk", terminal: str = "step_budget",
                        phase: str = "after_callbacks") -> dict:
    report = make_report(count, track="R", mode=mode)
    report["run"]["scenario"] = "natural_wave1"
    report["terminal"], report["terminal_phase"] = terminal, phase
    if terminal != "step_budget":
        report["run"]["steps"] = max(count, 10800)
    state = {"run_state": "PLAYING", "wave_index": 0, "live_enemies": 2, "kills": 0,
             "enemy_kinds": {"scrapper": 1, "dasher": 1}, "spawn_pending": 39,
             "portal_count": 3, "landing_fill_total": 0, "landing_fill_view_intersections": 0,
             "director_collection": False}
    report["initial"].update({"map_seed": 712, "layout_seed": 712, "enemies": 0, "portals": 3, "kills": 0,
                              "spawn_guard_active": False, "director_active": True,
                              "director_running": True, "start_input": "enter"})
    report["initial"]["player"].update(copy.deepcopy(state))
    report["initial"]["player"].update({"live_enemies": 0, "enemy_kinds": {}, "spawn_pending": 41, "shield": 0.0})
    for sample in report["samples"]:
        sample.update(copy.deepcopy(state))
        dash = mode == "dash" and sample["step"] % 180 == 0
        sample["dash_requested"] = sample["dash_pressed_pre"] = dash
    report["final"].update(copy.deepcopy(state))
    if terminal == "death":
        report["final"].update({"health": 0.0, "run_state": "RESULT"})
    elif terminal == "wave_clear":
        report["final"].update({"run_state": "WAVE_CLEAR", "live_enemies": 0,
                                "enemy_kinds": {}, "spawn_pending": 0, "portal_count": 0, "kills": 41})
    if terminal != "step_budget" and phase == "after_callbacks" and count:
        report["samples"][-1].update(copy.deepcopy(report["final"]))
        report["samples"][-1]["aim_validated"] = False
        report["samples"][-1]["actual_aim"] = [0.0, -1.0]
    return report


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

    def test_natural_long_dash_budget_remains_measurement_not_wave_completion(self) -> None:
        report = make_natural_report(1260, mode="dash")
        result = self.assert_valid(report)
        assessment = result["observation_assessment"]
        self.assertEqual(assessment["outcome"], "budget_exhausted")
        self.assertIs(assessment["wave_clear_observed"], False)
        report["samples"][-1]["dash_pressed_pre"] = False
        self.assert_invalid(report)  # Natural dash requests continue after the old 1080 slot.

    def test_natural_wave_clear_and_death_allow_both_real_terminal_boundaries(self) -> None:
        for terminal in ("wave_clear", "death"):
            for phase in ("before_input", "after_callbacks"):
                with self.subTest(terminal=terminal, phase=phase):
                    result = self.assert_valid(make_natural_report(terminal=terminal, phase=phase))
                    self.assertEqual(result["observation_assessment"]["outcome"], terminal)
                    self.assertIs(result["observation_assessment"]["wave_clear_observed"], terminal == "wave_clear")

    def test_natural_zero_step_death_does_not_fabricate_a_physics_step(self) -> None:
        report = make_natural_report(0, terminal="death", phase="before_input")
        self.assert_valid(report)

    def test_natural_requires_r_and_registered_scenario_and_budget(self) -> None:
        for scenario, track, steps in (("natural_wave1", "D", 4), ("typo", "R", 4),
                                       ("natural_wave1", "R", 10801), ("stress60", "R", 1201)):
            with self.subTest(scenario=scenario, track=track, steps=steps):
                report = make_natural_report()
                report["run"].update({"scenario": scenario, "track": track, "steps": steps})
                self.assert_invalid(report)
        report = make_report()
        report["run"]["scenario"] = "stress60"
        self.assert_valid(report)

    def test_natural_initial_observations_must_agree_not_just_claim_natural(self) -> None:
        changes = {"layout_seed": 713, "enemies": 1, "portals": 0,
                   "spawn_guard_active": True, "director_active": False,
                   "director_running": False, "start_input": "direct_callback"}
        for key, value in changes.items():
            with self.subTest(key=key):
                report = make_natural_report()
                report["initial"][key] = value
                self.assert_invalid(report)
        report = make_natural_report()
        del report["initial"]["director_running"]
        self.assert_invalid(report)

    def test_natural_counter_fields_require_nonnegative_integers_and_kind_sum(self) -> None:
        fields = ("live_enemies", "spawn_pending", "portal_count", "landing_fill_total", "landing_fill_view_intersections")
        for key in fields:
            for value in (-1, 0.5, True):
                with self.subTest(key=key, value=value):
                    report = make_natural_report()
                    report["samples"][0][key] = value
                    self.assert_invalid(report)
        for kinds in ({"scrapper": 3}, {"scrapper": -1, "dasher": 3}, {"scrapper": 1.5, "dasher": 0.5},
                      {"scrapper": True, "dasher": 1}, {"unknown": 2}, [], None):
            with self.subTest(kinds=kinds):
                report = make_natural_report()
                report["samples"][0]["enemy_kinds"] = kinds
                self.assert_invalid(report)
        report = make_natural_report()
        report["samples"][0]["landing_fill_view_intersections"] = 1
        self.assert_invalid(report)

    def test_natural_required_observations_and_sampling_phase_cannot_be_omitted(self) -> None:
        fields = ("run_state", "wave_index", "live_enemies", "enemy_kinds", "spawn_pending", "portal_count",
                  "landing_fill_total", "landing_fill_view_intersections", "director_collection")
        for location in ("sample", "final"):
            for key in fields:
                with self.subTest(location=location, key=key):
                    report = make_natural_report()
                    del (report["samples"][0] if location == "sample" else report["final"])[key]
                    self.assert_invalid(report)
        for state in ("START", "WAVE_INTRO", "WAVE_CLEAR", "SETTLEMENT", "PAUSED", "RESULT"):
            with self.subTest(state=state):
                report = make_natural_report()
                report["samples"][0]["run_state"] = state
                self.assert_invalid(report)
        report = make_natural_report()
        report["samples"][0]["wave_index"] = 1
        self.assert_invalid(report)

    def test_natural_clear_requires_empty_completed_first_wave_not_a_label(self) -> None:
        for key, value in (("live_enemies", 1), ("spawn_pending", 1), ("wave_index", 1),
                           ("director_collection", True), ("run_state", "SETTLEMENT"), ("portal_count", 1)):
            with self.subTest(key=key):
                report = make_natural_report(terminal="wave_clear", phase="before_input")
                report["final"][key] = value
                self.assert_invalid(report)
        report = make_natural_report(terminal="wave_clear")
        report["run"]["scenario"] = "stress60"
        report["run"]["steps"] = 1200
        self.assert_invalid(report)

    def test_natural_final_counters_match_after_callbacks_not_pre_cleanup_guesses(self) -> None:
        report = make_natural_report()
        report["final"]["live_enemies"] = 1
        report["final"]["enemy_kinds"] = {"scrapper": 1}
        self.assert_invalid(report)
        report = make_natural_report(terminal="wave_clear")
        report["samples"][-1]["run_state"] = "PLAYING"
        self.assert_invalid(report)
        report = make_natural_report()
        report["samples"][-1]["landing_fill_total"] = 1000000
        report["final"]["landing_fill_total"] = 1000001
        self.assert_invalid(report)  # Integer count identity never uses floating-point tolerance.

    def test_natural_malformed_terminal_is_rejected_without_an_exception(self) -> None:
        for terminal in ([], {}, None, True):
            with self.subTest(terminal=terminal):
                report = make_natural_report()
                report["terminal"] = terminal
                self.assert_invalid(report)

    def test_natural_initial_player_counters_cannot_hide_an_already_started_wave(self) -> None:
        for key, value in (("spawn_pending", 40), ("live_enemies", 1), ("portal_count", 2),
                           ("run_state", "WAVE_INTRO"), ("director_collection", True)):
            with self.subTest(key=key):
                report = make_natural_report()
                report["initial"]["player"][key] = value
                self.assert_invalid(report)
        for value in (None, [], {}):
            with self.subTest(initial=value):
                report = make_natural_report()
                report["initial"] = value
                self.assert_invalid(report)

    def test_natural_collection_is_a_valid_playing_observation_only_when_combat_is_empty(self) -> None:
        report = make_natural_report()
        for state in [*report["samples"], report["final"]]:
            state.update({"director_collection": True, "live_enemies": 0,
                          "enemy_kinds": {}, "spawn_pending": 0, "portal_count": 0, "kills": 41})
        self.assert_valid(report)
        report["samples"][0]["spawn_pending"] = 1
        self.assert_invalid(report)

    def test_natural_kills_are_required_nonnegative_integers_at_every_observation(self) -> None:
        for location in ("initial", "initial.player", "sample", "final"):
            for value in (None, -1, 0.5, True):
                with self.subTest(location=location, value=value):
                    report = make_natural_report()
                    state = {"initial": report["initial"], "initial.player": report["initial"]["player"],
                             "sample": report["samples"][0], "final": report["final"]}[location]
                    if value is None:
                        del state["kills"]
                    else:
                        state["kills"] = value
                    self.assert_invalid(report)

    def test_natural_closed_portal_cannot_discard_twenty_pending_enemies(self) -> None:
        report = make_natural_report()
        # This models the observed lost queue while preserving every sampling/aim field.
        report["samples"][1]["spawn_pending"] -= 20
        self.assert_invalid(report)
        report = make_natural_report(terminal="death", phase="before_input")
        report["final"]["spawn_pending"] -= 20
        self.assert_invalid(report)

    def test_natural_forged_41_kills_cannot_replace_live_or_missing_enemy_evidence(self) -> None:
        report = make_natural_report()
        report["samples"][1]["kills"] = 41  # Still has two live and 39 pending.
        self.assert_invalid(report)
        report = make_natural_report(terminal="wave_clear", phase="before_input")
        report["final"]["kills"] = 21  # Empty scene alone is not proof of 41 kills.
        self.assert_invalid(report)
        report = make_natural_report()
        report["initial"]["kills"] = 41
        self.assert_invalid(report)

    def test_natural_cannot_reset_kills_even_when_each_frame_balances_to_41(self) -> None:
        report = make_natural_report()
        report["samples"][0].update({"kills": 41, "live_enemies": 0,
                                       "enemy_kinds": {}, "spawn_pending": 0})
        self.assert_invalid(report)  # Later rows would resurrect the killed first wave.

    def test_natural_initial_player_is_unmodified_not_a_prepared_build(self) -> None:
        for key, value in (("health", 999.0), ("shield", 100.0), ("shield", False),
                           ("position", [1.0, 0.0]), ("kills", 1)):
            with self.subTest(key=key, value=value):
                report = make_natural_report()
                report["initial"]["player"][key] = value
                self.assert_invalid(report)
        for key in ("health", "shield", "position"):
            with self.subTest(missing=key):
                report = make_natural_report()
                del report["initial"]["player"][key]
                self.assert_invalid(report)

    def test_natural_death_keeps_conservation_and_clear_requires_all_41_killed(self) -> None:
        for terminal in ("death", "wave_clear"):
            for phase in ("before_input", "after_callbacks"):
                with self.subTest(terminal=terminal, phase=phase):
                    report = make_natural_report(terminal=terminal, phase=phase)
                    self.assert_valid(report)
                    self.assertEqual(sum(report["final"][key] for key in ("live_enemies", "spawn_pending", "kills")), 41)
                    if terminal == "wave_clear":
                        self.assertEqual(report["final"]["kills"], 41)

    def test_natural_first_wave_does_not_gain_other_enemy_species(self) -> None:
        report = make_natural_report()
        report["samples"][0]["enemy_kinds"] = {"lobber": 2}
        self.assert_invalid(report)

    def test_natural_terminal_aim_exception_is_only_the_final_after_callback(self) -> None:
        report = make_natural_report(terminal="wave_clear")
        report["samples"][0]["aim_validated"] = False
        self.assert_invalid(report)
        report = make_natural_report(terminal="wave_clear", phase="before_input")
        report["samples"][-1]["aim_validated"] = False
        self.assert_invalid(report)
        report = make_natural_report(terminal="wave_clear")
        report["samples"][-1]["aim_validated"] = True  # Wrong aim is still checked if validation is claimed.
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
