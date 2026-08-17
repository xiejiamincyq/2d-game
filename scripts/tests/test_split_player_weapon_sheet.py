import importlib.util
import tempfile
import unittest
from pathlib import Path

from PIL import Image, ImageDraw


SCRIPT_PATH = (
    Path(__file__).resolve().parents[1]
    / "art"
    / "split_player_weapon_sheet.py"
)


def load_script():
    spec = importlib.util.spec_from_file_location(
        "split_player_weapon_sheet", SCRIPT_PATH
    )
    module = importlib.util.module_from_spec(spec)
    assert spec.loader is not None
    spec.loader.exec_module(module)
    return module


class SplitPlayerWeaponSheetTest(unittest.TestCase):
    def test_split_sheet_creates_equal_square_views_without_cross_panel_content(self):
        module = load_script()
        source = Image.new("RGB", (2172, 724), (0, 255, 0))
        draw = ImageDraw.Draw(source)
        draw.rectangle((40, 220, 900, 500), fill=(40, 40, 40))
        draw.rectangle((960, 220, 1725, 500), fill=(70, 70, 70))
        draw.rectangle((1940, 215, 2020, 505), fill=(100, 100, 100))

        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source_path = root / "sheet.png"
            output_dir = root / "views"
            source.save(source_path)

            outputs = module.split_sheet(source_path, output_dir)

            self.assertEqual(list(outputs), ["front", "back", "right"])
            for view, path in outputs.items():
                with Image.open(path) as output:
                    self.assertEqual(output.size, (1024, 1024), view)
                    self.assertEqual(output.getpixel((0, 0))[:3], (0, 255, 0), view)

    def test_split_sheet_rejects_unexpected_dimensions(self):
        module = load_script()
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source_path = root / "wrong.png"
            Image.new("RGB", (1024, 1024), (0, 255, 0)).save(source_path)

            with self.assertRaisesRegex(ValueError, "3:1"):
                module.split_sheet(source_path, root / "views")

    def test_split_sheet_scales_oversized_panels_instead_of_cropping_them(self):
        module = load_script()
        source = Image.new("RGB", (3000, 1000), (0, 255, 0))
        draw = ImageDraw.Draw(source)
        draw.rectangle((10, 300, 1290, 700), fill=(40, 40, 40))

        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source_path = root / "large.png"
            source.save(source_path)

            outputs = module.split_sheet(source_path, root / "views")

            with Image.open(outputs["front"]) as output:
                self.assertEqual(output.getpixel((0, 512))[:3], (0, 255, 0))
                self.assertEqual(output.getpixel((1023, 512))[:3], (0, 255, 0))
                self.assertEqual(output.getpixel((512, 512))[:3], (40, 40, 40))


if __name__ == "__main__":
    unittest.main()
