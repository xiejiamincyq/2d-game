from __future__ import annotations

import importlib.util
import unittest
from pathlib import Path

from PIL import Image, ImageDraw


ROOT = Path(__file__).resolve().parents[2]
SCRIPT_PATH = ROOT / "scripts/art/remove_connected_light_background.py"


def load_script():
    spec = importlib.util.spec_from_file_location("remove_connected_light_background", SCRIPT_PATH)
    assert spec is not None and spec.loader is not None
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


class RemoveConnectedLightBackgroundTest(unittest.TestCase):
    def test_removes_edge_connected_checker_but_preserves_enclosed_white_detail(self):
        module = load_script()
        image = Image.new("RGB", (24, 24), (248, 248, 248))
        draw = ImageDraw.Draw(image)
        for y in range(0, 24, 4):
            for x in range(0, 24, 4):
                if (x + y) // 4 % 2:
                    draw.rectangle((x, y, x + 3, y + 3), fill=(238, 238, 238))
        draw.rectangle((6, 6, 17, 17), fill=(20, 24, 30))
        draw.rectangle((9, 9, 14, 14), fill=(250, 250, 250))

        result = module.remove_connected_background(image)

        self.assertEqual(result.getpixel((0, 0))[3], 0)
        self.assertEqual(result.getpixel((4, 0))[3], 0)
        self.assertEqual(result.getpixel((7, 7))[3], 255)
        self.assertEqual(result.getpixel((11, 11))[3], 255)

    def test_validate_sheet_rejects_empty_cell(self):
        module = load_script()
        image = Image.new("RGBA", (30, 20), (0, 0, 0, 0))
        draw = ImageDraw.Draw(image)
        for row in range(2):
            for column in range(3):
                if (column, row) != (2, 1):
                    draw.rectangle(
                        (column * 10 + 2, row * 10 + 2, column * 10 + 7, row * 10 + 7),
                        fill=(30, 40, 50, 255),
                    )
        with self.assertRaisesRegex(RuntimeError, "2,1"):
            module.validate_sheet(image, 3, 2)


if __name__ == "__main__":
    unittest.main()
