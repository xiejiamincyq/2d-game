"""Real scanner subprocesses against isolated source trees, not game play."""
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
SCANNER = ROOT / "scripts/tests/check_pause_ownership.ps1"
PWSH = "C:/Program Files/PowerShell/7/pwsh.exe"


class PauseOwnershipTest(unittest.TestCase):
    def run_scan(self, files):
        with tempfile.TemporaryDirectory(prefix="endless-pause-ownership-") as temp:
            root = Path(temp)
            for name, text in files.items():
                path = root / name
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text(text, encoding="utf-8")
            return subprocess.run(
                [PWSH, "-NoProfile", "-File", str(SCANNER), "-ProjectRoot", str(root)],
                capture_output=True, text=True, encoding="utf-8", timeout=20,
            )

    def test_only_two_explicit_production_owners_are_allowed(self):
        result = self.run_scan({
            "scripts/Main.gd": "get_tree().paused = true\n",
            "scripts/campaign/ChapterRun.gd": "get_tree().paused = false\n",
            "scripts/tests/fixtures/LegacyWaveMain.gd": "get_tree().paused = true\n",
            "scripts/art/probe.gd": "get_tree().paused = false\n",
        })
        self.assertEqual(0, result.returncode, result.stdout + result.stderr)
        self.assertIn("CHECK PASS: SceneTree.paused ownership", result.stdout)

    def test_enemy_ui_and_other_campaign_writers_still_fail(self):
        for path in ["scripts/actors/Enemy.gd", "scripts/ui/HUD.gd", "scripts/campaign/Other.gd"]:
            with self.subTest(path=path):
                result = self.run_scan({path: "get_tree().paused = true\n"})
                self.assertNotEqual(0, result.returncode)
                self.assertIn(path, result.stdout + result.stderr)

    def test_quotes_comments_and_non_script_files_are_not_writers(self):
        result = self.run_scan({
            "scripts/ui/HUD.gd": '# get_tree().paused = true\nvar a = "get_tree().paused = false"\nvar b = \'get_tree().paused = true\'\nvar reading = get_tree().paused == true\n',
            "scripts/ui/note.txt": "get_tree().paused = true\n",
        })
        self.assertEqual(0, result.returncode, result.stdout + result.stderr)

    def test_literal_before_real_assignment_does_not_hide_it(self):
        result = self.run_scan({"scripts/ui/HUD.gd": 'var label = "# harmless"; get_tree().paused = true\n'})
        self.assertNotEqual(0, result.returncode)
        self.assertIn("scripts/ui/HUD.gd", result.stdout + result.stderr)

    def test_missing_scripts_root_is_not_a_pass(self):
        result = self.run_scan({})
        self.assertNotEqual(0, result.returncode)


if __name__ == "__main__":
    unittest.main()
