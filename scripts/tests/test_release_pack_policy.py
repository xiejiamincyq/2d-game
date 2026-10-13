from pathlib import Path
import fnmatch
import re
import unittest
from unittest.mock import patch


PROJECT_ROOT = Path(__file__).resolve().parents[2]
# This older source was never tracked. Do not make a checkout depend on it;
# its exact export exclusion and lack of runtime references remain mandatory.
LOCAL_ONLY_RETIRED_BITMAPS = frozenset({"assets/art/environment/mint_farm_props_b_v1.png"})


class ReleasePackPolicyTest(unittest.TestCase):
    def test_checkout_without_local_only_retired_bitmap_keeps_release_policy(self) -> None:
        local_only = PROJECT_ROOT / "assets/art/environment/mint_farm_props_b_v1.png"
        original_is_file = Path.is_file

        def without_local_bitmap(path: Path) -> bool:
            return False if path == local_only else original_is_file(path)

        # Reproduce a clean checkout without moving/deleting the user's file.
        # The real policy still inspects the actual preset and runtime sources.
        with patch.object(Path, "is_file", without_local_bitmap):
            self.test_retired_bitmaps_are_preserved_but_no_longer_runtime_dependencies()

    def test_native_runtime_fixtures_keep_author_contracts_outside_pack(self) -> None:
        for kind in ("Impact", "Arena"):
            runtime = PROJECT_ROOT / f"scripts/tests/Native{kind}RuntimeTest.gd"
            self.assertTrue(runtime.is_file(), "canonical pure-runtime fixture missing")
            code = runtime.read_text(encoding="utf-8")
            self.assertNotIn("res://docs/", code)
            self.assertNotIn("get_file_as_string", code)
            author = (PROJECT_ROOT / f"scripts/tests/Native{kind}ArtTest.gd").read_text(encoding="utf-8")
            self.assertIn(f'extends "Native{kind}RuntimeTest.gd"', author)
            self.assertIn("res://docs/art/style-manifests/", author)
            runner = (PROJECT_ROOT / "scripts/tests/run_tests.ps1").read_text(encoding="utf-8")
            self.assertIn(f'"Native{kind}RuntimeTest"', runner)

    def test_resource_pack_gate_binds_current_measured_rift_evidence(self) -> None:
        gate = (PROJECT_ROOT / "scripts/tests/verify_rift_observer_actions_pack.ps1").read_text(encoding="utf-8")
        self.assertIn("$RiftActionsGpuReport", gate)
        self.assertNotIn("rift_observer_actions_gpu_v2/report.json", gate)
        for required in ("$gpu.samples.Count -ne 168", "$gpu.continuous_samples.Count -ne 90", "$gpu.gameplay_scale_samples.Count -ne 3", "RIFT OBSERVER GPU PASS", "$gpu.captures.PSObject.Properties", "$ResourceGpuLog", "$SourceFreezeReport"):
            self.assertIn(required, gate)

    def test_actual_combat_and_arena_support_is_relative_and_copied(self) -> None:
        gate = (PROJECT_ROOT / "scripts/tests/verify_rift_observer_actions_pack.ps1").read_text(encoding="utf-8")
        for suite in ("CombatFeedbackTest", "ArenaRuntimeTest"):
            fixture = (PROJECT_ROOT / f"scripts/tests/{suite}.gd").read_text(encoding="utf-8")
            self.assertIn('preload("TestSupport.gd")', fixture)
            self.assertNotIn('preload("res://scripts/tests/TestSupport.gd")', fixture)
            self.assertRegex(gate, rf"'{suite}'\s*=\s*@\('TestSupport'\)")

    def test_untraced_mp3_is_preserved_but_not_runtime_or_exported(self) -> None:
        path = "assets/audio/overdrive_bone_breaking.mp3"
        preset = (PROJECT_ROOT / "export_presets.cfg").read_text(encoding="utf-8")
        exclusions = [p.strip() for p in re.search(r'^exclude_filter="([^"]*)"', preset, re.MULTILINE).group(1).split(",")]
        self.assertTrue((PROJECT_ROOT / path).is_file(), "preserve the user's historical file")
        self.assertIn(path, exclusions, "untraced audio must not enter the final runtime pack")
        for root in ("scripts", "scenes", "assets/art/actors/native"):
            for source in (PROJECT_ROOT / root).rglob("*"):
                relative = source.relative_to(PROJECT_ROOT).as_posix()
                if source.suffix not in (".gd", ".tscn", ".tres") or any(fnmatch.fnmatchcase(relative, pattern) for pattern in exclusions):
                    continue
                self.assertNotIn("res://" + path, source.read_text(encoding="utf-8"), f"untraced audio remains a runtime dependency: {relative}")

    def test_retired_bitmaps_are_preserved_but_no_longer_runtime_dependencies(self) -> None:
        preset = (PROJECT_ROOT / "export_presets.cfg").read_text(encoding="utf-8")
        exclusions = [p.strip() for p in re.search(r'^exclude_filter="([^"]*)"', preset, re.MULTILINE).group(1).split(",")]
        retired = [f"assets/art/actors/enemies/enemy_{kind}_chibi_b_v1.png"
                   for kind in ("dasher", "bruiser", "spitter", "marksman", "lobber", "overseer")]
        retired += [f"assets/art/actors/enemies/enemy_dasher_{variant}_actions_runtime_v1.png"
                    for variant in ("a", "b")]
        retired += [f"assets/art/actors/enemies/enemy_{kind}.png"
                    for kind in ("bruiser", "lobber", "marksman", "overseer", "scrapper", "spitter")]
        retired += [
            "assets/art/effects/combat_hit_chibi_b_v1.png",
            "assets/art/environment/mint_farm_floor_b_v1.png",
            "assets/art/environment/mint_farm_props_b_packed_v1.png",
            "assets/art/actors/enemies/enemy_scrapper_chibi_b_v1.png",
            "assets/art/actors/player/player_chibi_b_cardinal_atlas_v1.png",
            "assets/art/actors/player/player_chibi_b_weapon_cardinal_atlas_v1.png",
            "assets/art/actors/player/player_chibi_b_weapon_v1.png",
            "assets/art/environment/mint_farm_props_b_v1.png",
        ]
        runtime_sources = []
        for root in ("scripts", "scenes", "assets/art/actors/native"):
            for source in (PROJECT_ROOT / root).rglob("*"):
                relative = source.relative_to(PROJECT_ROOT).as_posix()
                if source.suffix not in (".gd", ".tscn", ".tres") or any(fnmatch.fnmatchcase(relative, pattern) for pattern in exclusions):
                    continue
                runtime_sources.append((relative, source.read_text(encoding="utf-8")))
        for path in retired:
            with self.subTest(retired=path):
                if path not in LOCAL_ONLY_RETIRED_BITMAPS:
                    self.assertTrue((PROJECT_ROOT / path).is_file(), "tracked historical source must be preserved")
                self.assertIn(path, exclusions, "retired bitmap needs exact export exclusion, not broad directory removal")
                for relative, code in runtime_sources:
                    self.assertNotIn("res://" + path, code, f"retired bitmap is still a runtime dependency: {relative}")

    def test_formal_entry_pack_requires_current_gpu_and_relative_support(self) -> None:
        gate = (PROJECT_ROOT / "scripts/tests/verify_rift_observer_actions_pack.ps1").read_text(encoding="utf-8")
        self.assertIn("EntryGpuReport", gate)
        self.assertIn("Formal entry pack requires current GPU proof", gate)
        self.assertIn("$entryGpu.captures.Count -ne 15", gate)
        for suite in ("CampaignPrimaryEntryTest", "CampaignMenuIntegrationTest", "CampaignChapterLaunchTest"):
            self.assertRegex(gate, rf"'{suite}'\s*=\s*@\('TestSupport'\)")
        self.assertIn("'CampaignProgressStoreTest' = @('fixtures/CampaignFailedCommitStore')", gate)
        self.assertIn("$path.StartsWith('scripts/tests/fixtures/')", gate)

    def test_rift_chapter_pack_preserves_canonical_parent_closure(self) -> None:
        gate = (PROJECT_ROOT / "scripts/tests/verify_rift_observer_actions_pack.ps1").read_text(encoding="utf-8")
        for parent in ("SaltChapterTest", "EchoChapterLaunchTest", "EchoEncounterTest",
                       "EchoEncounterPolicyTest", "EchoEncounterRuntimeTest", "EchoMovementTest", "TestSupport"):
            self.assertIn(f"'{parent}'", gate, "external canonical fixture requires its actual relative parent")
        for suite in ("RiftChapterTest", "RiftChapterLaunchTest", "RiftEncounterTest", "RiftEncounterRuntimeTest"):
            self.assertIn(f"'{suite}'", gate)
        self.assertIn("ChapterFlowReports", gate)
        self.assertIn("restore-report.json", gate)
        self.assertIn("Ordinary sixth route prerequisite failed", gate)

    def test_native_technical_sample_does_not_ship(self) -> None:
        preset = (PROJECT_ROOT / "export_presets.cfg").read_text(encoding="utf-8")
        gate = (PROJECT_ROOT / "scripts/tests/run_release_checks.ps1").read_text(encoding="utf-8")
        self.assertIn("scenes/art/technical/*", preset)
        self.assertIn("res://scenes/art/technical/", gate)

    def test_export_excludes_retired_m2_atlases_but_keeps_native_player(self) -> None:
        preset = (PROJECT_ROOT / "export_presets.cfg").read_text(encoding="utf-8")
        exclusions = re.search(r'^exclude_filter="([^"]*)"', preset, re.MULTILINE).group(1).split(",")
        exclusions = [pattern.strip() for pattern in exclusions]
        for action in ("ready", "move", "fire"):
            retired = f"assets/art/actors/player/player_m2_{action}_120yaw.png"
            with self.subTest(retired=retired):
                self.assertTrue((PROJECT_ROOT / retired).is_file(), "keep historical source atlas")
                self.assertTrue(any(fnmatch.fnmatchcase(retired, pattern) for pattern in exclusions),
                                "retired M2 atlas should not ship in the 2D chibi package")
        for runtime in ("scenes/actors/native/player_paper_v1.tscn",
                        "assets/art/actors/native/player_front_motion_v1.tres",
                        "assets/art/actors/native/player_back_motion_v1.tres",
                        "assets/art/actors/native/player_left_motion_v1.tres",
                        "assets/art/actors/native/player_right_motion_v1.tres"):
            with self.subTest(runtime=runtime):
                self.assertTrue((PROJECT_ROOT / runtime).is_file())
                self.assertFalse(any(fnmatch.fnmatchcase(runtime, pattern) for pattern in exclusions),
                                 "current native player and all four motion libraries must remain exportable")

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
