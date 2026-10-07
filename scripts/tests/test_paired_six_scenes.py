"""Metadata rejection tests; native image/source verification is a separate gate."""
from copy import deepcopy
import hashlib
import sys
from pathlib import Path
import tempfile
import unittest
from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "art"))
from check_paired_six_scenes import SCENES, validate_pair, verify_native_files


def report(side):
    frames = []
    for scene in SCENES:
        for index in range(30):
            offers = [{"sold": index >= (10 if n == 0 else 20) and n < 2} for n in range(6)]
            condition = {"map_seed": 17, "time_s": index / 15, "player_position": [index, 0],
                         "player_velocity": [100, 0], "aim_angle": (index // 8) * 1.5707963267949,
                         "overdrive": index >= 15, "dash": scene == "dash", "enemy_specs": [],
                         "enemy_hit_requested": scene == "crowd" and 9 <= index < 15,
                         "terrain_obstacle": {"kind": "greenhouse", "position": [500, 500],
                                              "size": [210, 120], "player_walkable": True} if scene == "crowd" and index >= 15 else {},
                         "shop_state": {"families": [{"id": name, "offers": offers[n * 2:n * 2 + 2]}
                                                     for n, name in enumerate(("ballistics", "mobility", "automation"))],
                                        "coins": 80 if index < 20 else 50,
                                        "reward_claimed": index >= 10} if scene == "shop" else {}}
            if scene == "crowd":
                condition["enemy_specs"] = [{"kind": n % 6, "position": [n, n], "velocity": [1, 0]} for n in range(24)]
            frames.append({"scene": scene, "frame": index, "condition": condition,
                           "file": f"{scene}-{index:03}.png", "sha256": "e" * 64,
                           "player_reference_file": f"{scene}-{index:03}.alpha.png",
                           "player_reference_sha256": "f" * 64,
                           "rendered": {"camera_center": [0, 0], "camera_zoom": [1, 1],
                                        "terrain_alpha": 1.0 if index < 15 else 0.32,
                                        "enemy_flash_timers": [0.013] * 24 if 9 <= index < 15 else [0.0] * 24,
                                        "player_screen": [640, 360], "ui_labels": ["actual text"]}})
    return {"schema": "paired-six-scenes-v1", "scope": "controlled-keyframes-not-natural-input",
            "fixture_sha256": "a" * 64, "source_sha256": {"scripts/Main.gd": side * 64},
            "frames": frames}


class NativeFileTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="paired-scenes-test-")
        self.addCleanup(self.temp.cleanup)
        self.directory = Path(self.temp.name)
        self.record = report("b")["frames"][0]
        self.data = {"frames": [self.record]}
        color = Image.new("RGB", (1280, 720), "black")
        color.putpixel((640, 360), (255, 255, 255))
        reference = Image.new("RGBA", (1280, 720), (0, 0, 0, 0))
        reference.putpixel((640, 360), (35, 184, 172, 255))
        self.save(color, "file", "sha256")
        self.save(reference, "player_reference_file", "player_reference_sha256")

    def save(self, image, name_key, hash_key):
        path = self.directory / self.record[name_key]
        image.save(path)
        self.record[hash_key] = hashlib.sha256(path.read_bytes()).hexdigest()

    def test_bound_native_bytes_accepted(self):
        verify_native_files(self.data, self.directory)

    def test_wrong_hash_rejected(self):
        self.record["sha256"] = "0" * 64
        with self.assertRaises(ValueError):
            verify_native_files(self.data, self.directory)

    def test_outside_path_rejected_before_reading(self):
        self.record["file"] = "../outside.png"
        with self.assertRaises(ValueError):
            verify_native_files(self.data, self.directory)

    def test_wrong_native_dimensions_rejected(self):
        self.save(Image.new("RGB", (640, 360)), "file", "sha256")
        with self.assertRaises(ValueError):
            verify_native_files(self.data, self.directory)

    def test_blank_scene_rejected(self):
        self.save(Image.new("RGB", (1280, 720)), "file", "sha256")
        with self.assertRaises(ValueError):
            verify_native_files(self.data, self.directory)

    def test_empty_alpha_reference_rejected(self):
        self.save(Image.new("RGBA", (1280, 720)), "player_reference_file", "player_reference_sha256")
        with self.assertRaises(ValueError):
            verify_native_files(self.data, self.directory)


class PairedScenesTest(unittest.TestCase):
    def setUp(self):
        self.before, self.after = report("b"), report("c")
        self.sources = deepcopy({"before": self.before["source_sha256"], "after": self.after["source_sha256"]})

    def reject(self, mutate):
        mutate(self.after)
        with self.assertRaises(ValueError):
            validate_pair(self.before, self.after, self.sources)

    def test_same_inputs_allow_different_camera_and_ui_outputs(self):
        self.after["frames"][0]["rendered"]["camera_center"] = [10, -20]
        self.after["frames"][0]["rendered"]["ui_labels"] = ["new theme text"]
        self.assertEqual(validate_pair(self.before, self.after, self.sources)["paired_frames"], 180)

    def test_missing_frame_rejected(self):
        self.reject(lambda r: r["frames"].pop())

    def test_duplicate_frame_rejected(self):
        self.reject(lambda r: r["frames"].__setitem__(1, deepcopy(r["frames"][0])))

    def test_different_world_pose_rejected(self):
        self.reject(lambda r: r["frames"][0]["condition"].__setitem__("player_position", [999, 0]))

    def test_empty_conditions_rejected(self):
        self.reject(lambda r: r["frames"][0].__setitem__("condition", {}))

    def test_wrong_source_binding_rejected(self):
        self.reject(lambda r: r["source_sha256"].__setitem__("scripts/Main.gd", "d" * 64))

    def test_changed_fixture_rejected(self):
        self.reject(lambda r: r.__setitem__("fixture_sha256", "d" * 64))

    def test_bad_sample_time_rejected(self):
        self.reject(lambda r: r["frames"][0]["condition"].__setitem__("time_s", 3.0))

    def test_missing_native_reference_rejected(self):
        self.reject(lambda r: r["frames"][0].pop("player_reference_sha256"))

    def test_missing_real_shop_card_rejected(self):
        self.reject(lambda r: r["frames"][150]["condition"]["shop_state"]["families"][0]["offers"].pop())

    def test_crowd_without_actual_terrain_rejected(self):
        for record in self.before["frames"] + self.after["frames"]:
            record["condition"]["terrain_obstacle"] = {}
        with self.assertRaises(ValueError):
            validate_pair(self.before, self.after, self.sources)

    def test_crowd_without_continuous_hit_segment_rejected(self):
        for record in self.before["frames"] + self.after["frames"]:
            record["condition"]["enemy_hit_requested"] = False
        with self.assertRaises(ValueError):
            validate_pair(self.before, self.after, self.sources)

    def test_missing_four_cardinal_views_rejected(self):
        for record in self.before["frames"] + self.after["frames"]:
            record["condition"]["aim_angle"] = 0
        with self.assertRaises(ValueError):
            validate_pair(self.before, self.after, self.sources)


if __name__ == "__main__":
    unittest.main()
