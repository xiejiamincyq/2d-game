"""Sequential, non-release S1-B matrix. Standard library only."""
from __future__ import annotations

import argparse
import csv
import hashlib
import json
import math
import os
from pathlib import Path
import re
import subprocess
import sys
import time

SEEDS = (20260908, 20260909, 20260910)
TIMEOUT_SECONDS = 50
COMPARE_FIELDS = ("position", "velocity", "health", "shield", "input", "actual_aim",
                  "dash_active", "dash_requested", "dash_cooldown", "stealth_remaining",
                  "physics_delta", "scale_before_physics", "scale_after_physics",
                  "spawn_rng_state", "remaining_enemies")


def make_slots(batch: str, smoke: bool = False, track: str = "D", seed: int = 20260908, mode: str = "walk") -> list[dict]:
    cases = [(track, seed, mode, 1)] if smoke else [
        (t, s, m, repeat) for t in ("D", "R") for s in SEEDS
        for m in ("walk", "dash") for repeat in (1, 2, 3)]
    return [{"run": f"{batch}-{t}-{s}-{m}-{repeat}", "track": t, "seed": s,
             "mode": m, "repeat": repeat} for t, s, m, repeat in cases]


def summarize(report: dict) -> dict:
    samples = report["samples"]
    path = streak = longest = 0.0
    previous_position = report["initial"]["player"]["position"]
    actual_dash_starts = 0
    previous_dash = report["initial"]["player"].get("dash_active", False)
    streak_start = longest_start = longest_end = None
    for sample in samples:
        actual_dash_starts += bool(sample["dash_active"]) and not previous_dash
        previous_dash = bool(sample["dash_active"])
        movement = [b - a for a, b in zip(sample["position_before"], sample["position"])]
        # Include the observed gap between callbacks, not only the actor callback.
        path += math.dist(previous_position, sample["position_before"]) + math.hypot(*movement)
        previous_position = sample["position"]
        direction = sample["input"]
        length = math.hypot(*direction)
        budget = sample["requested_motion_pixels"]
        along = sum(a * b for a, b in zip(movement, direction)) / length if length else 0.0
        if budget > 0 and length > 0 and along < budget * 0.1:
            if not streak:
                streak_start = sample["step"]
            streak += sample["physics_delta"]
            if streak > longest:
                longest, longest_start, longest_end = streak, streak_start, sample["step"]
        else:
            streak = 0.0
    initial = report["initial"]["player"]["position"]
    final = report["final"]["position"]
    return {"terminal": report["terminal"], "sample_steps": report["sample_steps"],
            "physics_steps": report["physics_steps"], "simulated_seconds": report["simulated_seconds"],
            "wall_seconds": report["wall_seconds"], "unscaled_step_seconds": report["unscaled_step_seconds"],
            "net_pixels": math.dist(initial, final), "path_pixels": path,
            "health_loss": report["health_loss"], "shield_loss": report["shield_loss"],
            "dash_requested_count": sum(bool(s["dash_requested"]) for s in samples),
            "actual_dash_started_count": actual_dash_starts,
            "motion_budget_basis": "walk_speed_even_during_dash",
            "longest_low_progress_sim_seconds": longest,
            "low_progress_start_step": longest_start, "low_progress_end_step": longest_end}


