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
ENEMY_KINDS = {"scrapper", "dasher", "spitter", "bruiser", "marksman", "lobber", "overseer"}
FIRST_WAVE_KINDS = {"scrapper", "dasher", "spitter"}
FIRST_WAVE_TOTAL = 41
NATURAL_COUNTS = ("live_enemies", "spawn_pending", "kills", "portal_count", "landing_fill_total", "landing_fill_view_intersections")
NATURAL_FIELDS = ("run_state", "wave_index", "enemy_kinds", "director_collection") + NATURAL_COUNTS


def _number(value: Any) -> bool:
    return isinstance(value, (int, float)) and not isinstance(value, bool) and math.isfinite(value)


def _integer(value: Any) -> bool:
    return isinstance(value, int) and not isinstance(value, bool)


def _close(left: Any, right: float) -> bool:
    return _number(left) and math.isclose(left, right, rel_tol=EPS, abs_tol=EPS)


def _vector(value: Any) -> bool:
    return isinstance(value, list) and len(value) == 2 and all(_number(part) for part in value)


def _natural_state_errors(state: Any, label: str, expected_state: str) -> list[str]:
    """Check recorded first-wave counts and phase; this cannot inspect live nodes."""
    if not isinstance(state, dict):
        return [f"{label} must contain natural first-wave observations"]
    errors = []
    if state.get("run_state") != expected_state:
        errors.append(f"{label}.run_state must be {expected_state}")
    if not _integer(state.get("wave_index")) or state["wave_index"] != 0:
        errors.append(f"{label}.wave_index must remain the first wave (0)")
    for key in NATURAL_COUNTS:
        if not _integer(state.get(key)) or state[key] < 0:
            errors.append(f"{label}.{key} must be a nonnegative integer")
    population = [state.get(key) for key in ("live_enemies", "spawn_pending", "kills")]
    if all(_integer(value) for value in population) and sum(population) != FIRST_WAVE_TOTAL:
        errors.append(f"{label} first-wave conservation failed: live_enemies + spawn_pending + kills must equal {FIRST_WAVE_TOTAL}")
    kinds = state.get("enemy_kinds")
    valid_kinds = isinstance(kinds, dict) and all(
        key in ENEMY_KINDS and _integer(value) and value >= 0 for key, value in kinds.items())
    if not valid_kinds:
        errors.append(f"{label}.enemy_kinds must map registered names to nonnegative integer counts")
    elif sum(kinds.values()) != state.get("live_enemies"):
        errors.append(f"{label}.enemy_kinds sum differs from live_enemies")
    if valid_kinds and any(value > 0 and key not in FIRST_WAVE_KINDS for key, value in kinds.items()):
        errors.append(f"{label}.enemy_kinds contains a species absent from the natural first wave")
    total, visible = state.get("landing_fill_total"), state.get("landing_fill_view_intersections")
    if _integer(total) and _integer(visible) and visible > total:
        errors.append(f"{label}.landing_fill_view_intersections exceeds landing_fill_total")
    collection = state.get("director_collection")
    if not isinstance(collection, bool):
        errors.append(f"{label}.director_collection must be a recorded boolean")
    if expected_state == "WAVE_CLEAR" or collection is True:
        for key in ("live_enemies", "spawn_pending", "portal_count"):
            if state.get(key) != 0:
                errors.append(f"{label}.{key} must be zero after combat clears")
    if expected_state == "WAVE_CLEAR" and collection is not False:
        errors.append(f"{label}.director_collection must finish before WAVE_CLEAR")
    health = state.get("health")
    if not _number(health) or (health <= 0 if expected_state != "RESULT" else health > 0):
        errors.append(f"{label}.health contradicts the recorded {expected_state} phase")
    return errors


def _natural_initial_errors(initial: Any) -> list[str]:
    if not isinstance(initial, dict):
        return ["initial must contain natural first-wave startup observations"]
    errors = _natural_state_errors(initial.get("player"), "initial.player", "PLAYING")
    if not _integer(initial.get("map_seed")) or not _integer(initial.get("layout_seed")) or initial["map_seed"] != initial["layout_seed"]:
        errors.append("initial actual map_seed and layout_seed must be matching integers")
    expected = {"enemies": 0, "portals": 3, "kills": 0, "spawn_guard_active": False,
                "director_active": True, "director_running": True, "start_input": "enter"}
    for key, value in expected.items():
        if type(initial.get(key)) is not type(value) or initial[key] != value:
            errors.append(f"initial.{key} must be {value!r} for natural startup")
    player = initial.get("player", {})
    if isinstance(player, dict):
        for key, value in {"live_enemies": 0, "spawn_pending": FIRST_WAVE_TOTAL, "kills": 0, "portal_count": 3, "director_collection": False}.items():
            if type(player.get(key)) is not type(value) or player[key] != value:
                errors.append(f"initial.player.{key} must be {value!r} before natural spawns")
        for key, value in {"health": 100.0, "shield": 0.0}.items():
            if not _number(player.get(key)) or player[key] != value:
                errors.append(f"initial.player.{key} must be the unmodified starting value {value}")
        if not _vector(player.get("position")) or any(value != 0.0 for value in player["position"]):
            errors.append("initial.player.position must be the unmodified starting origin")
    return errors


