import tempfile
import unittest
from pathlib import Path
import sys

from PIL import Image, ImageDraw

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))
from scripts.art.build_player_sample import build_sample_strips


class BuildPlayerSampleTests(unittest.TestCase):
    def _source_sheet(self, path: Path, leave_empty: bool = False) -> None:
        sheet = Image.new("RGBA", (800, 300), (0, 0, 0, 0))
        draw = ImageDraw.Draw(sheet)
        for row in range(3):
            for column in range(8):
                if leave_empty and row == 1 and column == 4:
                    continue
                left = column * 100 + 20
                top = row * 100 + 12 + column % 3
                right = column * 100 + 80
                bottom = row * 100 + 88
                draw.rectangle(
                    (left, top, right, bottom),
                    fill=(40 + row * 60, 180, 220, 255),
                    outline=(40 + row * 60, 180, 220, 240),
                    width=2,
                )
        sheet.save(path)

    def test_builds_three_aligned_eight_direction_strips(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source = root / "source.png"
            self._source_sheet(source)

            outputs = build_sample_strips(source, root / "out")

            self.assertEqual(set(outputs), {"body", "weapon", "composite"})
            for path in outputs.values():
                with Image.open(path) as atlas:
                    self.assertEqual(atlas.size, (512, 64))
                    self.assertEqual(atlas.mode, "RGBA")
                    self.assertEqual(atlas.getpixel((0, 0))[3], 0)
                    alpha_values = set(atlas.getchannel("A").get_flattened_data())
                    self.assertFalse(alpha_values.intersection(range(1, 32)))
                    self.assertFalse(alpha_values.intersection(range(224, 255)))
            with Image.open(outputs["body"]) as body:
                for frame_index in range(8):
                    frame = body.crop((frame_index * 64, 0, (frame_index + 1) * 64, 64))
                    self.assertEqual(frame.getchannel("A").getbbox()[3], 60)

    def test_rejects_an_empty_direction_cell(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source = root / "source.png"
            self._source_sheet(source, leave_empty=True)

            with self.assertRaisesRegex(ValueError, "row 1 column 4"):
                build_sample_strips(source, root / "out")


if __name__ == "__main__":
    unittest.main()