def first_divergence(left: dict, right: dict) -> dict | None:
    def equal(a, b):
        if isinstance(a, list) and isinstance(b, list):
            return len(a) == len(b) and all(equal(x, y) for x, y in zip(a, b))
        if isinstance(a, (float, int)) and isinstance(b, (float, int)):
            return math.isclose(a, b, rel_tol=0.0, abs_tol=0.000001)
        return a == b
    for one, two in zip(left["samples"], right["samples"]):
        for field in COMPARE_FIELDS:
            if not equal(one.get(field), two.get(field)):
                return {"step": one["step"], "field": field, "baseline": one.get(field), "repeat": two.get(field)}
    if len(left["samples"]) != len(right["samples"]) or left["terminal"] != right["terminal"]:
        return {"step": min(len(left["samples"]), len(right["samples"])) + 1, "field": "terminal_or_length",
                "baseline": [left["terminal"], len(left["samples"])], "repeat": [right["terminal"], len(right["samples"])]}
    return None


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as source:
        for block in iter(lambda: source.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def source_hashes(project: Path) -> dict:
    files = [project / "project.godot", Path(__file__).resolve(),
             project / "scripts/art/check_movement_repeatability_report.py"]
    files.extend(sorted((project / "scripts").rglob("*.gd")))
    return {str(path.relative_to(project)).replace("\\", "/"): sha256(path) for path in files}


def validate_save_evidence(report: dict) -> list[str]:
    """Require the complete six-file isolation evidence, not empty-map equality."""
    expected = {base + suffix for base in ("user://five_minute_overdrive_run_v1.json",
                "user://five_minute_overdrive_run_test_v1.json") for suffix in ("", ".tmp", ".bak")}
    errors = []
    before, after = report.get("real_save_hashes_before"), report.get("real_save_hashes_after")
    for name, hashes in (("before", before), ("after", after)):
        if not isinstance(hashes, dict) or set(hashes) != expected:
            errors.append(f"Real save evidence {name} must contain exactly six known paths")
        elif any(not isinstance(value, str) or (value != "absent" and not re.fullmatch(r"[0-9a-fA-F]{64}", value)) for value in hashes.values()):
            errors.append(f"Real save evidence {name} has invalid hashes")
    if before != after:
        errors.append("Real save hashes changed")
    if report.get("initial", {}).get("save_path_isolated") is not True:
        errors.append("Run store was not explicitly isolated")
    return errors


def run_case(slot: dict, args, output: Path, baseline_hashes: dict, checker) -> tuple[dict, dict | None]:
    run_id = slot["run"]
    report_path, log_path = output / f"{run_id}.json", output / f"{run_id}.log"
    argv = [str(args.godot), "--path", str(args.project), "--max-fps", "60", "--audio-driver", "Dummy"]
    if args.headless:
        argv.append("--headless")
    argv += ["--script", "res://scripts/art/VerifyMovementRepeatability.gd", "--",
             f"--seed={slot['seed']}", f"--track={slot['track']}", f"--mode={slot['mode']}",
             f"--run={run_id}", f"--steps={args.steps}", "--clock=realtime"]
    record = dict(slot, status="invalid", errors=[], external={"argv": argv, "cwd": str(args.project),
                  "logfile": str(log_path), "report_file": str(report_path), "timeout_seconds": TIMEOUT_SECONDS,
                  "headless": args.headless, "fixed_fps": False, "movie": False})
    external, errors = record["external"], record["errors"]
    if report_path.exists() or log_path.exists():
        errors.append("Refusing existing per-run evidence")
        return record, None
    if source_hashes(args.project) != baseline_hashes:
        errors.append("Source hashes changed before launch")
        return record, None
    started = time.monotonic()
    try:
        with log_path.open("x", encoding="utf-8") as log:
            completed = subprocess.run(argv, cwd=args.project, stdout=log, stderr=subprocess.STDOUT,
                                       timeout=TIMEOUT_SECONDS, check=False,
                                       creationflags=subprocess.CREATE_NO_WINDOW if os.name == "nt" else 0)
        external["exit_code"] = completed.returncode
    except subprocess.TimeoutExpired:
        external["exit_code"] = None
        errors.append("Godot timed out; this slot is retained, not rerun")
    except OSError as exc:
        external["exit_code"] = None
        errors.append(f"Godot launch failed: {exc}")
    external["wall_seconds_including_startup_cleanup"] = time.monotonic() - started
    log_text = log_path.read_text(encoding="utf-8", errors="replace") if log_path.exists() else ""
    external["log_sha256"] = sha256(log_path) if log_path.exists() else None
    if external["exit_code"] != 0:
        errors.append(f"Nonzero/missing exit code: {external['exit_code']}")
    markers = re.findall(r"^MOVEMENT_SAMPLE_COMPLETE\b.*$", log_text, re.MULTILINE)
    if len(markers) != 1 or f"run={run_id} valid=true " not in markers[0]:
        errors.append("Missing, duplicate, mismatched or invalid completion marker")
    if re.search(r"SCRIPT ERROR|ERROR:|TEST FAIL:|ObjectDB instances were leaked|RID.+leaked|resources still in use", log_text):
        errors.append("Exit log contains errors or resource leaks")
    report = None
    try:
        report = json.loads(report_path.read_text(encoding="utf-8-sig"))
        external["report_sha256"] = sha256(report_path)
        for key in ("run", "track", "seed", "mode"):
            if report["run"][key] != slot[key]:
                errors.append(f"Report/slot mismatch: {key}")
        if report["run"]["steps"] != args.steps:
            errors.append("Report step budget mismatch")
        if report["run"].get("clock") != "realtime":
            errors.append("Report clock does not match realtime launch")
        errors.extend(validate_save_evidence(report))
        if not report["cleanup"]["owned_tree_freed"] or not report["cleanup"]["audio_references_cleared"]:
            errors.append("Owned scene/audio cleanup failed")
        unscaled_seconds = report["unscaled_step_seconds"]
        ratio = report["wall_seconds"] / unscaled_seconds if unscaled_seconds > 0 else None
        pacing_eligible = report["sample_steps"] >= 120
        external["wall_to_unscaled_step_ratio"] = ratio
        external["pacing_consistent"] = (ratio is not None and 0.9 <= ratio <= 1.1) if pacing_eligible else None
        external["pacing_assessment"] = "ratio_only_not_real_clock_certification" if pacing_eligible else "fewer_than_120_samples"
        if not args.smoke and pacing_eligible and not external["pacing_consistent"]:
            errors.append("Invalid formal pacing: wall/unscaled-step ratio outside 0.9..1.1")
        record["checker"] = checker(report)
        if not record["checker"]["valid"]:
            errors.extend(record["checker"]["errors"])
        record["metrics"] = summarize(report)
    except (OSError, ValueError, TypeError, KeyError) as exc:
        errors.append(f"Missing/invalid report or summary fields: {exc}")
    external["source_hashes_unchanged"] = source_hashes(args.project) == baseline_hashes
    if not external["source_hashes_unchanged"]:
        errors.append("Source hashes changed during run")
    record["status"] = "valid_measurement" if not errors else "invalid"
    return record, report


def save_summary(path: Path, manifest: dict, reports: dict) -> None:
    groups = []
    for track in ("D", "R"):
        for seed in SEEDS:
            for mode in ("walk", "dash"):
                rows = [r for r in manifest["runs"] if (r["track"], r["seed"], r["mode"]) == (track, seed, mode)]
                valid = [r for r in rows if r["status"] == "valid_measurement"]
                comparisons = []
                if valid:
                    for repeat in valid[1:]:
                        comparisons.append({"baseline_run": valid[0]["run"], "repeat_run": repeat["run"],
                                            "first_divergence": first_divergence(reports[valid[0]["run"]], reports[repeat["run"]])})
                groups.append({"track": track, "seed": seed, "mode": mode,
                               "valid_runs": len(valid), "complete_three_repeats": len(valid) == 3,
                               "comparisons": comparisons})
    manifest["groups"] = groups
    path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2, allow_nan=False) + "\n", encoding="utf-8")
    fields = ["run", "track", "seed", "mode", "repeat", "status", "terminal", "sample_steps", "physics_steps",
              "simulated_seconds", "wall_seconds", "unscaled_step_seconds", "net_pixels", "path_pixels",
              "health_loss", "shield_loss", "dash_requested_count", "actual_dash_started_count", "motion_budget_basis", "longest_low_progress_sim_seconds",
              "low_progress_start_step", "low_progress_end_step", "exit_code", "logfile", "errors"]
    with path.with_suffix(".csv").open("w", encoding="utf-8-sig", newline="") as output:
        writer = csv.DictWriter(output, fieldnames=fields, extrasaction="ignore")
        writer.writeheader()
        for record in manifest["runs"]:
            writer.writerow(dict(record, **record.get("metrics", {}),
                                 exit_code=record.get("external", {}).get("exit_code"),
                                 logfile=record.get("external", {}).get("logfile"), errors=" | ".join(record.get("errors", []))))


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", type=Path)
    parser.add_argument("--project", type=Path, default=Path(__file__).resolve().parents[2])
    parser.add_argument("--batch")
    parser.add_argument("--headless", action="store_true", help="No visual/performance acceptance")
    parser.add_argument("--smoke", action="store_true", help="One case only; never a formal matrix")
    parser.add_argument("--steps", type=int, default=1200, help="Only smoke may shorten the 1200-step budget")
    parser.add_argument("--smoke-track", choices=("D", "R"), default="D")
    parser.add_argument("--smoke-seed", type=int, choices=SEEDS, default=SEEDS[0])
    parser.add_argument("--smoke-mode", choices=("walk", "dash"), default="walk")
    parser.add_argument("--self-test", action="store_true", help="Pure Python self-check; never launches Godot")
    args = parser.parse_args()
    if args.self_test:
        self_test()
        return 0
    if not args.godot or not args.godot.is_file() or not args.batch or not re.fullmatch(r"[A-Za-z0-9_-]{1,40}", args.batch):
        parser.error("Provide an existing --godot executable and unique safe --batch (1..40 characters)")
    if not 1 <= args.steps <= 1200 or (not args.smoke and args.steps != 1200):
        parser.error("Formal matrix requires 1200 steps; smoke allows 1..1200")
    args.project, args.godot = args.project.resolve(), args.godot.resolve()
    from check_movement_repeatability_report import check_report
    output = args.project / "build/diagnostics/movement-repeatability"
    output.mkdir(parents=True, exist_ok=True)
    if any(p.name.startswith(args.batch + "-") for p in output.iterdir()):
        parser.error("Batch prefix already has evidence; choose a fresh --batch, no overwrite/resume")
    path = output / f"{args.batch}-matrix.json"
    hashes = source_hashes(args.project)
    slots = make_slots(args.batch, args.smoke, args.smoke_track, args.smoke_seed, args.smoke_mode)
    manifest = {"batch": args.batch, "formal_matrix": not args.smoke, "acceptance": "running",
                "planned_slots": len(slots), "steps_per_slot": args.steps, "godot_sha256": sha256(args.godot),
                "source_sha256": hashes, "runs": [dict(s, status="not_run") for s in slots],
                "comparison_abs_tolerance": 0.000001, "low_progress_fraction": 0.1,
                "limitations": "Measurement only, not balance/visual/performance/determinism acceptance. Death retained; no survival selection. R wall-clock evidence is separate from sampled game time. Headless runs have no visual acceptance. Low progress means along-input travel below 10% of walk-equivalent input budget, even during dash; it is not true dash budget or proof of stuck movement. Duration accumulates physics simulation seconds. First divergence excludes wall/absolute frame identifiers."}
    with path.open("x", encoding="utf-8") as reserved:
        reserved.write("{}\n")
    reports = {}
    save_summary(path, manifest, reports)
    try:
        for index, slot in enumerate(slots):
            print(f"MATRIX RUN {index + 1}/{len(slots)} {slot['run']}", flush=True)
            record, report = run_case(slot, args, output, hashes, check_report)
            manifest["runs"][index] = record
            if report is not None:
                reports[slot["run"]] = report
            save_summary(path, manifest, reports)
            if record["status"] != "valid_measurement":
                manifest["acceptance"] = "invalid_stopped_no_retry"
                break
        else:
            manifest["acceptance"] = "smoke_measurement_complete" if args.smoke else "measurement_matrix_complete"
    except (KeyboardInterrupt, OSError, ValueError, TypeError, KeyError) as exc:
        manifest["acceptance"] = "interrupted"
        manifest["runner_error"] = str(exc)
    save_summary(path, manifest, reports)
    print(f"MATRIX COMPLETE {manifest['acceptance']} {path}", flush=True)
    return 0 if manifest["acceptance"].endswith("_complete") else 2