def _result() -> dict:
    return {
        "valid": False, "errors": [],
        "observation_assessment": {
            "outcome": "unvalidated", "wave_clear_observed": False,
            "interpretation": "Measurement integrity only; a step budget is not first-wave completion, settlement, full-run or balance acceptance.",
        },
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
    scenario = run.get("scenario", "stress60")  # Preserve already-recorded schema-2 reports.
    natural = scenario == "natural_wave1"
    require(scenario in ("stress60", "natural_wave1"), "run.scenario must be stress60 or natural_wave1")
    requested, maximum = run.get("steps"), 10800 if natural else 1200
    require(_integer(requested) and 1 <= requested <= maximum, f"run.steps must be an integer within 1..{maximum}")
    require(run.get("track") in ("D", "R"), "run.track must be D or R")
    require(not natural or run.get("track") == "R", "natural_wave1 requires production-feedback R track")
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
    require(terminal in (("step_budget", "death", "wave_clear") if natural else ("step_budget", "death")),
            "terminal must be step_budget, real death, or natural first-wave wave_clear")
    require(terminal_phase in ("before_input", "after_callbacks"), "terminal_phase must identify the actual stopping boundary")
    if errors:
        return result
    if terminal == "step_budget":
        require(count == requested and count > 0, "step_budget termination requires all requested steps")
        require(terminal_phase == "after_callbacks", "step_budget must finish after the final callback sample")
    elif terminal == "death":
        require(_number(final.get("health")) and final["health"] <= 0, "death termination lacks a dead pre-cleanup final player")
        require(count > 0 or terminal_phase == "before_input", "zero-step death must occur before input, not fabricate a callback")
    elif terminal == "wave_clear":
        require(count > 0, "wave_clear requires an observed first-wave physics segment")
    if natural:
        errors.extend(_natural_initial_errors(report.get("initial")))
        errors.extend(_natural_state_errors(final, "final", {"death": "RESULT", "wave_clear": "WAVE_CLEAR"}.get(terminal, "PLAYING")))
    if terminal_phase == "after_callbacks" and samples and isinstance(samples[-1], dict):
        player_fields = ("position", "velocity", "health", "shield", "dash_active", "dash_cooldown", "stealth_remaining", "layer", "mask", "shape_disabled")
        for key in player_fields + (NATURAL_FIELDS if natural else ()):
            if key in final and key in samples[-1]:
                observed, sealed = samples[-1][key], final[key]
                if natural and key in NATURAL_FIELDS:
                    equal = type(observed) is type(sealed) and observed == sealed
                elif _vector(observed) and _vector(sealed):
                    equal = all(_close(a, b) for a, b in zip(observed, sealed))
                elif _number(observed) and _number(sealed):
                    equal = _close(observed, sealed)
                else:
                    equal = type(observed) is type(sealed) and observed == sealed
                require(equal, f"final.{key} differs from the last after-callback observation")

    simulated = 0.0
    last_wall, last_render, last_kills = 0.0, -1, 0
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
        dash = run["mode"] == "dash" and (index % 180 == 0 if natural else index in DASH_STEPS)
        for key in ("dash_requested", "dash_pressed_pre"):
            require(sample.get(key) is dash, f"{label}.{key} differs from the registered dash event")
        aim = sample.get("actual_aim")
        terminal_sample = terminal_phase == "after_callbacks" and index == count
        unvalidated_terminal = terminal_sample and (terminal == "death" or (natural and terminal == "wave_clear")) and sample.get("aim_validated") is False
        if natural:
            expected_state = {"death": "RESULT", "wave_clear": "WAVE_CLEAR"}.get(terminal, "PLAYING") if terminal_sample else "PLAYING"
            errors.extend(_natural_state_errors(sample, label, expected_state))
            if _integer(sample.get("kills")):
                require(sample["kills"] >= last_kills, f"{label}.kills cannot decrease within the first wave")
                last_kills = sample["kills"]
        require(sample.get("aim_validated") is True or unvalidated_terminal, f"{label}.aim_validated may be false only for the final after-callback death or natural wave_clear")
        require(_vector(aim), f"{label}.actual_aim must remain a finite vector observation")
        if not unvalidated_terminal:
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

    if natural and _integer(final.get("kills")):
        require(final["kills"] >= last_kills, "final.kills cannot decrease after the last observed first-wave step")
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
    if result["valid"]:
        result["observation_assessment"]["outcome"] = "budget_exhausted" if terminal == "step_budget" else terminal
        result["observation_assessment"]["wave_clear_observed"] = natural and terminal == "wave_clear"
    return result


def check_pressure_capture(report: dict) -> list[str]:
    """Independent optional stress observer integrity; never certify visual quality."""
    from check_late_crowd_report import check_entities
    import re
    errors = []
    def require(ok, message):
        if not ok: errors.append(message)
    try:
        run, capture, samples = report["run"], report["pressure_capture"], report["samples"]
        require(run["scenario"] == "stress60" and run["capture"] == "peak", "wrong pressure capture configuration")
        require(report["initial"]["enemies"] == 60, "not the existing stress60 startup")
        require(capture["valid"] is True, "producer pressure capture invalid")
        require(capture["viewport"] == [1280,720] and capture["display"] not in ("", "headless") and bool(capture["adapter"]), "not expected native pressure viewport")
        rows, history, frames = capture["observations"], capture["capture_history"], capture["frames"]
        if not all(isinstance(value,list) for value in (samples,rows,history,frames)):
            return errors + ["pressure samples/observations/history/frames must be arrays"]
        require(bool(rows) and len(rows) == len(samples), "pressure observations must cover every base sample")
        for index, (row, sample) in enumerate(zip(rows, samples), 1):
            if not isinstance(row,dict) or not isinstance(sample,dict):
                return errors + ["pressure/base observations must be objects"]
            require(all(row.get(k) == v for k,v in sample.items()), "pressure/base sample substitution")
            require(row["index"] == index == sample["step"] and row["frame"] == sample["physics_frame"] and _close(row["wall"],sample["wall_seconds"]), "pressure physics binding mismatch")
            require(row["segment"] == 1 and row["eligible"] is (sample["health"] > 0), "invalid pressure eligibility or segment")
            entities = row["entities"]
            errors.extend(check_entities(entities, entities["canvas"]))
            require(row["live"] == len(entities["bodies"]) and 0 <= row["live"] <= 60 and row["visible"] == entities["visible"], "pressure live/visible count mismatch")
            require(all(b["kind"].lower() in ENEMY_KINDS for b in entities["bodies"]), "foreign pressure actor kind")
            radius = entities["player_radius"]
            require(_number(radius) and radius>0, "invalid pressure player radius")
            if _number(radius) and radius>0:
                gap = min((math.dist(row["position"],b["position"])-radius-b["radius"] for b in entities["bodies"]),default=None)
                require((gap is None and entities["nearest_gap"] is None) or _close(gap,entities["nearest_gap"]), "pressure actor clearance mismatch")
            warnings = row["warnings"]
            require(len({w["id"] for w in warnings}) == len(warnings), "duplicate pressure warning")
            for w in warnings:
                require(_integer(w["id"]) and w["id"]>0 and _vector(w["position"]) and all(_number(w[k]) for k in ("radius","elapsed","duration")) and w["radius"]>0 and 0<=w["elapsed"]<w["duration"], "invalid pressure lob warning")
        eligible = [r for r in rows if r["eligible"]]
        peak = max(eligible, key=lambda r:r["live"], default={})
        require(bool(peak) and capture["peak"] == peak, "wrong pressure peak or earliest tie")
        require(capture["visible_peak"] == max(eligible,key=lambda r:r["visible"],default={}), "wrong visible peak or earliest tie")
        if not peak: return errors
        previous = None
        for h in history:
            require(all(_integer(h[k]) and h[k]>0 for k in ("frame","process_frame","segment")), "pressure draw counters must be positive integers")
            require(_integer(h["observation"]) and 1<=h["observation"]<=len(rows), "invalid pressure draw observation")
            row = rows[h["observation"]-1]
            require(row["eligible"] and h["frame"] == row["frame"] and h["segment"] == 1 and _close(h["physics_wall"],row["wall"]) and _number(h["wall"]) and row["wall"]<=h["wall"]<=report["wall_seconds"], "pressure draw binding mismatch")
            if previous:
                require(h["wall"]-previous["wall"]>=.1-1e-6 and h["frame"]>previous["frame"] and h["process_frame"]>previous["process_frame"], "invalid pressure draw pacing/order")
            previous=h
        expected = [h for h in history if abs(h["wall"]-peak["wall"])<=3]
        require(bool(frames) and len(frames)==len(expected) and all(all(f.get(k)==v for k,v in h.items()) for f,h in zip(frames,expected)), "pressure peak frames omitted/reordered/substituted")
        for index,f in enumerate(frames):
            require(f["path"]==f"build/diagnostics/movement-repeatability/{run['run']}-peak/peak-{index:03d}.png" and re.fullmatch(r"[0-9a-f]{64}",f["sha256"]) is not None, "invalid pressure frame path/hash")
        require(capture["cache_limit"]==120 and _integer(capture["max_retained"]) and len(frames)<=capture["max_retained"]<=120, "unbounded or understated pressure cache")
        # Independent event replay: each draw follows its bound physics row;
        # count the union, not ring+candidate references to the same bitmap.
        draws = {h["observation"]:i for i,h in enumerate(history)}
        require(len(draws)==len(history), "multiple pressure draws bound to one physics row")
        ring, candidate, running_peak, maximum = [], [], None, 0
        for row in rows:
            if row["eligible"] and (running_peak is None or row["live"]>running_peak["live"]):
                running_peak=row
                candidate=[i for i in ring if history[i]["wall"]>=row["wall"]-3]
            if row["index"] not in draws:
                continue
            i=draws[row["index"]]
            h=history[i]
            ring=[j for j in ring if history[j]["wall"]>=h["wall"]-3]+[i]
            if running_peak is not None and abs(h["wall"]-running_peak["wall"])<=3:
                candidate.append(i)
            maximum=max(maximum,len(set(ring+candidate)))
        require(capture["max_retained"]==maximum, "pressure cache union maximum mismatch")
        window = capture["window"]
        start, end = max(0.0,peak["wall"]-3), min(report["wall_seconds"],peak["wall"]+3)
        times = [start]+[f["wall"] for f in frames]+[end]
        gap = max(b-a for a,b in zip(times,times[1:]))
        numeric = {"requested_start":peak["wall"]-3,"requested_end":peak["wall"]+3,
                   "coverage_start":start,"coverage_end":end,"terminal_wall":report["wall_seconds"],
                   "first_capture":frames[0]["wall"],"last_capture":frames[-1]["wall"],
                   "left_gap":frames[0]["wall"]-start,"right_gap":end-frames[-1]["wall"],"max_gap":gap,"gap_limit":.25}
        require(all(_close(window.get(k),v) for k,v in numeric.items()), "pressure window arithmetic mismatch")
        left,right = peak["wall"]<3,report["wall_seconds"]<peak["wall"]+3
        require(window["truncated_left"] is left and window["truncated_right"] is right and window["left_reason"]==("startup" if left else "none") and window["right_reason"]==(report["terminal"] if right else "none") and window["terminal_reason"]==report["terminal"], "pressure truncation declaration mismatch")
        require(window["observed_interval_complete"] is True and gap<=.25 and all(b>=a for a,b in zip(times,times[1:])), "pressure observed interval has missing coverage")
    except (KeyError,TypeError,ValueError,IndexError,OverflowError,AttributeError) as error:
        errors.append(f"malformed pressure capture: {type(error).__name__}")
    return errors


def check_pressure_files(report: dict, project: Path) -> list[str]:
    """Read original PNG bytes; callers must first pass the pure capture gate."""
    import hashlib
    from PIL import Image
    errors=[]
    root=project.resolve()
    for frame in report["pressure_capture"]["frames"]:
        try:
            path=(root/frame["path"]).resolve()
            if not path.is_relative_to(root) or hashlib.sha256(path.read_bytes()).hexdigest()!=frame["sha256"]:
                errors.append("pressure PNG path/bytes mismatch")
                continue
            with Image.open(path) as image:
                if image.format!="PNG" or image.size!=(1280,720) or len(set(image.convert("L").getextrema()))!=2:
                    errors.append("pressure PNG flat or incorrectly sized")
        except (OSError,ValueError) as error:
            errors.append(f"unreadable pressure PNG: {type(error).__name__}")
    return errors


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("report", type=Path)
    parser.add_argument("--require-pressure",action="store_true")
    parser.add_argument("--project",type=Path,default=Path(__file__).resolve().parents[2])
    arguments = parser.parse_args()
    try:
        report = json.loads(arguments.report.read_text(encoding="utf-8-sig"))
        result = check_report(report)
        if arguments.require_pressure:
            capture_errors=check_pressure_capture(report)
            result["errors"].extend(capture_errors)
            if not capture_errors: result["errors"].extend(check_pressure_files(report,arguments.project))
            result["valid"]=not result["errors"]
    except (OSError, UnicodeError, json.JSONDecodeError) as error:
        result = _result()
        result["errors"].append(f"could not read report: {error}")
    print(json.dumps(result, ensure_ascii=False, allow_nan=False))
    return 0 if result["valid"] else 2


if __name__ == "__main__":
    raise SystemExit(main())
