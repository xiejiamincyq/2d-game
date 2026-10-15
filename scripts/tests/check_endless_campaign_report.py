"""Read-only independent checks for actual, input-only endless journey legs."""
from check_campaign_chain_report import digest, read_json, number, sha, MARKERS, FORBIDDEN
import argparse
from pathlib import Path
import re
import math


def validate_profile(profile):
    errors = []
    def require(ok, label):
        if not ok:
            errors.append(label)
    if not isinstance(profile, dict):
        return ["missing real profile"]
    require(profile.get("sampled") is True and profile.get("complete") is True, "complete sampled profile")
    require(profile.get("overflow") is False and profile.get("invalid_clock") is False, "no truncated or invalid clock data")
    require(profile.get("fixed_fps_argument") is False and profile.get("audio_nodes_enabled") is True, "real clock and audio nodes")
    require(profile.get("sampling_image_readbacks") == 0 and type(profile.get("sampling_image_readbacks")) is int, "no sampled GPU readbacks")
    require(all(isinstance(profile.get(key), str) and profile[key] for key in ["adapter", "driver", "audio_driver", "display_server"])
            and profile.get("display_server") != "headless" and profile.get("audio_driver") != "Dummy", "real renderer and audio driver metadata")
    rows = profile.get("raw_rows")
    if not isinstance(rows, list) or not 1000 <= len(rows) <= 60000:
        return errors + ["bounded sufficient raw frame rows"]
    previous = None
    for row in rows:
        if not isinstance(row, dict) or not all(number(row.get(key), 1 if key in {"frame", "callback_index", "window_id", "wall_usec", "previous_wall_usec"} else 0)
                                              for key in ["frame", "callback_index", "window_id", "wall_usec", "previous_wall_usec", "enemies", "projectiles", "draw_calls"]):
            return errors + ["invalid raw frame counters"]
        if not isinstance(row.get("phase"), str) or re.fullmatch(r"(?:COMBAT|BOSS):[0-2]", row["phase"]) is None:
            return errors + ["invalid actual combat phase"]
        if not all(finite_ms(row.get(key)) for key in ["interval_ms", "process_ms", "physics_ms"]):
            return errors + ["invalid raw frame timings"]
        if row["wall_usec"] <= row["previous_wall_usec"] or not near(row["interval_ms"], (row["wall_usec"] - row["previous_wall_usec"]) / 1000):
            return errors + ["raw wall interval mismatch"]
        if previous:
            if row["frame"] <= previous["frame"] or row["callback_index"] <= previous["callback_index"] or row["wall_usec"] <= previous["wall_usec"]:
                return errors + ["nonmonotonic raw frame sequence"]
            # Engine process frames can advance without a render callback.
            # Require every observed callback, not an invented 1:1 render ratio.
            if row["window_id"] < previous["window_id"] or (row["window_id"] == previous["window_id"] and row["phase"] != previous["phase"]):
                return errors + ["invalid measured window identity"]
            if row["window_id"] == previous["window_id"] and (row["callback_index"] != previous["callback_index"] + 1 or row["previous_wall_usec"] != previous["wall_usec"]):
                return errors + ["filtered or missing sampled frames"]
            if row["window_id"] != previous["window_id"] and row["wall_usec"] - previous["wall_usec"] < 2000000:
                return errors + ["new measured window without required warmup"]
        previous = row
    groups = dict(all=rows, combat=[row for row in rows if row["phase"].startswith("COMBAT")],
                  boss=[row for row in rows if row["phase"].startswith("BOSS")], dense_at_least_12=[row for row in rows if row["enemies"] >= 12])
    require(bool(groups["combat"]) and bool(groups["boss"]), "actual combat and Boss windows")
    for name, part in groups.items():
        require(nested_near(profile.get(name), summarize_rows(part)), "raw summary mismatch: " + name)
    streak = longest = 0.0
    previous = None
    for row in groups["dense_at_least_12"]:
        streak = streak + row["interval_ms"] if previous and row["callback_index"] == previous["callback_index"] + 1 and row["window_id"] == previous["window_id"] else 0.0
        longest = max(longest, streak)
        previous = row
    require(near(profile.get("longest_contiguous_dense_seconds"), longest / 1000)
            and profile.get("dense_coverage_available") is (longest >= 5000), "actual contiguous dense coverage")
    return errors


