"""Read-only measurement integrity checker; not visual or human acceptance."""
import argparse
import hashlib
import json
import math
import re
from pathlib import Path

def check_resume(checkpoint, resumed, checkpoint_sha):
    reference = resumed.get("resume_reference", {})
    return [] if (checkpoint.get("terminal") == "checkpoint" and checkpoint.get("valid") is True
                  and isinstance(checkpoint.get("process_id"), int) and checkpoint["process_id"] > 0
                  and isinstance(resumed.get("process_id"), int) and resumed["process_id"] > 0
                  and resumed["process_id"] != checkpoint["process_id"]
                  and resumed.get("source_sha256") == checkpoint.get("source_sha256")
                  and resumed.get("config", {}).get("resume") == checkpoint["config"]["run"]
                  and resumed["config"].get("save_path") == checkpoint["config"]["save_path"]
                  and reference.get("report_sha256") == checkpoint_sha
                  and reference.get("snapshot_before") == checkpoint["final"]["snapshot"]
                  and reference.get("restored") == {key: checkpoint["final"]["snapshot"][key] for key in ("player", "settlement")}
                  and reference.get("verified") is True) else ["cross-process checkpoint mismatch"]

def check_log(log, run):
    errors = []
    if re.search(r"SCRIPT ERROR|ERROR:|TEST FAIL:|ObjectDB instances were leaked|RID.+leaked|resources still in use", log):
        errors.append("runtime error/leak in original log")
    markers = re.findall(r"(?m)^NATURAL_RUN_COMPLETE run=(\S+) valid=true steps=\d+ terminal=(\S+)", log)
    if len(markers) != 1 or markers[0][0] != run:
        errors.append("missing/duplicate/wrong-run completion marker")
    return errors

def check_report(report):
    errors = []
    if report.get("valid") is not True or report.get("acceptance") != "measurement_only":
        errors.append("producer did not produce valid measurement")
    before = report.get("real_saves_before", {})
    if len(before) != 6 or before != report.get("real_saves_after"):
        errors.append("real save isolation mismatch")
    if report.get("orphan_after", 999) > report.get("orphan_before", 0):
        errors.append("owned-tree leak")
    if not isinstance(report.get("map_seed"), int) or report["map_seed"] == 0:
        errors.append("actual map seed missing")
    samples = report.get("samples", [])
    if not samples:
        errors.append("empty sampling")
    simulation, frame, wall = 0.0, -1, -1.0
    for step, sample in enumerate(samples, 1):
        delta = sample["delta"]
        simulation += delta
        if (sample["step"] != step or sample["frame"] <= frame or sample["wall"] <= wall
                or not math.isfinite(delta) or not 0 < delta <= 1 / 60 + 1e-6
                or not math.isclose(simulation, sample["simulation"], abs_tol=1e-6)
                or not math.isfinite(sample["aim_dot"]) or sample["aim_dot"] < .9999
                or any(not math.isfinite(v) for v in sample["position"])
                or not math.isfinite(sample["health"]) or sample["health"] < 0
                or any(not math.isclose(a, b, abs_tol=1e-5) for a, b in zip(sample["input"], sample["actual_input"]))):
            errors.append(f"invalid sample {step}")
            break
        frame, wall = sample["frame"], sample["wall"]
    terminal = report.get("terminal")
    if terminal == "checkpoint":
        final = report.get("final", {})
        if final.get("state") != "SETTLEMENT" or not final.get("snapshot") or final["snapshot"].get("boundary") != "settlement" or report.get("result"):
            errors.append("checkpoint is not a natural saved settlement")
    elif terminal == "step_budget":
        if len(samples) != report["config"]["steps"] or report.get("result"):
            errors.append("truncated or mislabeled budget")
    elif terminal in ("death", "victory"):
        result = report.get("result", {})
        if not (report.get("restart_verified") is True and result.get("snapshot_cleared") is True and result.get("terminal") == terminal):
            errors.append("result/restart not verified")
        if terminal == "death" and result.get("health", 100) > 0:
            errors.append("progression failure is not natural death")
        if terminal == "victory" and result.get("wave") != 6:
            errors.append("victory before final wave")
    else:
        errors.append("invalid terminal")
    return errors


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("report", type=Path)
    parser.add_argument("--log", type=Path, required=True)
    parser.add_argument("--checkpoint", type=Path)
    args = parser.parse_args()
    report = json.loads(args.report.read_text(encoding="utf-8"))
    errors = check_report(report)
    errors.extend(check_log(args.log.read_text(encoding="utf-8-sig"), report["config"]["run"]))
    if report["config"].get("resume"):
        if args.checkpoint is None:
            errors.append("resume verification requires original checkpoint report")
        else:
            checkpoint = json.loads(args.checkpoint.read_text(encoding="utf-8"))
            errors.extend(check_resume(checkpoint, report, hashlib.sha256(args.checkpoint.read_bytes()).hexdigest()))
    project = Path(__file__).resolve().parents[2]
    for relative, expected in report.get("source_sha256", {}).items():
        source = (project / relative).resolve()
        if not source.is_relative_to(project) or hashlib.sha256(source.read_bytes()).hexdigest() != expected:
            errors.append(f"current source mismatch: {relative}")
    print(json.dumps({"valid": not errors, "errors": errors, "steps": len(report["samples"]), "terminal": report["terminal"], "scope": "measurement integrity; not complete S4/visual/human acceptance"}, ensure_ascii=False))
    raise SystemExit(1 if errors else 0)
