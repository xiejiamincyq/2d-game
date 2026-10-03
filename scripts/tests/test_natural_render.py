from pathlib import Path
import sys
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "art"))
from check_natural_render import check_metadata, CLIPS


def fixture():
    frames = [{"state": "PLAYING", "wave": 1, "step": 30 + i * 4, "visible_live": 0,
               "dash": False, "warning_overlap": False, "warnings": [], "boss_active": False,
               "shop_ready": False, "wall": 2 + i / 15, "frame": 120 + i * 4, "process_frame": 100 + i * 4,
               "sha256": f"{i:064x}", "path": f"build/diagnostics/natural-run/captures-fixture/opening-{i:03}.png"}
              for i in range(30)]
    return {"run": "fixture", "viewport": [1280, 720], "display": "Windows", "adapter": "synthetic unit fixture",
            "clips": {"opening": frames}, "missing": list(CLIPS[1:])}

def fixture_for(tag, **conditions):
    report = fixture()
    frames = report["clips"].pop("opening")
    report["clips"][tag] = frames
    frames[0].update(conditions)
    for index, frame in enumerate(frames):
        frame["path"] = f"build/diagnostics/natural-run/captures-fixture/{tag}-{index:03}.png"
    report["missing"] = [name for name in CLIPS if name != tag]
    return report


class NaturalRenderTest(unittest.TestCase):
    def test_truthfully_partial_capture_is_not_six_scene_approval(self):
        self.assertEqual([], check_metadata(fixture()))

    def test_each_nonopening_condition_is_required(self):
        for tag, key, value in [("crowd", "visible_live", 20), ("dash", "dash", True), ("boss", "boss_active", True), ("shop", "shop_ready", True)]:
            report = fixture_for(tag, **{key: value})
            if tag == "shop":
                report["clips"][tag][0]["state"] = "SETTLEMENT"
            self.assertEqual([], check_metadata(report), tag)
            report["clips"][tag][0][key] = 0 if tag == "crowd" else False
            self.assertTrue(check_metadata(report), tag)

    def test_overlap_requires_actual_intersecting_warning_circles(self):
        report = fixture_for("overlap", warning_overlap=True, warnings=[{"position": [0, 0], "radius": 72}, {"position": [100, 0], "radius": 72}])
        self.assertEqual([], check_metadata(report))
        report["clips"]["overlap"][0]["warnings"][1]["position"] = [1000, 0]
        self.assertTrue(check_metadata(report))

    def test_truthful_truncation_remains_missing_not_fake_success(self):
        report = fixture()
        report["clips"]["opening"].pop()
        report["missing"] = list(CLIPS)
        self.assertEqual([], check_metadata(report))

    def test_reject_false_coverage_or_truncation(self):
        for missing in [[], list(CLIPS)]:
            report = fixture()
            report["missing"] = missing
            self.assertTrue(check_metadata(report))
        report = fixture()
        report["clips"]["opening"].pop()
        self.assertTrue(check_metadata(report))

    def test_reject_invented_opening_condition(self):
        report = fixture()
        report["clips"]["opening"][0]["state"] = "PAUSED"
        self.assertTrue(check_metadata(report))

    def test_reject_backward_time_frame_or_unsafe_path(self):
        for key, value in [("wall", 0), ("frame", 1), ("process_frame", 1), ("path", "../../user-save.json")]:
            report = fixture()
            report["clips"]["opening"][1][key] = value
            self.assertTrue(check_metadata(report))

    def test_reject_headless_or_repeated_static_images(self):
        report = fixture()
        report["display"] = "headless"
        self.assertTrue(check_metadata(report))
        report = fixture()
        for frame in report["clips"]["opening"]:
            frame["sha256"] = "a" * 64
        self.assertTrue(check_metadata(report))


if __name__ == "__main__":
    unittest.main()
