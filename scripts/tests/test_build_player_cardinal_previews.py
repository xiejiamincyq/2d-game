import tempfile
import unittest
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw

from scripts.art.build_player_cardinal_previews import DIRECTIONS, build_cardinal_previews


class BuildPlayerCardinalPreviewsTests(unittest.TestCase):
    def test_builds_three_true_yaw_bodies_and_direction_specific_weapon_occlusion(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            body_paths = {}
            for index, direction in enumerate(DIRECTIONS):
                path = root / f"{direction}.png"
                image = Image.new("RGBA", (256, 256), (0, 0, 0, 0))
                ImageDraw.Draw(image).rectangle((70 + index * 6, 30, 185, 235), fill=(40 + index * 50, 180, 220, 255))
                image.save(path)
                body_paths[direction] = path

            weapon_atlas = root / "weapons.png"
            atlas = Image.new("RGBA", (512, 64), (0, 0, 0, 0))
            draw = ImageDraw.Draw(atlas)
            for column in range(8):
                left = column * 64
                draw.rectangle((left + 7, 27, left + 57, 37), fill=(255, 80 + column * 10, 20, 255))
            atlas.save(weapon_atlas)

            outputs = build_cardinal_previews(body_paths, weapon_atlas, root / "out")

            self.assertEqual(set(outputs), {"body", "weapon_behind", "weapon_front", "composite"})
            layers = {name: Image.open(path).convert("RGBA") for name, path in outputs.items()}
            for layer in layers.values():
                self.assertEqual(layer.size, (192, 64))
                self.assertEqual(layer.getpixel((0, 0))[3], 0)

            expected = Image.new("RGBA", (192, 64), (0, 0, 0, 0))
            expected.alpha_composite(layers["weapon_behind"])
            expected.alpha_composite(layers["body"])
            expected.alpha_composite(layers["weapon_front"])
            self.assertIsNone(ImageChops.difference(expected, layers["composite"]).getbbox())

            behind_alpha = layers["weapon_behind"].getchannel("A")
            front_alpha = layers["weapon_front"].getchannel("A")
            self.assertIsNone(behind_alpha.crop((0, 0, 64, 64)).getbbox())
            self.assertIsNotNone(front_alpha.crop((0, 0, 64, 64)).getbbox())
            self.assertIsNotNone(behind_alpha.crop((64, 0, 128, 64)).getbbox())
            self.assertIsNotNone(front_alpha.crop((64, 0, 128, 64)).getbbox())
            self.assertIsNotNone(behind_alpha.crop((128, 0, 192, 64)).getbbox())
            self.assertIsNone(front_alpha.crop((128, 0, 192, 64)).getbbox())


if __name__ == "__main__":
    unittest.main()