def finite_ms(value):
    return type(value) in (int, float) and math.isfinite(value) and value >= 0


def near(actual, expected):
    return finite_ms(actual) and finite_ms(expected) and math.isclose(actual, expected, rel_tol=1e-8, abs_tol=1e-6)


def nested_near(actual, expected):
    if isinstance(expected, dict):
        return isinstance(actual, dict) and actual.keys() == expected.keys() and all(nested_near(actual[key], value) for key, value in expected.items())
    return near(actual, expected)


def distribution(values):
    ordered = sorted(values)
    size = len(values)
    return dict(count=size, mean=sum(values) / size, p50=ordered[math.ceil(size * .5) - 1],
                p95=ordered[math.ceil(size * .95) - 1], p99=ordered[math.ceil(size * .99) - 1], maximum=ordered[-1])


def summarize_rows(rows):
    if not rows:
        return {}
    intervals = [row["interval_ms"] for row in rows]
    total = sum(intervals)
    return dict(frames=len(rows), wall_seconds=total / 1000, effective_callback_fps=len(rows) * 1000 / total,
                interval_ms=distribution(intervals), process_ms=distribution([row["process_ms"] for row in rows]),
                physics_ms=distribution([row["physics_ms"] for row in rows]), enemy_peak=max(row["enemies"] for row in rows),
                projectile_peak=max(row["projectiles"] for row in rows), draw_call_peak=max(row["draw_calls"] for row in rows),
                intervals_over_16_667_ms=sum(value > 16.667 for value in intervals), intervals_over_33_333_ms=sum(value > 33.333 for value in intervals))


