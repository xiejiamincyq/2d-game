"""Validate recorded movement measurements; never certify balance or clock pacing."""

from __future__ import annotations

import argparse
import json
import math
from pathlib import Path
from typing import Any


EPS = 1e-5
DIRECTIONS = ((1.0, 0.0), (0.0, 1.0), (-1.0, 0.0), (0.0, -1.0))
DASH_STEPS = {180, 360, 540, 720, 900, 1080}


def _number(value: Any) -> bool:
    return isinstance(value, (int, float)) and not isinstance(value, bool) and math.isfinite(value)


def _integer(value: Any) -> bool:
    return isinstance(value, int) and not isinstance(value, bool)


def _close(left: Any, right: float) -> bool:
    return _number(left) and math.isclose(left, right, rel_tol=EPS, abs_tol=EPS)


def _vector(value: Any) -> bool:
    return isinstance(value, list) and len(value) == 2 and all(_number(part) for part in value)


def _result() -> dict:
    return {
        "valid": False, "errors": [],
        "clock_assessment": {
            "real_clock_verified": False, "clock_declaration": "unknown",
            "wall_to_unscaled_step_ratio": None, "wall_to_simulated_ratio": None,
            "interpretation": "Observed elapsed-time ratios are arithmetic evidence, not verification of real-time pacing or balance.",
        },
    }


