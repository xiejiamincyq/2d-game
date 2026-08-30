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

    def test_source_larger_than_the_class_target_is_valid(self) -> None:
        manifest = copy.deepcopy(self.manifest)
        manifest["source_dimensions"] = {"width": 1536, "height": 1024}
        manifest["aspect_ratio"] = "3:2"

        self.assertEqual(VALIDATOR.validate(manifest), [])

    def test_source_smaller_than_the_class_target_is_rejected(self) -> None:
        manifest = copy.deepcopy(self.manifest)
        manifest["source_dimensions"] = {"width": 512, "height": 512}
        manifest["aspect_ratio"] = "1:1"

        errors = VALIDATOR.validate(manifest)

        self.assertTrue(any("at least 1024x1024" in error for error in errors))

    def test_boss_uses_the_character_actor_contract(self) -> None:
        manifest = copy.deepcopy(self.manifest)
        manifest["asset_class"] = "boss"
        manifest["runtime_path"] = "res://assets/art/actors/enemies/test_boss.png"

        self.assertEqual(VALIDATOR.validate(manifest), [])


if __name__ == "__main__":
    unittest.main()
