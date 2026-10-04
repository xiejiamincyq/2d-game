"""Read-only measurement integrity checker; not visual or human acceptance."""
import argparse
import hashlib
import json
import math
import re
from pathlib import Path

REAL_SAVE_PATHS = {base + suffix for base in ('user://five_minute_overdrive_run_v1.json',
                  'user://five_minute_overdrive_run_test_v1.json') for suffix in ('', '.tmp', '.bak')}

def check_resume(checkpoint, resumed, checkpoint_sha):
    reference = resumed.get("resume_reference", {})
    config = resumed.get('config', {})
    origin = checkpoint.get('config', {}).get('save_path')
    strategy = config.get('resume_strategy', 'consume')
    destination_valid = strategy == 'consume' and config.get('save_path') == origin
    if strategy == 'copy':
        run = config.get('run', '')
        source_digest = checkpoint.get('isolated_save_sha256')
        saved = checkpoint['final']['snapshot']
        restored_run = {'map_seed': saved.get('map_seed'), 'kills': saved.get('kills'),
                        'coins': saved.get('coins'), 'wave': saved.get('pending_stage', 0)-1,
                        'waiting_for_advance': True}
        destination_valid = (isinstance(run,str) and re.fullmatch(r'[A-Za-z0-9_-]{1,80}',run) is not None
            and config.get('save_path') == f'user://natural-run/{run}/run.json' and config['save_path'] != origin
            and origin == f"user://natural-run/{checkpoint['config']['run']}/run.json"
            and isinstance(source_digest,str) and re.fullmatch(r'[0-9a-f]{64}',source_digest) is not None
            and reference.get('source_save_path') == origin
            and reference.get('restored_run') == restored_run
            and reference.get('restored_growth') == {key: saved.get(key) for key in
                    ['coins', 'family_levels', 'upgrade_counts', 'evolution', 'settlement']}
            and any(s.get('state') == 'PLAYING' and s.get('wave') == saved.get('pending_stage')
                    for s in resumed.get('samples', []))
            and all(reference.get(key) == source_digest for key in
                    ['source_save_sha256','copied_save_sha256','source_save_sha256_after']))
    return [] if (checkpoint.get("terminal") == "checkpoint" and checkpoint.get("valid") is True
                  and isinstance(checkpoint.get("process_id"), int) and checkpoint["process_id"] > 0
                  and isinstance(resumed.get("process_id"), int) and resumed["process_id"] > 0
                  and resumed["process_id"] != checkpoint["process_id"]
                  and resumed.get("source_sha256") == checkpoint.get("source_sha256")
                  and resumed.get("config", {}).get("resume") == checkpoint["config"]["run"]
                  and destination_valid
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
    if set(before) != REAL_SAVE_PATHS or before != report.get("real_saves_after"):
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
    config = report.get('config', {})
    if 'movement' in config:
        movement = config['movement']
        if movement not in ['walk','dash'] or any(type(s.get('dash_requested')) is not bool or
                (movement == 'walk' and s['dash_requested']) for s in samples):
            errors.append('invalid movement mode or recorded dash request')
    if terminal == "checkpoint":
        final = report.get("final", {})
        if final.get("state") != "SETTLEMENT" or not final.get("snapshot") or final["snapshot"].get("boundary") != "settlement" or report.get("result"):
            errors.append("checkpoint is not a natural saved settlement")
        if 'checkpoint_wave' in config:
            wave = config['checkpoint_wave']
            snapshot = final.get('snapshot', {})
            observed = {s.get('wave') for s in samples}
            cleared = {e.get('wave') for e in report.get('events', [])
                       if e.get('event') == 'state' and e.get('state') == 'WAVE_CLEAR'}
            if (type(wave) is not int or not 1 <= wave <= 5 or config.get('mode') != 'checkpoint'
                    or final.get('wave') != wave or snapshot.get('pending_stage') != wave+1
                    or snapshot.get('settlement', {}).get('wave') != wave
                    or observed != set(range(1,wave+1)) or cleared != observed):
                errors.append('checkpoint did not naturally complete the requested waves')
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
