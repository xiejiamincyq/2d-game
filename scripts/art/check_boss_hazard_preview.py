"""Read-only checks for the fixed-component Boss hazard before/after evidence."""
import argparse
import hashlib
import json
from pathlib import Path

from PIL import Image


def check(directory: Path, project: Path) -> dict:
    before = json.loads((directory / "before.json").read_text(encoding="utf-8"))
    after = json.loads((directory / "after.json").read_text(encoding="utf-8"))
    errors = []
    first, second = before["poses"], after["poses"]
    differences = [index for index, (a, b) in enumerate(zip(first, second)) if a != b]
    if len(first) != 360 or len(second) != 360 or differences:
        errors.append("360-frame mechanical signatures differ")
    for report in (before, after):
        if not report["screenshot_ok"] or not report["owned_nodes_freed"] or report["orphan_after"] != 0:
            errors.append("capture or node cleanup failed")
    capture_script = "scripts/art/VerifyBossHazards.gd"
    if before["source_sha256"][capture_script] != after["source_sha256"][capture_script]:
        errors.append("before and after used different capture scripts")
    for path, digest in after["source_sha256"].items():
        if hashlib.sha256((project / path).read_bytes()).hexdigest() != digest:
            errors.append("current source differs from final capture: " + path)
    for key, damage in (("target_hits", 18.0), ("offset_hits", 18.0), ("slam_hits", 20.0)):
        if second[-1][key] != [damage] * 3:
            errors.append("fixture did not resolve the expected three cycles: " + key)
    atlas = Image.open(project / "assets/art/actors/player/player_chibi_b_cardinal_atlas_v1.png").convert("RGBA")
    pictures = {name: Image.open(directory / (name + ".png")).convert("RGB")
                for name in ("before", "after", "before-projectiles", "after-projectiles")}
    # Frame-30 warning vs frame-85 unfilled view, same static native-scale body.
    # Exclude source alpha edges plus their neighbors: antialiasing blends those with the ground.
    interior = [(298 + x, 198 + y) for y in range(63) for x in range(63)
                if all(atlas.getpixel((2 * x + dx, 2 * y + dy))[3] == 255
                       for dx in (0, 1, 2) for dy in (0, 1, 2))]
    old_tinted = sum(pictures["before"].getpixel(p) != pictures["before-projectiles"].getpixel(p) for p in interior)
    new_tinted = sum(pictures["after"].getpixel(p) != pictures["after-projectiles"].getpixel(p) for p in interior)
    if len(interior) < 200 or old_tinted != len(interior) or new_tinted != 0:
        errors.append("opaque interior warning-fill comparison failed")
    inputs = [directory / name for name in ("before.json", "after.json", "before.png", "after.png", "before-projectiles.png", "after-projectiles.png")]
    return {"valid": not errors, "errors": errors, "acceptance": "component_visual_evidence_only",
            "pose_count": len(second), "mechanical_differences": len(differences),
            "opaque_interior_samples": len(interior), "before_tinted_samples": old_tinted,
            "after_tinted_samples": new_tinted,
            "sha256": {path.name: hashlib.sha256(path.read_bytes()).hexdigest() for path in inputs},
            "limitations": "Fixed component fixture only. Interior sample mask excludes antialiased edges; not a claim that every body pixel is opaque or that a full natural Boss fight passed."}


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("directory", type=Path)
    args = parser.parse_args()
    result = check(args.directory, Path(__file__).resolve().parents[2])
    print(json.dumps(result, ensure_ascii=False))
    raise SystemExit(0 if result["valid"] else 2)