def check_report(report: dict) -> dict:
    """Return diagnostics without repairing, mutating, or trusting claimed validity."""
    result = _result()
    errors = result["errors"]

    def require(condition: bool, message: str) -> None:
        if not condition:
            errors.append(message)

    if not isinstance(report, dict):
        errors.append("report must be a JSON object")
        return result
    require(report.get("schema_version") == 2, "schema_version must be 2")
    require(report.get("sampling_method") == "pre_post_physics_callbacks", "sampling_method must identify pre/post physics callbacks")
    require(report.get("sampling_valid") is True, "sampler did not declare valid evidence")
    require(report.get("acceptance") == "measurement_only", "acceptance must be measurement_only, never a balance pass")
    run, clock, samples, final = (report.get(key) for key in ("run", "clock", "samples", "final"))
    for key, value, expected in (("run", run, dict), ("clock", clock, dict), ("samples", samples, list), ("final", final, dict)):
        require(isinstance(value, expected), f"{key} has missing/invalid container type")
    hz, baseline = report.get("physics_hz"), report.get("first_physics_frame")
    require(_integer(hz) and hz > 0, "physics_hz must be a positive integer")
    require(_integer(baseline) and baseline >= 0, "first_physics_frame must be a nonnegative integer")
    if errors:
        return result
    requested = run.get("steps")
    require(_integer(requested) and 1 <= requested <= 1200, "run.steps must be an integer within 1..1200")
    require(run.get("track") in ("D", "R"), "run.track must be D or R")
    require(run.get("mode") in ("walk", "dash"), "run.mode must be walk or dash")
    require(run.get("clock") in ("unknown", "fixed", "realtime"), "run.clock has invalid declaration")
    if errors:
        return result
    count = len(samples)
    for key in ("sample_steps", "physics_steps"):
        require(_integer(report.get(key)) and report[key] == count, f"{key} does not match every recorded physics step")
    require(count <= requested, "recorded steps exceed the requested budget")
    terminal = report.get("terminal")
    terminal_phase = report.get("terminal_phase")
    require(terminal in ("step_budget", "death"), "terminal must be step_budget or a real death")
    require(terminal_phase in ("before_input", "after_callbacks"), "terminal_phase must identify the actual stopping boundary")
    if terminal == "step_budget":
        require(count == requested and count > 0, "step_budget termination requires all requested steps")
        require(terminal_phase == "after_callbacks", "step_budget must finish after the final callback sample")
    elif terminal == "death":
        require(_number(final.get("health")) and final["health"] <= 0, "death termination lacks a dead pre-cleanup final player")
        require(count > 0 or terminal_phase == "before_input", "zero-step death must occur before input, not fabricate a callback")
    if terminal_phase == "after_callbacks" and samples and isinstance(samples[-1], dict):
        for key in ("position", "velocity", "health", "shield", "dash_active", "dash_cooldown", "stealth_remaining", "layer", "mask", "shape_disabled"):
            if key in final and key in samples[-1]:
                observed, sealed = samples[-1][key], final[key]
                if _vector(observed) and _vector(sealed):
                    equal = all(_close(a, b) for a, b in zip(observed, sealed))
                elif _number(observed) and _number(sealed):
                    equal = _close(observed, sealed)
                else:
                    equal = type(observed) is type(sealed) and observed == sealed
                require(equal, f"final.{key} differs from the last after-callback observation")

    simulated = 0.0
    last_wall, last_render = 0.0, -1
    for index, sample in enumerate(samples, 1):
        label = f"sample[{index}]"
        if not isinstance(sample, dict):
            errors.append(f"{label} must be an object")
            continue
        expected_frame = baseline + index
        require(_integer(sample.get("step")) and sample["step"] == index, f"{label} step is missing, duplicated or out of sequence")
        for key in ("physics_frame", "pre_physics_frame", "post_physics_frame", "mouse_injected_physics_frame"):
            require(_integer(sample.get(key)) and sample[key] == expected_frame, f"{label}.{key} is not the same consecutive physics step")
        render = sample.get("process_frame")
        require(_integer(render) and render >= last_render, f"{label}.process_frame is missing or went backwards")
        if _integer(render):
            last_render = render  # Equality is legal: one render can contain many ticks.
        direction = DIRECTIONS[((index - 1) // 75) % len(DIRECTIONS)]
        for key in ("input_pre", "input"):
            observed = sample.get(key)
            require(_vector(observed) and all(_close(a, b) for a, b in zip(observed, direction)), f"{label}.{key} differs from the scheduled actual input")
        require(sample.get("fire_pressed_pre") is True, f"{label} actual fire press is absent")
        dash = run["mode"] == "dash" and index in DASH_STEPS
        for key in ("dash_requested", "dash_pressed_pre"):
            require(sample.get(key) is dash, f"{label}.{key} differs from the registered dash event")
        aim = sample.get("actual_aim")
        unvalidated_death = terminal == "death" and terminal_phase == "after_callbacks" and index == count and sample.get("aim_validated") is False
        require(sample.get("aim_validated") is True or unvalidated_death, f"{label}.aim_validated may be false only for the final after-callback death")
        require(_vector(aim), f"{label}.actual_aim must remain a finite vector observation")
        if not unvalidated_death:
            require(_vector(aim) and _close(math.hypot(*aim), 1.0) and sum(a * b for a, b in zip(aim, direction)) >= 0.9999,
                    f"{label}.actual_aim does not match the injected direction")
        delta, pre_delta = sample.get("physics_delta"), sample.get("pre_physics_delta")
        delta_valid = _number(delta) and 0 < delta <= 1.0 / hz + EPS
        require(delta_valid, f"{label}.physics_delta must be finite, positive and within one unscaled tick")
        require(delta_valid and _close(pre_delta, delta), f"{label} pre/post physics deltas disagree")
        if delta_valid:
            simulated += delta
        require(_close(sample.get("simulated_seconds"), simulated), f"{label}.simulated_seconds is not the cumulative callback delta")
        wall = sample.get("wall_seconds")
        require(_number(wall) and wall >= last_wall, f"{label}.wall_seconds is missing, nonfinite or went backwards")
        if _number(wall):
            last_wall = wall
        for key in ("scale_before_physics", "scale_after_physics"):
            scale = sample.get(key)
            require(_number(scale) and 0 < scale <= 1.0 + EPS, f"{label}.{key} must be finite within (0, 1]")
            if run["track"] == "D":
                require(_close(scale, 1.0), f"D track {label}.{key} changed time scale")

    unscaled = count / hz
    require(_close(report.get("simulated_seconds"), simulated), "simulated_seconds summary does not equal actual sampled deltas")
    require(_close(report.get("unscaled_step_seconds"), unscaled), "unscaled_step_seconds summary does not equal counted ticks / physics_hz")
    wall = report.get("wall_seconds")
    require(_number(wall) and wall >= last_wall and wall >= 0, "wall_seconds summary must be finite and include the last sample")
    declaration = clock.get("clock_declaration")
    result["clock_assessment"]["clock_declaration"] = declaration
    require(declaration == run["clock"], "clock declaration disagrees with the run arguments")
    require(clock.get("real_clock_pass") is False, "recorded ratios/arguments cannot establish real_clock_pass")
    require(clock.get("automatic_clock_verification") == "unavailable", "automatic real-clock verification is not established by this report")
    expected_fidelity = "not_applicable_D" if run["track"] == "D" else {
        "unknown": "sampling_smoke_clock_unknown", "fixed": "sampling_smoke_declared_fixed",
        "realtime": "declared_realtime_unverified",
    }[run["clock"]]
    require(clock.get("fidelity") == expected_fidelity, "clock fidelity overstates or contradicts the declared measurement")
    for key, denominator in (("wall_to_unscaled_step_ratio", unscaled), ("wall_to_simulated_ratio", simulated)):
        ratio = wall / denominator if _number(wall) and denominator > 0 else None
        if ratio is not None and not math.isfinite(ratio):
            errors.append(f"clock.{key} overflows a finite observed ratio")
            ratio = None
        result["clock_assessment"][key] = ratio
        require((clock.get(key) is None) if ratio is None else _close(clock.get(key), ratio), f"clock.{key} does not match the observed time arithmetic")
    result["valid"] = not errors
    return result


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("report", type=Path)
    arguments = parser.parse_args()
    try:
        report = json.loads(arguments.report.read_text(encoding="utf-8-sig"))
        result = check_report(report)
    except (OSError, UnicodeError, json.JSONDecodeError) as error:
        result = _result()
        result["errors"].append(f"could not read report: {error}")
    print(json.dumps(result, ensure_ascii=False, allow_nan=False))
    return 0 if result["valid"] else 2


if __name__ == "__main__":
    raise SystemExit(main())
