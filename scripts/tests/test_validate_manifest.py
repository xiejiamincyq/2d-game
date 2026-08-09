from __future__ import annotations

import copy
import importlib.util
import json
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
VALIDATOR_PATH = ROOT / ".agents/skills/godot-neon-art-pipeline/scripts/validate_manifest.py"
TEMPLATE_PATH = ROOT / ".agents/skills/godot-neon-art-pipeline/assets/manifest-entry.json"
SPEC = importlib.util.spec_from_file_location("godot_neon_validate_manifest", VALIDATOR_PATH)
assert SPEC is not None and SPEC.loader is not None
VALIDATOR = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(VALIDATOR)


class ManifestReviewStateTest(unittest.TestCase):
    def setUp(self) -> None:
        self.manifest = json.loads(TEMPLATE_PATH.read_text(encoding="utf-8"))

    def test_preview_is_a_valid_review_state(self) -> None:
        manifest = copy.deepcopy(self.manifest)
        manifest["review_state"] = "preview"

        self.assertEqual(VALIDATOR.validate(manifest), [])

    def test_unknown_review_state_is_rejected(self) -> None:
        manifest = copy.deepcopy(self.manifest)
        manifest["review_state"] = "approved-ish"

        errors = VALIDATOR.validate(manifest)

        self.assertTrue(any("review_state must be one of" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
