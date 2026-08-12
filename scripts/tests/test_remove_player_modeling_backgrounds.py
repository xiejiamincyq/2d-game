from __future__ import annotations

import importlib.util
import tempfile
import unittest
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[2]
SCRIPT_PATH = ROOT / "scripts/art/remove_player_modeling_backgrounds.py"


def load_script():
    spec = importlib.util.spec_from_file_location(
        "remove_player_modeling_backgrounds", SCRIPT_PATH
    )
    assert spec is not None and spec.loader is not None
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


class RemovePlayerModelingBackgroundsTest(unittest.TestCase):
    def test_remove_background_writes_valid_rgba_cutout(self):
        module = load_script()
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source = root / "source.png"
            output = root / "output.png"
            Image.new("RGB", (64, 64), "white").save(source)

            def fake_remover(image: Image.Image) -> Image.Image:
                result = image.convert("RGBA")
                result.putalpha(Image.new("L", result.size, 0))
                for x in range(16, 48):
                    for y in range(8, 56):
                        result.putpixel((x, y), (30, 30, 30, 255))
                return result

            module.remove_background(source, output, fake_remover)

            with Image.open(output) as result:
                self.assertEqual(result.mode, "RGBA")
                self.assertEqual(result.getchannel("A").getextrema(), (0, 255))
                self.assertEqual(result.getpixel((0, 0))[3], 0)
                self.assertEqual(result.getpixel((32, 32))[3], 255)

    def test_validate_cutout_rejects_fully_opaque_alpha(self):
        module = load_script()
        image = Image.new("RGBA", (32, 32), (255, 255, 255, 255))

        with self.assertRaisesRegex(RuntimeError, "fully opaque"):
            module.validate_cutout(image, "test")


if __name__ == "__main__":
    unittest.main()
