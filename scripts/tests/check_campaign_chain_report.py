"""Read-only independent acceptance of one actual sequential campaign leg."""
import argparse
import hashlib
import json
import math
from pathlib import Path
import re

MARKERS = [f"Verify{name}ChapterFlow" for name in ("Nursery", "Foundry", "Salt", "Archive", "Echo", "Rift")]
FORBIDDEN = r"SCRIPT ERROR|ERROR:|TEST FAIL:|ObjectDB instances were leaked|RID.+leaked|resources still in use"


def number(value, minimum=0):
    return type(value) in (int, float) and math.isfinite(value) and value == math.floor(value) and value >= minimum


def sha(value):
    return isinstance(value, str) and re.fullmatch(r"[a-f0-9]{64}", value) is not None


def state(value, count):
    return (isinstance(value, dict) and set(value) == {"version", "cleared_chapters"}
            and number(value["version"], 1) and value["version"] == 1
            and isinstance(value["cleared_chapters"], list) and len(value["cleared_chapters"]) == count
            and all(number(v, 1) and v == n + 1 for n, v in enumerate(value["cleared_chapters"])))


def validate(report, chapter, actual_exit, log, saved_state, saved_sha, bank):
    errors = []
    def require(ok, label):
        if not ok: errors.append(label)
    if not isinstance(report, dict) or not number(chapter, 1) or chapter > 6:
        return ["invalid report/chapter"]
    require(number(actual_exit) and actual_exit == 0, "actual process exit")
    require(isinstance(log, str) and re.search(FORBIDDEN, log) is None, "error/leak log")
    matches = re.findall(rf"(?m)^TEST PASS: {MARKERS[chapter - 1]} ([1-9][0-9]*)\r?$", log)
    require(len(matches) == 1 and number(report.get("assertions"), 1) and int(matches[0]) == report["assertions"], "unique positive terminal PASS")
    require(report.get("valid") is True and number(report.get("chapter"), 1) and report["chapter"] == chapter, "valid actual chapter")
    require(number(report.get("moves"), 501) and number(report.get("shots"), 51), "ordinary movement/fire")
    require(report.get("prerequisite_fixture") == [], "no preseed fixture")
    chain = report.get("chain")
    if not isinstance(chain, dict): return errors + ["missing chain"]
    require(number(chain.get("schema"), 1) and chain["schema"] == 1, "chain schema")
    require(chain.get("enabled") is True and chain.get("used_preseed") is False and chain.get("returned_to_main") is True, "ordinary return provenance")
    require(number(chain.get("process_id"), 1) and number(chain.get("previous_process_id")) and chain["process_id"] != chain["previous_process_id"], "different engine process")
    require(number(chain.get("defeated_boss_instance"), 1) and number(chain.get("expected_kills"), 1), "true Boss and kill debt")
    samples = report.get("samples")
    last = samples[-1] if isinstance(samples, list) and samples and isinstance(samples[-1], dict) else {}
    require(last.get("state") == "CLEARED" and number(last.get("kills"), 1) and number(chain.get("expected_kills"), 1) and last["kills"] >= chain["expected_kills"], "actual terminal saved victory")
    require(state(saved_state, chapter) and state(chain.get("saved_state"), chapter) and chain["saved_state"] == saved_state, "exact sequential saved clears")
    require(state(chain.get("before_state"), chapter - 1), "sequential predecessor")
    require(sha(saved_sha) and chain.get("saved_sha256") == saved_sha, "actual save SHA")
    require(isinstance(bank, dict) and bool(bank) and all(sha(v) for v in bank.values()) and chain.get("source_bank") == bank, "frozen source bank")
    if chapter == 1:
        require(chain.get("parent_report_sha256") == "" and chain.get("parent_saved_sha256") == "" and chain.get("previous_process_id") == 0, "actual fresh first stage")
    else:
        require(sha(chain.get("parent_report_sha256")) and sha(chain.get("parent_saved_sha256")) and number(chain.get("previous_process_id"), 1), "parent SHA linkage")
    require(number(chain.get("next_entry_chapter"), 1) and chain["next_entry_chapter"] == min(chapter + 1, 6), "restored formal next entry")
    capture = chain.get("return_capture")
    require(isinstance(capture, dict) and isinstance(capture.get("file"), str) and sha(capture.get("sha256")), "actual return capture")
    return errors


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def read_json(path, maximum=4 * 1024 * 1024):
    if path.stat().st_size > maximum: raise ValueError("bounded evidence size exceeded")
    return json.loads(path.read_text(encoding="utf-8-sig"))


