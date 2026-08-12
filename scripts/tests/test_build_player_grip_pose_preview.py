import tempfile
import unittest
from pathlib import Path

from PIL import Image, ImageDraw

from scripts.art.build_player_grip_pose_preview import (
    _pose_bounds,
    build_comparison_board,
    build_runtime_atlas,
)


class BuildPlayerGripPosePreviewTests(unittest.TestCase):
    def _candidate(self, path: Path, pose_count: int = 3) -> None:
        image = Image.new("RGBA", (900, 900), (0, 0, 0, 0))
        draw = ImageDraw.Draw(image)
        for index in range(pose_count):
            center = 150 + index * 300
            draw.rectangle(
                (center - 90, 180 + index * 5, center + 90, 800),
                fill=(45 + index * 40, 150, 220, 255),
            )
        image.save(path)

    def test_builds_nine_complete_runtime_frames(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            candidates = {}
            for label in ("A", "B", "C"):
                path = root / f"{label}.png"
                self._candidate(path)
                candidates[label] = path

            output = root / "runtime.png"
            build_runtime_atlas(candidates, output)

            with Image.open(output) as atlas:
                self.assertEqual(atlas.size, (576, 64))
                self.assertEqual(atlas.mode, "RGBA")
                for frame_index in range(9):
                    frame = atlas.crop((frame_index * 64, 0, (frame_index + 1) * 64, 64))
                    self.assertIsNotNone(frame.getchannel("A").getbbox())

    def test_rejects_a_candidate_with_missing_pose(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            candidates = {}
            for label in ("A", "B", "C"):
                path = root / f"{label}.png"
                self._candidate(path, pose_count=2 if label == "B" else 3)
                candidates[label] = path

            with self.assertRaisesRegex(ValueError, "B.*three poses"):
                build_runtime_atlas(candidates, root / "runtime.png")

    def test_separates_three_poses_when_horizontal_projections_overlap(self) -> None:
        image = Image.new("RGBA", (900, 900), (0, 0, 0, 0))
        draw = ImageDraw.Draw(image)
        draw.rectangle((40, 60, 340, 310), fill=(80, 180, 220, 255))
        draw.rectangle((280, 360, 580, 670), fill=(120, 190, 220, 255))
        draw.rectangle((520, 70, 820, 320), fill=(160, 200, 220, 255))

        bounds = _pose_bounds(image, "A")

        self.assertEqual(len(bounds), 3)
        self.assertLess(bounds[0][0], bounds[1][0])
        self.assertLess(bounds[1][0], bounds[2][0])

    def test_builds_a_1280_by_720_review_board(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            candidates = {}
            for label in ("A", "B", "C"):
                path = root / f"{label}.png"
                self._candidate(path)
                candidates[label] = path
            runtime = root / "runtime.png"
            build_runtime_atlas(candidates, runtime)

            output = root / "board.png"
            build_comparison_board(candidates, runtime, output)

            with Image.open(output) as board:
                self.assertEqual(board.size, (1280, 720))
                self.assertEqual(board.mode, "RGBA")


if __name__ == "__main__":
    unittest.main()
