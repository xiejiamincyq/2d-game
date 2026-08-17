from __future__ import annotations

import unittest
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[2]
ASSETS = (
    ROOT / "assets/art/actors/enemies/enemy_dasher_a_actions_runtime_v1.png",
    ROOT / "assets/art/actors/enemies/enemy_dasher_b_actions_runtime_v1.png",
)


class DasherActionAssetsTest(unittest.TestCase):
    def test_runtime_sheets_have_strict_rgba_grid_and_safe_frames(self):
        for path in ASSETS:
            with self.subTest(path=path.name), Image.open(path) as image:
                self.assertEqual(image.mode, "RGBA")
                self.assertEqual(image.size, (384, 256))
                alpha = image.getchannel("A")
                self.assertEqual(alpha.getextrema(), (0, 255))
                self.assertEqual(
                    [
                        alpha.getpixel((0, 0)),
                        alpha.getpixel((383, 0)),
                        alpha.getpixel((0, 255)),
                        alpha.getpixel((383, 255)),
                    ],
                    [0, 0, 0, 0],
                )
                for row in range(2):
                    for column in range(3):
                        cell = alpha.crop(
                            (
                                column * 128,
                                row * 128,
                                (column + 1) * 128,
                                (row + 1) * 128,
                            )
                        )
                        bbox = cell.getbbox()
                        self.assertIsNotNone(bbox)
                        assert bbox is not None
                        self.assertGreaterEqual(bbox[0], 6)
                        self.assertGreaterEqual(bbox[1], 6)
                        self.assertLessEqual(bbox[2], 122)
                        self.assertLessEqual(bbox[3], 122)


if __name__ == "__main__":
    unittest.main()