def self_test() -> None:
    slots = make_slots("unit")
    assert len(slots) == 36 and len({slot["run"] for slot in slots}) == 36
    assert all(slot["track"] == "D" for slot in slots[:18])
    assert slots[18]["track"] == "R" and slots[-1]["repeat"] == 3
    assert len(make_slots("unit", True, "R", 20260910, "dash")) == 1
    report = {"initial": {"player": {"position": [0, 0]}}, "final": {"position": [2, 0]},
              "terminal": "death", "sample_steps": 2, "physics_steps": 2,
              "simulated_seconds": 0.02, "wall_seconds": 0.03, "unscaled_step_seconds": 2 / 60,
              "health_loss": 12, "shield_loss": 3, "samples": [
                  {"step": 1, "position_before": [0, 0], "position": [0, 0], "input": [1, 0],
                   "requested_motion_pixels": 2, "physics_delta": 0.01, "dash_requested": False, "dash_active": False},
                  {"step": 2, "position_before": [0, 0], "position": [2, 0], "input": [1, 0],
                   "requested_motion_pixels": 2, "physics_delta": 0.01, "dash_requested": True, "dash_active": True}]}
    metrics = summarize(report)
    assert metrics["terminal"] == "death" and metrics["net_pixels"] == 2
    assert metrics["path_pixels"] == 2 and metrics["longest_low_progress_sim_seconds"] == 0.01
    assert metrics["health_loss"] == 12 and metrics["shield_loss"] == 3
    assert metrics["actual_dash_started_count"] == 1
    assert first_divergence(report, report) is None
    changed = dict(report, samples=[dict(report["samples"][0], position=[0.5, 0]), report["samples"][1]])
    assert first_divergence(report, changed)["step"] == 1
    ended = dict(report, samples=report["samples"][:1])
    assert first_divergence(report, ended)["field"] == "terminal_or_length"
    print("MATRIX SELF TEST PASS (no Godot invoked)")


if __name__ == "__main__":
    sys.exit(main())
