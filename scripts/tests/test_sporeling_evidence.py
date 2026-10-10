"""Committed spore evidence must bind real, unchanged source files."""
import hashlib
import json
import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
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

    def test_source_bindings_are_complete_and_current(self):
        for name in REPORTS:
            report = json.loads((ROOT / "docs/art/previews/campaign" / name).read_text(encoding="utf-8"))
            self.assertTrue(report["passed"], name)
            self.assertGreater(len(report["sources"]), 3, name)
            for relative_path, expected in report["sources"].items():
                with self.subTest(report=name, source=relative_path):
                    self.assertRegex(expected, re.compile(r"^[a-f0-9]{64}$"))
                    source = ROOT / relative_path
                    self.assertTrue(source.is_file(), relative_path)
                    self.assertIn(expected, source_hashes(source.read_bytes()))


if __name__ == "__main__":
    unittest.main()
