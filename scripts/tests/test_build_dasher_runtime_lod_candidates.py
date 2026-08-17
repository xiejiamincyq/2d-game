from __future__ import annotations

import importlib.util
import sys
import tempfile
import unittest
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[2]
SCRIPT_PATH = ROOT / "scripts/art/build_dasher_runtime_lod_candidates.py"


def load_script():
    sys.path.insert(0, str(SCRIPT_PATH.parent))
    try:
        spec = importlib.util.spec_from_file_location(
            "build_dasher_runtime_lod_candidates",
            SCRIPT_PATH,
        )
        assert spec is not None and spec.loader is not None
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        return module
    finally:
        sys.path.pop(0)


class BuildDasherRuntimeLodCandidatesTest(unittest.TestCase):
    def test_builds_valid_128_pixel_candidate_without_touching_runtime_asset(self):
        module = load_script()
        with tempfile.TemporaryDirectory() as temporary_directory:
            output = module.build_candidate("a", 128, Path(temporary_directory))
            with Image.open(output) as image:
                self.assertEqual(image.mode, "RGBA")
                self.assertEqual(image.size, (384, 256))
                self.assertEqual(image.getchannel("A").getextrema(), (0, 255))


if __name__ == "__main__":
    unittest.main()
