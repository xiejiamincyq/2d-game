import unittest
from pathlib import Path

from PIL import Image, ImageDraw

from scripts.art.prepare_static_enemy_sprite import prepare_sprite, validate_sprite


ROOT = Path(__file__).resolve().parents[2]


class PrepareStaticEnemySpriteTests(unittest.TestCase):
    def test_crop_scale_outline_and_padding(self) -> None:
        source = Image.new("RGBA", (300, 220), (0, 0, 0, 0))
        draw = ImageDraw.Draw(source)
        draw.rectangle((90, 40, 240, 190), fill=(60, 45, 70, 255))

        result = prepare_sprite(source)

        self.assertEqual(result.size, (128, 128))
        validate_sprite(result, 128, 7)
        self.assertEqual(result.getpixel((0, 0))[3], 0)

    def test_production_static_enemies_are_bounded(self) -> None:
        for name in ("enemy_scrapper.png", "enemy_bruiser.png"):
            with Image.open(ROOT / "assets/art/actors/enemies" / name) as image:
                validate_sprite(image.convert("RGBA"), 128, 7)

    def test_high_resolution_sources_have_clean_alpha_and_no_key_green(self) -> None:
        for name in ("enemy_scrapper_alpha_v1.png", "enemy_bruiser_alpha_v1.png"):
            with Image.open(ROOT / "assets/art/source/enemies" / name) as image:
                rgba = image.convert("RGBA")
            self.assertEqual(rgba.size, (1254, 1254))
            for corner in ((0, 0), (1253, 0), (0, 1253), (1253, 1253)):
                self.assertEqual(rgba.getpixel(corner)[3], 0)
            visible = [pixel for pixel in rgba.get_flattened_data() if pixel[3] >= 128]
            key_green = [
                pixel
                for pixel in visible
                if pixel[1] > 200 and pixel[1] > pixel[0] * 1.4 and pixel[1] > pixel[2] * 1.4
            ]
            self.assertTrue(visible)
            self.assertEqual(key_green, [])


if __name__ == "__main__":
    unittest.main()
