"""Native frame capture integrity; not human or performance acceptance."""
import argparse
import hashlib
import json
import math
import re
from pathlib import Path

from check_natural_run_report import check_report, check_log

CLIPS = ("opening", "crowd", "dash", "overlap", "boss", "shop")

def finite_number(value):
    return type(value) in (int, float) and math.isfinite(value)


def valid_rect(rect):
    return (isinstance(rect, list) and len(rect) == 4
            and all(finite_number(v) for v in rect) and rect[2] > 0 and rect[3] > 0)


def check_collection_metadata(manifest):
    errors = []
    collection = manifest.get('collection', {})
    start, end, frames = (collection.get(k, {}) for k in ('start', 'end', 'frames'))
    if not start or not end or not collection.get('complete') or not isinstance(frames, list) or not 40 <= len(frames) <= 128:
        return ['missing or truncated collection window']
    if start.get('duration') != 3.0 or end.get('remaining') != 0.0 or start.get('wave') != end.get('wave'):
        errors.append('wrong collection lifecycle')
    start_wall, end_wall = start.get('wall', float('nan')), end.get('wall', float('nan'))
    if not finite_number(start_wall) or not finite_number(end_wall):
        return ['invalid whole-window wall duration']
    if not 2.8 <= end_wall - start_wall <= 3.5:
        errors.append('invalid whole-window wall duration')
    first_wall, first_remaining = frames[0].get('wall'), frames[0].get('remaining')
    last_wall = frames[-1].get('wall')
    if not finite_number(first_wall) or not finite_number(first_remaining) or not 0 <= first_wall - start_wall <= .15 or first_remaining < 2.8:
        errors.append('missing collection opening')
    if not finite_number(last_wall) or not 0 <= last_wall - end_wall <= .25 or frames[-1].get('remaining') != 0.0 or frames[-1].get('visible') is not False:
        errors.append('missing hidden collection tail')
    previous = None
    for index, row in enumerate(frames):
        wall, remaining = row.get('wall', float('nan')), row.get('remaining', float('nan'))
        if not finite_number(wall) or not finite_number(remaining) or not 0 <= remaining <= 3.0:
            errors.append('invalid collection numeric sample')
            continue
        if any(type(row.get(key)) is not int or row[key] < 0 for key in ('frame', 'process_frame')):
            errors.append('invalid collection frame number')
            continue
        hidden_tail = index == len(frames) - 1 and remaining == 0.0 and row.get('visible') is False
        minimum_step = 0 if hidden_tail else 3
        if previous and (not 0 < wall - previous['wall'] <= .2 or row['process_frame'] <= previous['process_frame'] or row['frame'] - previous['frame'] < minimum_step or remaining > previous['remaining'] + 1e-6):
            errors.append('invalid collection cadence or monotonic counter')
        last = index == len(frames) - 1
        expected_state = 'WAVE_CLEAR' if last else 'PLAYING'
        if (row.get('state') != expected_state or row.get('visible') is not (not last)
                or (remaining != 0.0 if last else remaining <= 0.0)):
            errors.append('collection state/visibility mismatch')
        # Real HUD ProgressBar inherits Range's default 0.01 step; it is not a raw float mirror.
        expected_bar = math.floor(remaining / .01 + .5) * .01
        if (row.get('bar_max') != 3.0 or not finite_number(row.get('bar_value')) or not math.isclose(row['bar_value'], expected_bar, abs_tol=1e-5)
                or row.get('label') != f'倒计时：{remaining:.1f}s'
                or not finite_number(row.get('alpha')) or not math.isclose(row['alpha'], min(1.0, remaining/.35), abs_tol=1e-5)):
            errors.append('collection UI differs from real counter')
        rect = row.get('rect', [])
        other = row.get('overdrive_rect', [])
        if not valid_rect(other):
            errors.append('invalid overdrive rectangle')
        # Hidden tail remains a valid node rectangle, but no visible-panel bottom margin is required.
        bottom_limit = 702.01 if row.get('visible') else 720.01
        if not valid_rect(rect) or rect[0] < 0 or rect[1] < 0 or rect[0]+rect[2] > 1280.01 or rect[1]+rect[3] > bottom_limit:
            errors.append('collection outside viewport/margin')
        elif row.get('visible') and row.get('overdrive_visible') and valid_rect(other):
            if (min(rect[0]+rect[2],other[0]+other[2]) > max(rect[0],other[0]) and min(rect[1]+rect[3],other[1]+other[3]) > max(rect[1],other[1])):
                errors.append('collection and overdrive overlap')
        if row.get('path') != f"build/diagnostics/natural-run/captures-{manifest.get('run')}/collection-{index:03}.png" or not re.fullmatch(r'[0-9a-f]{64}', row.get('sha256', '')):
            errors.append('invalid collection path/hash')
        previous = row
    if len({row.get('sha256') for row in frames}) < 2:
        errors.append('static collection images')
    return errors


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
    parser.add_argument("--require-collection", action="store_true")
    args = parser.parse_args()
    manifest = json.loads(args.manifest.read_text(encoding="utf-8"))
    report = json.loads(args.report.read_text(encoding="utf-8"))
    errors = check_metadata(manifest) + check_report(report) + check_log(args.log.read_text(encoding="utf-8-sig"), manifest["run"])
    if manifest["run"] != report["config"]["run"] or manifest["source_sha256"] != report["source_sha256"]:
        errors.append("capture/run source binding mismatch")
    if args.require_six and manifest["missing"]:
        errors.append("six natural scene clips not complete")
    if args.require_collection:
        errors += check_collection_metadata(manifest)
    project = Path(__file__).resolve().parents[2]
    for relative, expected in manifest["source_sha256"].items():
        path = (project / relative).resolve()
        if not path.is_relative_to(project) or not path.is_file() or hashlib.sha256(path.read_bytes()).hexdigest() != expected:
            errors.append(f"current source mismatch: {relative}")
    image_groups = list(manifest["clips"].values())
    if args.require_collection:
        image_groups.append(manifest.get('collection', {}).get('frames', []))
    for frames in image_groups:
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
