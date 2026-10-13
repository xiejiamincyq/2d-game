"""Portable resource signatures and byte-identical authored evidence policy."""
from pathlib import Path
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[2]


class GitResourceBytesTest(unittest.TestCase):
    def attributes(self, path):
        result = subprocess.run(
            ["git", "check-attr", "text", "eol", "--", path], cwd=ROOT,
            text=True, encoding="utf-8", capture_output=True, check=True,
        )
        return {line.split(": ")[-2]: line.split(": ")[-1]
                for line in result.stdout.splitlines()}

    def test_godot_resources_and_scripts_preserve_signed_raw_bytes(self):
        for path in ["actors/a.gd", "a.gdshader", "a.tscn", "a.tres", "a.uid",
                     "a.py", "a.ps1", "project.godot", "export_presets.cfg"]:
            with self.subTest(path=path):
                self.assertEqual(self.attributes(path)["text"], "unset")

    def test_recorded_json_and_svg_evidence_is_not_normalized(self):
        for path in ["docs/art/previews/report.json", "assets/art/authoring/body.svg"]:
            with self.subTest(path=path):
                self.assertEqual(self.attributes(path)["text"], "unset")

    def test_real_mixed_line_ending_inputs_are_not_filtered_at_git_boundary(self):
        # Existing code/config contains CRLF, while newly signed native
        # resources use LF. Both are legitimate signed inputs. Enforcing LF
        # on old files changes their raw SHA despite no gameplay edit.
        for path in ["project.godot", "export_presets.cfg", "scripts/actors/Player.gd",
                     "scripts/actors/Player.gd.uid", "scenes/Main.tscn",
                     "assets/art/actors/native/player_front_motion_v1.tres"]:
            with self.subTest(path=path):
                raw = subprocess.run(["git", "hash-object", "--no-filters", path],
                                     cwd=ROOT, text=True, capture_output=True, check=True)
                filtered = subprocess.run(["git", "hash-object", "--path=" + path, path],
                                          cwd=ROOT, text=True, capture_output=True, check=True)
                self.assertEqual(raw.stdout.strip(), filtered.stdout.strip())


if __name__ == "__main__":
    unittest.main()
