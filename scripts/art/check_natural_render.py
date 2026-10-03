"""Native frame capture integrity; not human or performance acceptance."""
import argparse
import hashlib
import json
import math
import re
from pathlib import Path

from check_natural_run_report import check_report, check_log

CLIPS = ("opening", "crowd", "dash", "overlap", "boss", "shop")

def check_metadata(manifest):
    errors = []
    run = manifest.get("run", "")
    clips = manifest.get("clips", {})
    if not re.fullmatch(r"[A-Za-z0-9_-]{1,80}", run) or not clips or set(clips) - set(CLIPS):
        return ["missing/unsafe run or clips"]
    if manifest.get("viewport") != [1280, 720] or manifest.get("display") in (None, "", "headless") or not manifest.get("adapter"):
        errors.append("not native rendering at expected viewport")
    if manifest.get("missing") != [tag for tag in CLIPS if len(clips.get(tag, [])) != 30]:
        errors.append("incorrect six-scene coverage declaration")
    for tag, frames in clips.items():
        if not 1 <= len(frames) <= 30:
            errors.append(f"invalid frame count: {tag}")
            continue
        first = frames[0]
        state = first.get("state")
        overlapping = any(math.dist(a["position"], b["position"]) < a["radius"] + b["radius"]
                          for i, a in enumerate(first.get("warnings", [])) for b in first.get("warnings", [])[:i])
        conditions = {"opening": state == "PLAYING" and first.get("wave") == 1 and first.get("step", 0) >= 30,
                      "crowd": state == "PLAYING" and first.get("visible_live", 0) >= 20,
                      "dash": state == "PLAYING" and first.get("dash") is True,
                      "overlap": state == "PLAYING" and first.get("warning_overlap") is True and overlapping,
                      "boss": state == "PLAYING" and first.get("boss_active") is True,
                      "shop": state == "SETTLEMENT" and first.get("shop_ready") is True}
        if not conditions[tag]:
            errors.append(f"capture started without its condition: {tag}")
        previous = (-1, -1, -1)
        for index, frame in enumerate(frames):
            current = (frame["wall"], frame["frame"], frame["process_frame"])
            if (any(not math.isfinite(v) or v <= p for v, p in zip(current, previous))
                    or frame.get("path") != f"build/diagnostics/natural-run/captures-{run}/{tag}-{index:03}.png"
                    or not re.fullmatch(r"[0-9a-f]{64}", frame.get("sha256", ""))):
                errors.append(f"invalid time/frame/path/hash: {tag}-{index}")
            previous = current
        if len(frames) > 1 and len({frame["sha256"] for frame in frames}) < 2:
            errors.append(f"repeated static image is not motion: {tag}")
    return errors


if __name__ == "__main__":
    from PIL import Image
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("manifest", type=Path)
    parser.add_argument("--report", type=Path, required=True)
    parser.add_argument("--log", type=Path, required=True)
    parser.add_argument("--require-six", action="store_true")
    args = parser.parse_args()
    manifest = json.loads(args.manifest.read_text(encoding="utf-8"))
    report = json.loads(args.report.read_text(encoding="utf-8"))
    errors = check_metadata(manifest) + check_report(report) + check_log(args.log.read_text(encoding="utf-8-sig"), manifest["run"])
    if manifest["run"] != report["config"]["run"] or manifest["source_sha256"] != report["source_sha256"]:
        errors.append("capture/run source binding mismatch")
    if args.require_six and manifest["missing"]:
        errors.append("six natural scene clips not complete")
    project = Path(__file__).resolve().parents[2]
    for relative, expected in manifest["source_sha256"].items():
        path = (project / relative).resolve()
        if not path.is_relative_to(project) or not path.is_file() or hashlib.sha256(path.read_bytes()).hexdigest() != expected:
            errors.append(f"current source mismatch: {relative}")
    for frames in manifest["clips"].values():
        for frame in frames:
            path = (project / frame["path"]).resolve()
            if not path.is_relative_to(project) or not path.is_file() or hashlib.sha256(path.read_bytes()).hexdigest() != frame["sha256"]:
                errors.append(f"image hash/path mismatch: {frame['path']}")
                continue
            with Image.open(path) as image:
                if image.size != (1280, 720) or image.convert("L").getextrema()[0] == image.convert("L").getextrema()[1]:
                    errors.append(f"empty/flat/wrong-sized image: {frame['path']}")
    print(json.dumps({"valid": not errors, "errors": errors, "missing": manifest["missing"], "frames": sum(map(len, manifest["clips"].values())),
                      "scope": "native capture integrity; not paired before/after, performance or human acceptance"}, ensure_ascii=False))
    raise SystemExit(1 if errors else 0)
