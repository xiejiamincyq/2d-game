from __future__ import annotations

import importlib.util
import tempfile
import unittest
from pathlib import Path

from PIL import Image, ImageDraw


ROOT = Path(__file__).resolve().parents[2]
SCRIPT_PATH = ROOT / "scripts/art/split_player_modeling_sheet.py"


def load_script():
    spec = importlib.util.spec_from_file_location("split_player_modeling_sheet", SCRIPT_PATH)
    assert spec is not None and spec.loader is not None
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


class SplitPlayerModelingSheetTest(unittest.TestCase):
    def test_split_sheet_preserves_three_views_on_square_canvases(self):
        module = load_script()
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source = root / "sheet.png"
            output = root / "views"
            image = Image.new("RGB", (1536, 1024), "white")
            draw = ImageDraw.Draw(image)
            draw.rectangle((120, 80, 550, 950), fill="red")
            draw.rectangle((620, 80, 920, 950), fill="green")
            draw.rectangle((980, 80, 1420, 950), fill="blue")
            image.save(source)

            result = module.split_sheet(source, output)

            self.assertEqual(set(result), {"front", "right", "back"})
            for path in result.values():
                with Image.open(path) as view:
                    self.assertEqual(view.size, (1024, 1024))
                    self.assertEqual(view.mode, "RGBA")
                    self.assertEqual(view.getpixel((0, 0)), (255, 255, 255, 255))
            with Image.open(result["front"]) as front:
                self.assertEqual(front.getpixel((512, 500))[:3], (255, 0, 0))
            with Image.open(result["right"]) as right:
                self.assertEqual(right.getpixel((512, 500))[:3], (0, 128, 0))
                self.assertEqual(right.getpixel((280, 500))[:3], (255, 255, 255))
                self.assertEqual(right.getpixel((750, 500))[:3], (255, 255, 255))
            with Image.open(result["back"]) as back:
                self.assertEqual(back.getpixel((512, 500))[:3], (0, 0, 255))

    def test_split_sheet_rejects_unexpected_source_dimensions(self):
        module = load_script()
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source = root / "sheet.png"
            Image.new("RGB", (1024, 1024), "white").save(source)

            with self.assertRaisesRegex(ValueError, "1536x1024"):
                module.split_sheet(source, root / "views")


if __name__ == "__main__":
    unittest.main()