def safe_source(path):
    return (isinstance(path, str) and ".." not in path and ":" not in path and "\\" not in path
            and not path.startswith("/") and
            ((path.startswith(("scripts/", "scenes/", "assets/art/actors/native/", "assets/art/shaders/"))
              and Path(path).suffix in (".gd", ".gdshader", ".tscn", ".tres", ".uid"))
             or path in ("project.godot", "export_presets.cfg", "assets/audio/overdrive_bone_breaking.mp3",
                         "scripts/tests/run_tests.ps1", "scripts/tests/run_campaign_chain.ps1",
                         "scripts/tests/check_campaign_chain_report.py")))


def check_disk(root, identifier, chapter, actual_exit, parent):
    if not re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]{0,79}", identifier): raise ValueError("unsafe evidence ID")
    folder = root / "build/diagnostics/campaign-goal" / identifier
    report = read_json(folder / "report.json")
    campaign = folder / "campaign.json"
    bank = report.get("chain", {}).get("source_bank", {})
    for source, expected in bank.items():
        if not safe_source(source): raise ValueError("unrelated source path")
        path = (root / source).resolve()
        if not path.is_relative_to(root) or digest(path) != expected: raise ValueError("current source drift: " + source)
    log_path = folder / "driver.log"
    if log_path.stat().st_size > 4 * 1024 * 1024: raise ValueError("oversized process log")
    errors = validate(report, chapter, actual_exit, log_path.read_text(encoding="utf-8-sig"), read_json(campaign, 4096), digest(campaign), bank)
    if errors: raise ValueError("; ".join(errors))
    chain = report["chain"]
    expected_capture = f"build/diagnostics/campaign-goal/{identifier}/returned_main.png"
    if chain["return_capture"]["file"] != expected_capture or digest(root / expected_capture) != chain["return_capture"]["sha256"]:
        raise ValueError("return capture drift")
    if Path(str(campaign) + ".tmp").exists(): raise ValueError("unfinished transaction")
    backup = Path(str(campaign) + ".bak")
    if chapter == 1:
        if parent or backup.exists(): raise ValueError("fresh stage acquired a predecessor")
    else:
        if not parent or parent == identifier or not re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]{0,79}", parent): raise ValueError("invalid parent ID")
        previous = folder.parent / parent
        parent_report = read_json(previous / "report.json")
        parent_receipt = read_json(previous / "exit-report.json")
        if (parent_receipt.get("actual_exit") != 0 or parent_receipt.get("report_sha256") != digest(previous / "report.json")
                or parent_receipt.get("log_sha256") != digest(previous / "driver.log")): raise ValueError("unaccepted parent exit ledger")
        if (chain["parent_report_sha256"] != digest(previous / "report.json")
                or chain["parent_saved_sha256"] != digest(previous / "campaign.json")
                or chain["previous_process_id"] != parent_report["chain"]["process_id"]
                or chain["source_bank"] != parent_report["chain"]["source_bank"]
                or chain["before_state"] != read_json(previous / "campaign.json", 4096)): raise ValueError("parent linkage drift")
        if digest(backup) != chain["parent_saved_sha256"] or read_json(backup, 4096) != chain["before_state"]: raise ValueError("committed backup drift")
    return report


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", required=True, type=Path)
    parser.add_argument("--id", required=True)
    parser.add_argument("--chapter", required=True, type=int)
    parser.add_argument("--actual-exit", required=True, type=int)
    parser.add_argument("--parent", default="")
    args = parser.parse_args()
    try:
        result = check_disk(args.root.resolve(), args.id, args.chapter, args.actual_exit, args.parent)
    except (OSError, ValueError, TypeError, KeyError, AttributeError) as error:
        print("CHAIN REPORT FAILED:", error)
        raise SystemExit(1)
    print(f"CHAIN LEG PASS: chapter={args.chapter} assertions={result['assertions']}")
