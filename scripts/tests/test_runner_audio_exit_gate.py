"""Source-contract guard for capturing all Godot process diagnostic channels."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]


class RunnerAudioExitGateTest(unittest.TestCase):
    def test_godot_stdout_and_stderr_are_drained_asynchronously(self):
        source = (ROOT / "scripts/tests/run_tests.ps1").read_text(encoding="utf-8").split("# --- Python art-pipeline")[0]
        self.assertIn("$startInfo.RedirectStandardOutput = $true", source)
        self.assertIn("$startInfo.RedirectStandardError = $true", source)
        self.assertIn("$stdoutTask = $process.StandardOutput.ReadToEndAsync()", source)
        self.assertIn("$stderrTask = $process.StandardError.ReadToEndAsync()", source)
        self.assertLess(source.index("$stderrTask ="), source.index("$process.WaitForExit(120000)"))

    def test_forbidden_checks_use_all_channels_but_pass_marker_is_single_channel(self):
        source = (ROOT / "scripts/tests/run_tests.ps1").read_text(encoding="utf-8").split("# --- Python art-pipeline")[0]
        self.assertIn('$diagnosticOutput = $output + "`n" + $stdout + "`n" + $stderr', source)
        self.assertIn("if ($diagnosticOutput -match $forbidden)", source)
        self.assertIn('[regex]::Matches($output, "TEST PASS:', source)

    def test_articulated_origin_fixture_has_real_physics_budget(self):
        source = (ROOT / "scripts/tests/run_tests.ps1").read_text(encoding="utf-8")
        # This fixture awaits 64 real physics registrations. The generic 120
        # uncapped process frames exit without a PASS, despite process exit 0.
        self.assertRegex(
            source,
            r'if \(\$test -in @\([^)]*"RiftObserverOriginSafetyTest"[^)]*\)\) '
            r'\{ \$frameBudget = 3000; \$fixedStepArguments = "--max-fps 120" \}',
        )

    def test_nursery_supply_fixture_can_finish_natural_entrance(self):
        source = (ROOT / "scripts/tests/run_tests.ps1").read_text(encoding="utf-8")
        self.assertRegex(
            source,
            r'if \(\$test -eq "NurserySupplyRuntimeTest"\) '
            r'\{ \$frameBudget = 1800; \$fixedStepArguments = "--max-fps 120" \}',
        )


if __name__ == "__main__":
    unittest.main()
