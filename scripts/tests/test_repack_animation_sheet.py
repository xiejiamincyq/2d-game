from __future__ import annotations

import importlib.util
import unittest
from pathlib import Path

from PIL import Image, ImageDraw


ROOT = Path(__file__).resolve().parents[2]
SCRIPT_PATH = ROOT / "scripts/art/repack_animation_sheet.py"


def load_script():
    spec = importlib.util.spec_from_file_location("repack_animation_sheet", SCRIPT_PATH)
    assert spec is not None and spec.loader is not None
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


class RepackAnimationSheetTest(unittest.TestCase):
    def test_repack_orders_components_and_keeps_safe_padding(self):
        module = load_script()
        image = Image.new("RGBA", (300, 200), (0, 0, 0, 0))
        draw = ImageDraw.Draw(image)
        colors = []
        for row in range(2):
            for column in range(3):
                color = (30 + column * 40, 50 + row * 80, 100, 255)
                colors.append(color)
                x = column * 100 + (0 if (row, column) == (1, 1) else 20)
                y = row * 100 + 20
                draw.rectangle((x, y, x + 70, y + 50), fill=color)

        result = module.repack_sheet(image, cell_size=128, padding=16)
        module.validate_repacked_sheet(result, cell_size=128, padding=12)

        for index, color in enumerate(colors):
            center = (index % 3 * 128 + 64, index // 3 * 128 + 64)
            self.assertEqual(result.getpixel(center), color)

    def test_requires_exactly_six_large_components(self):
        module = load_script()
        image = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
        ImageDraw.Draw(image).rectangle((4, 4, 50, 50), fill=(20, 30, 40, 255))
        with self.assertRaisesRegex(RuntimeError, "exactly 6"):
            module.ordered_six_components(image)

    def test_bakes_outline_behind_opaque_subject_without_changing_core(self):
        module = load_script()
        image = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
        ImageDraw.Draw(image).rectangle((12, 12, 19, 19), fill=(20, 30, 40, 255))
        result = module.bake_alpha_outline(image, "#33fff2ff", 2)
        self.assertEqual(result.getpixel((15, 15)), (20, 30, 40, 255))
        self.assertEqual(result.getpixel((10, 15)), (51, 255, 242, 255))
        self.assertEqual(result.getpixel((8, 15))[3], 0)

    def test_validation_padding_tracks_configured_cell_margin_and_outline(self):
        module = load_script()
        self.assertEqual(module.validation_padding(32, 8), 24)
        self.assertEqual(module.validation_padding(8, 2), 6)
        self.assertEqual(module.validation_padding(1, 4), 1)


if __name__ == "__main__":
    unittest.main()
