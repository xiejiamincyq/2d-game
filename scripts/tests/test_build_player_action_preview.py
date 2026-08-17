import sys
import tempfile
import unittest
from pathlib import Path

from PIL import Image, ImageDraw

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))
from scripts.art.build_player_action_preview import build_action_atlas, build_comparison_board


class BuildPlayerActionPreviewTests(unittest.TestCase):
    def _source_sheet(self, path: Path, empty_cell: tuple[int, int] | None = None) -> None:
        sheet = Image.new("RGBA", (600, 500), (0, 0, 0, 0))
        draw = ImageDraw.Draw(sheet)
        for row in range(5):
            for column in range(6):
                if empty_cell == (row, column):
                    continue
                left = column * 100 + 18 + column
                top = row * 100 + 10 + row
                right = column * 100 + 82
                bottom = row * 100 + 90
                draw.rectangle((left, top, right, bottom), fill=(60, 180, 220, 255))
        sheet.save(path)

    def test_builds_a_six_by_five_runtime_scale_atlas(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source = root / "source.png"
            output = root / "atlas.png"
            self._source_sheet(source)

            build_action_atlas(source, output)

            with Image.open(output) as atlas:
                self.assertEqual(atlas.size, (384, 320))
                self.assertEqual(atlas.mode, "RGBA")
                self.assertEqual(atlas.getpixel((0, 0))[3], 0)
                for row in range(5):
                    for column in range(6):
                        frame = atlas.crop((column * 64, row * 64, (column + 1) * 64, (row + 1) * 64))
                        self.assertIsNotNone(frame.getchannel("A").getbbox())

    def test_rejects_an_empty_action_cell(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source = root / "source.png"
            self._source_sheet(source, empty_cell=(3, 4))

            with self.assertRaisesRegex(ValueError, "row 3 column 4"):
                build_action_atlas(source, root / "atlas.png")

    def test_detects_six_frames_when_generated_columns_drift_left(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source = root / "drifted.png"
            sheet = Image.new("RGBA", (600, 500), (0, 0, 0, 0))
            draw = ImageDraw.Draw(sheet)
            centers = (50, 135, 220, 305, 390, 475)
            colors = [(30 + column * 35, 120, 210, 255) for column in range(6)]
            for row in range(5):
                for center, color in zip(centers, colors):
                    draw.rectangle((center - 24, row * 100 + 18, center + 24, row * 100 + 90), fill=color)
            sheet.save(source)

            output = root / "atlas.png"
            build_action_atlas(source, output)

            with Image.open(output) as atlas:
                for column, color in enumerate(colors):
                    sampled = atlas.getpixel((column * 64 + 32, 32))
                    self.assertLessEqual(abs(sampled[0] - color[0]), 3)
                    self.assertGreater(sampled[3], 230)

    def test_builds_a_labeled_three_candidate_comparison(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            atlases = []
            for label in ("A", "B", "C"):
                source = root / f"source_{label}.png"
                atlas = root / f"atlas_{label}.png"
                self._source_sheet(source)
                build_action_atlas(source, atlas)
                atlases.append(atlas)

            output = root / "comparison.png"
            build_comparison_board(dict(zip(("A", "B", "C"), atlases)), output)

            with Image.open(output) as comparison:
                self.assertEqual(comparison.size, (1280, 448))
                self.assertEqual(comparison.mode, "RGBA")


if __name__ == "__main__":
    unittest.main()
