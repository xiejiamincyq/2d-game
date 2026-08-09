import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))
from scripts.art.build_player_action_slice import ACTIONS, build_action_slice


class BuildPlayerActionSliceTests(unittest.TestCase):
    def _body_sheet(self, path: Path) -> None:
        sheet = Image.new("RGBA", (600, 500), (0, 0, 0, 0))
        draw = ImageDraw.Draw(sheet)
        centers = (50, 135, 220, 305, 390, 475)
        for row in range(5):
            for column, center in enumerate(centers):
                top = row * 100 + 12 + column % 3
                draw.ellipse((center - 22, top, center + 22, row * 100 + 92), fill=(70, 130 + row * 10, 190, 255))
        sheet.save(path)

    def _weapon_atlas(self, path: Path, empty: bool = False) -> None:
        atlas = Image.new("RGBA", (512, 64), (0, 0, 0, 0))
        if not empty:
            draw = ImageDraw.Draw(atlas)
            origin = 64
            draw.rounded_rectangle((origin + 8, 25, origin + 54, 38), radius=3, fill=(255, 87, 31, 255))
            draw.rectangle((origin + 4, 28, origin + 16, 35), fill=(48, 48, 56, 255))
        atlas.save(path)

    def test_builds_three_layers_composite_and_two_sockets_for_thirty_frames(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            body = root / "body.png"
            weapon = root / "weapon.png"
            self._body_sheet(body)
            self._weapon_atlas(weapon)

            outputs = build_action_slice(body, weapon, root / "out")

            self.assertEqual(
                set(outputs),
                {"body", "weapon_behind", "weapon_front", "composite", "sockets"},
            )
            layers = {}
            for name in ("body", "weapon_behind", "weapon_front", "composite"):
                layers[name] = Image.open(outputs[name]).convert("RGBA")
                self.assertEqual(layers[name].size, (384, 320))
                self.assertEqual(layers[name].getpixel((0, 0))[3], 0)

            expected = Image.new("RGBA", (384, 320), (0, 0, 0, 0))
            expected.alpha_composite(layers["weapon_behind"])
            expected.alpha_composite(layers["body"])
            expected.alpha_composite(layers["weapon_front"])
            self.assertIsNone(ImageChops.difference(expected, layers["composite"]).getbbox())

            combined_weapon = Image.new("RGBA", (384, 320), (0, 0, 0, 0))
            combined_weapon.alpha_composite(layers["weapon_behind"])
            combined_weapon.alpha_composite(layers["weapon_front"])
            for row in range(5):
                for column in range(6):
                    frame = combined_weapon.crop((column * 64, row * 64, (column + 1) * 64, (row + 1) * 64))
                    bounds = frame.getchannel("A").getbbox()
                    self.assertIsNotNone(bounds)
                    self.assertGreaterEqual(bounds[2] - bounds[0], 24)

            sockets = json.loads(outputs["sockets"].read_text(encoding="utf-8"))
            self.assertEqual(tuple(sockets["actions"]), ACTIONS)
            vectors = set()
            for frames in sockets["actions"].values():
                self.assertEqual(len(frames), 6)
                for frame in frames:
                    grip = frame["grip"]
                    muzzle = frame["muzzle"]
                    self.assertTrue(all(0 <= value < 64 for value in grip + muzzle))
                    self.assertGreater(muzzle[0], grip[0])
                    vectors.add((muzzle[0] - grip[0], muzzle[1] - grip[1]))
            self.assertEqual(len(vectors), 1, "weapon direction changed between animation frames")

    def test_rejects_an_empty_weapon_direction(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            body = root / "body.png"
            weapon = root / "weapon.png"
            self._body_sheet(body)
            self._weapon_atlas(weapon, empty=True)

            with self.assertRaisesRegex(ValueError, "weapon direction 1 is empty"):
                build_action_slice(body, weapon, root / "out")

    def test_cli_runs_from_the_project_root(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            body = root / "body.png"
            weapon = root / "weapon.png"
            output = root / "out"
            self._body_sheet(body)
            self._weapon_atlas(weapon)

            project_root = Path(__file__).resolve().parents[2]
            completed = subprocess.run(
                [
                    sys.executable,
                    str(project_root / "scripts/art/build_player_action_slice.py"),
                    str(body),
                    str(weapon),
                    str(output),
                ],
                cwd=project_root,
                capture_output=True,
                text=True,
                check=False,
            )

            self.assertEqual(completed.returncode, 0, completed.stderr)
            self.assertTrue((output / "player_b_action_slice_down_right_composite.png").is_file())


if __name__ == "__main__":
    unittest.main()
