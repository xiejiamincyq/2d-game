from pathlib import Path
import unittest


PROJECT_ROOT = Path(__file__).resolve().parents[2]


class ReleasePackPolicyTest(unittest.TestCase):
    def test_export_keeps_runtime_scripts_and_excludes_authoring_content(self) -> None:
        preset = (PROJECT_ROOT / "export_presets.cfg").read_text(encoding="utf-8")

        self.assertIn('export_filter="all_resources"', preset)
        for excluded_path in (
            "assets/art/source/*",
            "assets/art/actors/player/directions/*",
            "assets/art/actors/player/turnaround_directions/*",
            "assets/art/actors/player/technical_previews/*",
            "scripts/art/*",
            "scripts/tests/*",
        ):
            self.assertIn(excluded_path, preset)

    def test_release_gate_rejects_bloat_and_authoring_content(self) -> None:
        release_gate = (
            PROJECT_ROOT / "scripts" / "tests" / "run_release_checks.ps1"
        ).read_text(encoding="utf-8")

        self.assertIn("$maxPackBytes = 30MB", release_gate)
        for forbidden_path in (
            "res://assets/art/source/",
            "res://assets/art/actors/player/technical_previews/",
            "res://scripts/art/",
            "res://scripts/tests/",
        ):
            self.assertIn(forbidden_path, release_gate)


if __name__ == "__main__":
    unittest.main()
