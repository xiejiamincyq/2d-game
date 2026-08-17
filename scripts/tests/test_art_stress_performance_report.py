import json
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
REPORT_PATH = ROOT / "docs/art/reviews/art-stress-performance-v1.json"


class ArtStressPerformanceReportTests(unittest.TestCase):
    def test_real_gpu_report_is_complete_and_nonzero(self) -> None:
        report = json.loads(REPORT_PATH.read_text(encoding="utf-8"))

        self.assertEqual(report["schema_version"], 1)
        self.assertEqual(report["fixture"], "high-density-art-stress-v1")
        self.assertEqual(report["viewport"], {"width": 1536, "height": 900})
        self.assertGreaterEqual(report["warmup_frames"], 120)
        self.assertGreaterEqual(report["sample_frames"], 180)

        process = report["process_msec"]
        self.assertGreater(process["average"], 0.0)
        self.assertLessEqual(process["average"], process["maximum"])
        self.assertLessEqual(process["p95"], process["maximum"])

        draw_calls = report["render_draw_calls"]
        self.assertGreater(draw_calls["average"], 0.0)
        self.assertLessEqual(draw_calls["average"], draw_calls["maximum"])
        self.assertGreater(report["render_objects"]["maximum"], 0)
        self.assertGreater(report["render_texture_memory_bytes"], 0)
        self.assertGreater(report["render_video_memory_bytes"], 0)
        self.assertGreater(report["node_count"], 0)
        self.assertTrue(report["rendering_device"].strip())
        self.assertIn("single-machine", report["interpretation"])


if __name__ == "__main__":
    unittest.main()
