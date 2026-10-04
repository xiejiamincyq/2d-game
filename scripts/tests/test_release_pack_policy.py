from pathlib import Path
import fnmatch
import re
import unittest


PROJECT_ROOT = Path(__file__).resolve().parents[2]


class ReleasePackPolicyTest(unittest.TestCase):
    def test_export_excludes_retired_m2_atlases_but_keeps_chibi(self) -> None:
        preset = (PROJECT_ROOT / "export_presets.cfg").read_text(encoding="utf-8")
        exclusions = re.search(r'^exclude_filter="([^"]*)"', preset, re.MULTILINE).group(1).split(",")
        exclusions = [pattern.strip() for pattern in exclusions]
        for action in ("ready", "move", "fire"):
            retired = f"assets/art/actors/player/player_m2_{action}_120yaw.png"
            with self.subTest(retired=retired):
                self.assertTrue((PROJECT_ROOT / retired).is_file(), "keep historical source atlas")
                self.assertTrue(any(fnmatch.fnmatchcase(retired, pattern) for pattern in exclusions),
                                "retired M2 atlas should not ship in the 2D chibi package")
        for current in ("player_chibi_b_cardinal_atlas_v1.png", "player_chibi_b_weapon_cardinal_atlas_v1.png"):
            runtime = f"assets/art/actors/player/{current}"
            with self.subTest(runtime=runtime):
                self.assertTrue((PROJECT_ROOT / runtime).is_file())
                self.assertFalse(any(fnmatch.fnmatchcase(runtime, pattern) for pattern in exclusions),
                                 "current chibi atlas must remain exportable")

    def test_runtime_preloads_are_not_excluded_from_the_export(self) -> None:
        preset = (PROJECT_ROOT / "export_presets.cfg").read_text(encoding="utf-8")
        exclusions = re.search(r'^exclude_filter="([^"]*)"', preset, re.MULTILINE).group(1).split(",")
        exclusions = [pattern.strip() for pattern in exclusions]
        for source in (PROJECT_ROOT / "scripts").rglob("*.gd"):
            relative = source.relative_to(PROJECT_ROOT).as_posix()
            if any(fnmatch.fnmatchcase(relative, pattern) for pattern in exclusions):
                continue
            dependencies = re.findall(r'''preload\(\s*["']res://([^"']+)["']\s*\)''', source.read_text(encoding="utf-8"))
            for dependency in dependencies:
                with self.subTest(source=relative, dependency=dependency):
                    self.assertFalse(any(fnmatch.fnmatchcase(dependency, pattern) for pattern in exclusions),
                                     "runtime preload excluded from standalone package")

    def test_diagnostic_build_folder_is_not_imported_as_runtime_resources(self) -> None:
        marker = PROJECT_ROOT / "build" / ".gdignore"
        self.assertTrue(marker.is_file(), "diagnostic CSV tables must not be imported as translations")
        self.assertEqual("", marker.read_text(encoding="utf-8").strip())

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

    def test_windows_exe_gate_exports_and_launches_release(self) -> None:
        windows_gate = (
            PROJECT_ROOT / "scripts" / "tests" / "run_windows_exe_checks.ps1"
        ).read_text(encoding="utf-8")

        for marker in (
            "$maxPackBytes = 30MB",
            "--export-release",
            "--quit-after",
            "WaitForExit(60000)",
            "SCRIPT ERROR",
            "Remove-Item -LiteralPath",
        ):
            self.assertIn(marker, windows_gate)


if __name__ == "__main__":
    unittest.main()
