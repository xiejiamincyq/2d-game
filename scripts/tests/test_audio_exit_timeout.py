"""Isolated negative runtime tests; do not weaken the regular forbidden gate."""
import os
from pathlib import Path
import re
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]


class AudioExitTimeoutTest(unittest.TestCase):
    def test_close_and_restart_report_real_timeout_and_exit_one(self):
        godot = os.environ.get("GODOT_BIN") or str(Path(os.environ["LOCALAPPDATA"]) / "Microsoft/WinGet/Links/godot_console.exe")
        self.assertTrue(Path(godot).is_file(), "configured Godot runtime is required")
        for mode in ("close", "restart"):
            with self.subTest(mode=mode), tempfile.TemporaryDirectory(prefix="overdrive-audio-timeout-") as directory:
                run = Path(directory)
                profile = run / "appdata"
                profile.mkdir()
                environment = dict(os.environ, APPDATA=str(profile))
                args = [godot, "--headless", "--audio-driver", "Dummy", "--path", str(ROOT), "--log-file", str(run / "engine.log"), "--script", "res://scripts/tests/MainCloseTimeoutProbe.gd"]
                if mode == "restart":
                    args += ["--", "--restart"]
                result = subprocess.run(args, cwd=ROOT, env=environment, capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=8)
                combined = result.stdout + result.stderr + (run / "engine.log").read_text(encoding="utf-8")
                self.assertEqual(1, result.returncode, combined)
                self.assertIn("NEGATIVE EXPECTED: timeout exit_code=1", result.stdout)
                self.assertIn("Audio shutdown timed out before scene exit", combined)
                self.assertNotRegex(combined, r"SCRIPT ERROR|ObjectDB instances were leaked|RID.+leaked|resources still in use|NEGATIVE FIXTURE FAILED")
                errors = re.findall(r"^ERROR: (.+)$", combined, re.MULTILINE)
                self.assertTrue(errors)
                self.assertTrue(all(error.strip() == "Audio shutdown timed out before scene exit" for error in errors), errors)
                print(f"NEGATIVE VERIFIED: {mode}, actual exit={result.returncode}, three-channel timeout observed, no unrelated error/leak")


if __name__ == "__main__":
    unittest.main()
