"""Strict controlled-display pairing, not a natural-input or visual approval gate."""
import hashlib
import math
from pathlib import Path
import re

from PIL import Image

SCENES = ("opening", "crowd", "dash", "overlap", "boss", "shop")
CONDITIONS = {"map_seed", "time_s", "player_position", "player_velocity", "aim_angle",
              "overdrive", "dash", "enemy_specs", "shop_state"}


def require(value, message):
    if not value:
        raise ValueError(message)


def sha256(value):
    return isinstance(value, str) and re.fullmatch(r"[0-9a-f]{64}", value) is not None


def validate_pair(before, after, expected_sources):
    indexed = {}
    for side, report in (("before", before), ("after", after)):
        require(report.get("schema") == "paired-six-scenes-v1", "Unknown schema")
        require(report.get("scope") == "controlled-keyframes-not-natural-input", "Wrong scope")
        require(report.get("source_sha256") == expected_sources[side] and expected_sources[side], "Source mismatch")
        require(all(sha256(h) for h in expected_sources[side].values()), "Invalid source SHA256")
        require(sha256(report.get("fixture_sha256")), "Invalid fixture hash")
        records = report.get("frames", [])
        require(len(records) == 180, "Need all six 30-frame scenes")
        frames = {}
        for record in records:
            scene, frame = record.get("scene"), record.get("frame")
            require(scene in SCENES and type(frame) is int and 0 <= frame < 30, "Bad scene/frame")
            key = scene, frame
            require(key not in frames, "Duplicate scene/frame")
            condition = record.get("condition", {})
            require(isinstance(condition, dict) and CONDITIONS <= condition.keys(), "Missing conditions")
            require(math.isfinite(condition["time_s"]) and abs(condition["time_s"] - frame / 15) < 1e-6, "Bad sample time")
            require(math.isfinite(condition["aim_angle"]), "Non-finite aim")
            require(type(condition["overdrive"]) is bool and type(condition["dash"]) is bool, "Wrong input flags")
            for field in ("player_position", "player_velocity"):
                require(len(condition[field]) == 2 and all(math.isfinite(n) for n in condition[field]), "Bad actor vector")
            require(isinstance(condition["enemy_specs"], list), "Missing enemy specifications")
            require(record.get("file") == f"{scene}-{frame:03}.png" and sha256(record.get("sha256")), "Bad native image binding")
            require(record.get("player_reference_file") == f"{scene}-{frame:03}.alpha.png"
                    and sha256(record.get("player_reference_sha256")), "Missing native Player reference")
            rendered = record.get("rendered", {})
            require(all(k in rendered for k in ("camera_center", "camera_zoom", "player_screen", "ui_labels")), "Missing rendered state")
            require(rendered["ui_labels"], "No real UI text observed")
            frames[key] = record
        require(set(frames) == {(s, n) for s in SCENES for n in range(30)}, "Incomplete scenes")
        dash = [frames["dash", n]["condition"] for n in range(30)]
        require(len({round(c["aim_angle"], 5) for c in dash}) == 4, "Four cardinal views missing")
        require({c["overdrive"] for c in dash} == {False, True}, "Both overdrive states required")
        require(all(len(frames["crowd", n]["condition"]["enemy_specs"]) == 24 for n in range(30)), "Crowd count differs")
        for n in range(9, 15):
            r = frames["crowd", n]
            require(r["condition"].get("enemy_hit_requested") is True, "Continuous crowd hits missing")
            timers = r["rendered"].get("enemy_flash_timers", [])
            require(len(timers) == 24 and all(0 < t < 0.08 for t in timers), "Real continuous flash timers missing")
        for n in range(15, 30):
            r = frames["crowd", n]
            terrain = r["condition"].get("terrain_obstacle", {})
            require(terrain.get("kind") == "greenhouse" and terrain.get("player_walkable") is True
                    and len(terrain.get("position", [])) == 2 and len(terrain.get("size", [])) == 2,
                    "Real foreground terrain missing")
            alpha = r["rendered"].get("terrain_alpha", 1.0)
            require(math.isfinite(alpha) and 0.31 <= alpha < 1.0, "Terrain fade not observed")
        shop = [frames["shop", n]["condition"]["shop_state"] for n in range(30)]
        for state in shop:
            families = state.get("families", [])
            require(len(families) == 3 and {f.get("id") for f in families}
                    == {"ballistics", "mobility", "automation"}, "Three real shop families required")
            require(all(len(f.get("offers", [])) == 2 for f in families), "Six real shop cards required")
        require(not shop[0].get("reward_claimed") and shop[10].get("reward_claimed"), "Free-claim states missing")
        require(shop[20]["coins"] < shop[10]["coins"], "Paid purchase state missing")
        indexed[side] = frames
    require(before["fixture_sha256"] == after["fixture_sha256"], "Fixture differs")
    for key, record in indexed["before"].items():
        require(record["condition"] == indexed["after"][key]["condition"], f"Different world/input conditions: {key}")
    return {"paired_frames": 180, "native_color_images": 360, "scope": "controlled display metadata only"}


def verify_native_files(report, directory):
    """Inspect actual PNG bytes; paths must stay inside this single run directory."""
    directory = Path(directory).resolve()
    for record in report["frames"]:
        for name_key, hash_key in (("file", "sha256"), ("player_reference_file", "player_reference_sha256")):
            path = (directory / record[name_key]).resolve()
            require(path.parent == directory, "Image outside the run")
            require(hashlib.sha256(path.read_bytes()).hexdigest() == record[hash_key], "PNG hash mismatch")
            with Image.open(path) as image:
                require(image.format == "PNG" and image.size == (1280, 720), "Wrong native PNG dimensions")
                image.load()
                if name_key == "file":
                    extrema = image.convert("RGB").getextrema()
                    require(any(high - low > 24 for low, high in extrema), "Blank native scene")
                else:
                    require(image.mode == "RGBA" and image.getchannel("A").getbbox() is not None, "Empty Player reference")