def validate(report, stage, actual_exit, log, saved, saved_sha, bank):
    errors = []
    def require(ok, label):
        if not ok:
            errors.append(label)
    if not isinstance(report, dict) or not number(stage, 1) or stage > 12:
        return ["invalid report/stage"]
    chapter, loop = (stage - 1) % 6 + 1, (stage - 1) // 6 + 1
    require(number(actual_exit) and actual_exit == 0, "actual process exit")
    require(isinstance(log, str) and re.search(FORBIDDEN, log) is None, "error/leak log")
    matches = re.findall(rf"(?m)^TEST PASS: {MARKERS[chapter - 1]} ([1-9][0-9]*)\r?$", log)
    require(len(matches) == 1 and number(report.get("assertions"), 1) and int(matches[0]) == report["assertions"], "unique positive terminal PASS")
    require(report.get("valid") is True and number(report.get("chapter"), 1) and report["chapter"] == chapter, "valid actual chapter")
    require(number(report.get("moves"), 501) and number(report.get("shots"), 51), "ordinary movement/fire")
    require(report.get("prerequisite_fixture") == [], "no preseed fixture")
    evidence = report.get("endless")
    if not isinstance(evidence, dict):
        return errors + ["missing endless receipt"]
    require(number(evidence.get("schema"), 1) and evidence["schema"] == 1 and number(evidence.get("loop"), 1) and evidence["loop"] == loop, "exact journey loop")
    require(evidence.get("used_preseed") is False and evidence.get("returned_to_main") is True, "ordinary return provenance")
    require(number(evidence.get("process_id"), 1) and number(evidence.get("previous_process_id")) and evidence["process_id"] != evidence["previous_process_id"], "different engine process")
    require(number(evidence.get("defeated_boss_instance"), 1) and number(evidence.get("expected_kills"), 1), "actual Boss and kill debt")
    samples = report.get("samples")
    last = samples[-1] if isinstance(samples, list) and samples and isinstance(samples[-1], dict) else {}
    require(last.get("state") == "CLEARED" and number(last.get("kills"), 1) and number(evidence.get("expected_kills"), 1) and last["kills"] >= evidence["expected_kills"], "actual saved victory")
    require(journey_state(saved, stage) and evidence.get("saved_state") == saved, "exact actual journal")
    before = evidence.get("before_state")
    require(journey_state(before, stage - 1), "sequential predecessor")
    require(sha(saved_sha) and evidence.get("saved_sha256") == saved_sha, "actual journal SHA")
    require(isinstance(bank, dict) and bool(bank) and all(sha(v) for v in bank.values()) and evidence.get("source_bank") == bank, "frozen source bank")
    require(evidence.get("next_entry") == dict(loop=stage // 6 + 1, chapter=stage % 6 + 1), "restored endless next entry")
    if journey_state(before, stage - 1) and journey_state(saved, stage):
        require(number(last.get("coins")) and last["coins"] == saved["coins"], "actual balance retained")
        expected = dict(before["inherited_counts"])
        choice, earned = evidence.get("choice"), evidence.get("earned_counts")
        require(isinstance(choice, str) and isinstance(earned, dict), "actual inheritance selection")
        if isinstance(choice, str) and isinstance(earned, dict):
            require(all(number(rank, 1) for rank in earned.values()), "earned ordinary ranks")
            require(all(earned.get(key, 0) >= rank for key, rank in expected.items()), "prior inheritance not lost")
            if choice:
                require(choice not in {"thunder_matrix", "orbital_storm", "rift_overdrive"} and number(earned.get(choice), 1) and earned[choice] > expected.get(choice, 0), "genuinely earned nonultimate card")
                expected[choice] = expected.get(choice, 0) + 1
            require(saved["inherited_counts"] == expected, "exactly one selected inherited rank")
    if "performance" in report:
        errors.extend(validate_profile(report["performance"]))
        require("source-bound GPU screenshots" not in report.get("native_scope", ""), "performance run inherits unsampled combat screenshot claim")
    return errors


def journey_state(value, stage):
    return (isinstance(value, dict) and set(value) == {"version", "cleared_stage", "coins", "inherited_counts", "pending_clear"}
            and number(value.get("version"), 1) and value["version"] == 1
            and number(value.get("cleared_stage")) and value["cleared_stage"] == stage
            and number(value.get("coins")) and isinstance(value.get("inherited_counts"), dict)
            and all(isinstance(key, str) and number(rank, 1) for key, rank in value["inherited_counts"].items())
            and value.get("pending_clear") == {})


EXTRA_SOURCES = ["project.godot", "export_presets.cfg", "assets/audio/overdrive_bone_breaking.mp3",
                 "scripts/tests/run_tests.ps1", "scripts/tests/run_campaign_chain.ps1", "scripts/tests/check_campaign_chain_report.py",
                 "themes/CyberTheme.tres", "themes/MintFarmTheme.tres", "scripts/tests/run_endless_campaign.ps1",
                 "scripts/tests/check_endless_campaign_report.py"]


def current_bank(root):
    bank = {}
    for folder in ["scripts", "scenes", "assets/art/actors/native", "assets/art/shaders"]:
        for path in (root / folder).rglob("*"):
            relative = path.relative_to(root)
            if path.is_file() and path.suffix in {".gd", ".uid", ".gdshader", ".tscn", ".tres"} and not any(part.startswith(".") for part in relative.parts):
                bank[relative.as_posix()] = digest(path)
    for path in EXTRA_SOURCES:
        if (root / path).is_file():
            bank[path] = digest(root / path)
    return bank


def safe_id(value):
    return isinstance(value, str) and re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]{0,79}", value) is not None


def valid_process_receipt(receipt, engine_id):
    if not isinstance(receipt, dict):
        return False
    observed = receipt.get("observed_engine_process_ids")
    return (number(receipt.get("actual_exit")) and receipt["actual_exit"] == 0
            and number(engine_id, 1) and receipt.get("engine_process_id") == engine_id
            and number(receipt.get("launcher_process_id"), 1)
            and isinstance(observed, list) and all(number(pid, 1) for pid in observed)
            and engine_id in observed and receipt["launcher_process_id"] in observed)


def check_disk(root, identifier, stage, actual_exit, process_id, parent):
    if not safe_id(identifier):
        raise ValueError("unsafe evidence ID")
    folder = root / "build/diagnostics/campaign-goal" / identifier
    report = read_json(folder / "report.json", 32 * 1024 * 1024)
    journal = folder / "campaign.json.journey"
    saved = read_json(journal, 4096)
    log = (folder / "driver.log").read_text(encoding="utf-8-sig")
    bank = current_bank(root)
    errors = validate(report, stage, actual_exit, log, saved, digest(journal), bank)
    if errors:
        raise ValueError("; ".join(errors))
    evidence = report["endless"]
    if not number(process_id, 1) or evidence["process_id"] != process_id:
        raise ValueError("actual launcher process identity")
    if Path(str(journal) + ".tmp").exists() or (folder / "campaign.json").exists():
        raise ValueError("unfinished transaction or synthetic legacy unlock file")
    backup = read_json(Path(str(journal) + ".bak"), 4096)
    if (backup.get("cleared_stage") != stage - 1 or backup.get("coins") != saved["coins"]
            or backup.get("inherited_counts") != evidence["before_state"]["inherited_counts"]
            or backup.get("pending_clear") != dict(loop=evidence["loop"], chapter=report["chapter"],
                                                    coins=saved["coins"], earned_counts=evidence["earned_counts"])):
        raise ValueError("actual pending-reward backup transaction")
    captures = list(report["samples"]) + [evidence["return_capture"]] + report.get("layout_samples", [])
    for capture in captures:
        if capture.get("image_readback") is False:
            if report.get("performance", {}).get("sampled") is not True or "file" in capture:
                raise ValueError("unproven image-readback exclusion")
            continue
        relative = capture["file"].removeprefix("res://")
        path = (root / relative).resolve()
        if not path.is_relative_to(folder.resolve()) or digest(path) != capture["sha256"]:
            raise ValueError("capture path or pixel drift")
    if stage == 1:
        if parent or evidence["parent_report_sha256"] or evidence["parent_saved_sha256"] or evidence["previous_process_id"] != 0:
            raise ValueError("fresh journey has a synthetic predecessor")
    else:
        if not safe_id(parent) or parent == identifier:
            raise ValueError("invalid parent ID")
        previous = folder.parent / parent
        previous_report = read_json(previous / "report.json", 32 * 1024 * 1024)
        receipt = read_json(previous / "exit-report.json")
        if (not valid_process_receipt(receipt, previous_report["endless"]["process_id"])
                or receipt.get("report_sha256") != digest(previous / "report.json")
                or receipt.get("log_sha256") != digest(previous / "driver.log")
                ):
            raise ValueError("unaccepted actual parent exit")
        if (evidence["parent_report_sha256"] != digest(previous / "report.json")
                or evidence["parent_saved_sha256"] != digest(previous / "campaign.json.journey")
                or evidence["before_state"] != read_json(previous / "campaign.json.journey", 4096)
                or evidence["previous_process_id"] != previous_report["endless"]["process_id"]
                or evidence["source_bank"] != previous_report["endless"]["source_bank"]):
            raise ValueError("parent file/state/source linkage drift")
    return report


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", required=True, type=Path)
    parser.add_argument("--id", required=True)
    parser.add_argument("--stage", required=True, type=int)
    parser.add_argument("--actual-exit", required=True, type=int)
    parser.add_argument("--process-id", required=True, type=int)
    parser.add_argument("--parent", default="")
    args = parser.parse_args()
    try:
        report = check_disk(args.root.resolve(), args.id, args.stage, args.actual_exit, args.process_id, args.parent)
    except (OSError, ValueError, TypeError, KeyError, AttributeError) as error:
        print("ENDLESS REPORT FAILED:", error)
        raise SystemExit(1)
    print(f"ENDLESS LEG PASS: stage={args.stage} assertions={report['assertions']}")
