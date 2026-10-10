"""Frozen spore reports retain verified provenance as runtime code evolves."""
import hashlib
import json
import re
import subprocess
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
# Frozen capture sources, not today's actor implementation. Future migrations
# must not falsify or require rerendering these historical diagnostics.
CAPTURE_REVISION = "3d5e2b1feb1dd406041242dad15eaff827c0017d"
REPORTS = (
    "sporeling-resource-v1.json",
    "sporeling-opacity-v1.json",
    "sporeling-chapter-v1.json",
)


def source_hashes(content):
    # Evidence retains exact render-machine bytes; Git may change only EOLs.
    lf = content.replace(b"\r\n", b"\n")
    return {hashlib.sha256(value).hexdigest() for value in (content, lf, lf.replace(b"\n", b"\r\n"))}


class SporelingEvidenceTest(unittest.TestCase):
    def test_git_eol_conversion_does_not_mask_source_edits(self):
        original = hashlib.sha256(b"const x = 1\n").hexdigest()
        self.assertIn(original, source_hashes(b"const x = 1\r\n"))
        self.assertNotIn(original, source_hashes(b"const x = 2\r\n"))

    def test_source_bindings_match_verified_capture_revision(self):
        for name in REPORTS:
            relative_report = f"docs/art/previews/campaign/{name}"
            report = json.loads((ROOT / relative_report).read_text(encoding="utf-8"))
            original = subprocess.run(
                ["git", "show", f"{CAPTURE_REVISION}:{relative_report}"],
                cwd=ROOT, check=True, capture_output=True,
            ).stdout
            self.assertTrue(source_hashes((ROOT / relative_report).read_bytes()) & source_hashes(original))
            # Exact JSON data from the verified capture commit: no invented
            # hashes or swapped samples. Git can normalize mixed line endings,
            # so raw render-machine source SHA is not a portable blob SHA.
            self.assertEqual(report, json.loads(original.decode("utf-8")))
            self.assertTrue(report["passed"], name)
            self.assertGreater(len(report["sources"]), 3, name)
            for relative_path, expected in report["sources"].items():
                with self.subTest(report=name, source=relative_path):
                    self.assertRegex(expected, re.compile(r"^[a-f0-9]{64}$"))
                    source = subprocess.run(
                        ["git", "show", f"{CAPTURE_REVISION}:{relative_path}"],
                        cwd=ROOT, check=True, capture_output=True,
                    ).stdout
                    self.assertGreater(len(source), 0)


if __name__ == "__main__":
    unittest.main()
