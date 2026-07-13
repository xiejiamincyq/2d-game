from __future__ import annotations

import json
import math
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
SKILL = ROOT / ".agents" / "skills" / "godot-neon-art-pipeline"
VALIDATOR = SKILL / "scripts" / "validate_manifest.py"
TEMPLATE = SKILL / "assets" / "manifest-entry.json"
CLASS_CONTRACTS = {
    "actor": ("characters-combat", "actors", (1024, 1024)),
    "enemy": ("characters-combat", "actors", (1024, 1024)),
    "effect": ("characters-combat", "effects", (1024, 1024)),
    "pickup": ("characters-combat", "pickups", (512, 512)),
    "background": ("environment", "environment", (2560, 1440)),
    "environment": ("environment", "environment", (1024, 1024)),
    "ui-panel": ("ui", "ui", (2048, 1024)),
    "ui-icon": ("ui", "ui", (256, 256)),
}


class ArtPipelineSkillTest(unittest.TestCase):
    def load_manifest(self, **overrides: object) -> dict[str, object]:
        data = json.loads(TEMPLATE.read_text(encoding="utf-8"))
        data.update(overrides)
        return data

    def manifest_for_class(self, asset_class: str, **overrides: object) -> dict[str, object]:
        batch, root, (width, height) = CLASS_CONTRACTS[asset_class]
        divisor = math.gcd(width, height)
        fields: dict[str, object] = {
            "asset_class": asset_class,
            "batch": batch,
            "runtime_path": f"res://assets/art/{root}/sample.png",
            "source_dimensions": {"width": width, "height": height},
            "aspect_ratio": f"{width // divisor}:{height // divisor}",
        }
        fields.update(overrides)
        return self.load_manifest(**fields)

    def run_validator(self, data: dict[str, object]) -> subprocess.CompletedProcess[str]:
        with tempfile.TemporaryDirectory() as directory:
            manifest = Path(directory) / "manifest.json"
            manifest.write_text(json.dumps(data), encoding="utf-8")
            return subprocess.run(
                [sys.executable, str(VALIDATOR), str(manifest)],
                cwd=ROOT,
                text=True,
                capture_output=True,
                check=False,
            )

    def assert_manifest_invalid(self, data: dict[str, object], message: str) -> None:
        result = self.run_validator(data)
        self.assertNotEqual(0, result.returncode, result.stdout + result.stderr)
        self.assertIn(message, result.stdout)

    def test_required_skill_files_exist(self) -> None:
        required = [
            SKILL / "SKILL.md",
            SKILL / "agents" / "openai.yaml",
            SKILL / "references" / "style-guide.md",
            SKILL / "references" / "godot-import.md",
            TEMPLATE,
            VALIDATOR,
        ]
        self.assertEqual([], [str(path.relative_to(ROOT)) for path in required if not path.is_file()])

    def test_skill_routes_prompt_search_generation_and_style_lock(self) -> None:
        text = (SKILL / "SKILL.md").read_text(encoding="utf-8")
        for phrase in (
            "ai-image-prompts-skill",
            "imagegen",
            "style-lock",
            "validate_manifest.py",
            "Never overwrite an approved asset",
        ):
            self.assertIn(phrase, text)

    def test_skill_requires_explicit_review_confirmation_before_final(self) -> None:
        text = (SKILL / "SKILL.md").read_text(encoding="utf-8")
        self.assertIn("does not store or prove review history", text)
        self.assertIn("must explicitly confirm", text)
        self.assertIn("style-approved", text)
        self.assertIn("gameplay-approved", text)

    def test_references_pin_current_project_constraints(self) -> None:
        style = (SKILL / "references" / "style-guide.md").read_text(encoding="utf-8")
        imports = (SKILL / "references" / "godot-import.md").read_text(encoding="utf-8")
        for phrase in ("1280×720", "#33fff2", "#f559bf", "1024×1024", "2560×1440"):
            self.assertIn(phrase, style.lower())
        for phrase in ("canvas_items", "collision radius", "lossless", "mipmaps", "nine-patch"):
            self.assertIn(phrase, imports.lower())

    def test_openai_metadata_mentions_the_skill(self) -> None:
        metadata = (SKILL / "agents" / "openai.yaml").read_text(encoding="utf-8")
        self.assertIn('$godot-neon-art-pipeline', metadata)
        self.assertIn('display_name: "Godot Neon Art Pipeline"', metadata)

    def test_manifest_template_is_valid(self) -> None:
        result = subprocess.run(
            [sys.executable, str(VALIDATOR), str(TEMPLATE)],
            cwd=ROOT,
            text=True,
            capture_output=True,
            check=False,
        )
        self.assertEqual(0, result.returncode, result.stdout + result.stderr)
        self.assertIn("VALID", result.stdout)

    def test_manifest_validator_rejects_unsafe_final_asset(self) -> None:
        self.assert_manifest_invalid(
            self.load_manifest(review_state="final", license_review_state="pending"),
            "license_review_state",
        )

    def test_manifest_validator_rejects_booleans_as_integer_fields(self) -> None:
        cases = (
            ("schema_version", self.load_manifest(schema_version=True)),
            (
                "source_dimensions.width",
                self.load_manifest(source_dimensions={"width": True, "height": 1024}),
            ),
            (
                "runtime_target.height",
                self.load_manifest(runtime_target={"width": 64, "height": True}),
            ),
        )
        for message, data in cases:
            with self.subTest(message=message):
                self.assert_manifest_invalid(data, message)

    def test_manifest_validator_rejects_undeclared_or_empty_runtime_path_segments(self) -> None:
        for runtime_path in (
            "res://assets/art/characters/player_base.png",
            "res://assets/art//actors/player_base.png",
            "res://assets/art/actors//player_base.png",
        ):
            with self.subTest(runtime_path=runtime_path):
                self.assert_manifest_invalid(
                    self.load_manifest(runtime_path=runtime_path),
                    "runtime_path",
                )

    def test_manifest_validator_rejects_asset_classes_in_the_wrong_batch(self) -> None:
        for asset_class, (batch, _root, _source) in CLASS_CONTRACTS.items():
            wrong_batch = next(
                candidate
                for candidate in ("characters-combat", "environment", "ui")
                if candidate != batch
            )
            with self.subTest(asset_class=asset_class):
                self.assert_manifest_invalid(
                    self.manifest_for_class(asset_class, batch=wrong_batch),
                    "batch",
                )

    def test_manifest_validator_rejects_asset_classes_in_the_wrong_runtime_root(self) -> None:
        for asset_class, (_batch, root, _source) in CLASS_CONTRACTS.items():
            wrong_root = next(
                candidate
                for candidate in ("actors", "effects", "pickups", "environment", "ui")
                if candidate != root
            )
            with self.subTest(asset_class=asset_class):
                self.assert_manifest_invalid(
                    self.manifest_for_class(
                        asset_class,
                        runtime_path=f"res://assets/art/{wrong_root}/sample.png",
                    ),
                    "runtime_path",
                )

    def test_manifest_validator_rejects_noncanonical_source_dimensions(self) -> None:
        cases = {
            "actor": (1024, 512),
            "enemy": (512, 1024),
            "effect": (512, 512),
            "pickup": (1024, 1024),
            "background": (1280, 720),
            "environment": (2048, 2048),
            "ui-icon": (512, 512),
            "ui-panel": (1024, 512),
        }
        for asset_class, (width, height) in cases.items():
            divisor = math.gcd(width, height)
            with self.subTest(asset_class=asset_class):
                self.assert_manifest_invalid(
                    self.manifest_for_class(
                        asset_class,
                        source_dimensions={"width": width, "height": height},
                        aspect_ratio=f"{width // divisor}:{height // divisor}",
                    ),
                    "source_dimensions",
                )

    def test_manifest_validator_rejects_invalid_or_mismatched_aspect_ratios(self) -> None:
        for aspect_ratio in ("0:1", "-1:1", "1.5:1", "1:0", "2:2", "16:9"):
            with self.subTest(aspect_ratio=aspect_ratio):
                self.assert_manifest_invalid(
                    self.load_manifest(aspect_ratio=aspect_ratio),
                    "aspect_ratio",
                )


if __name__ == "__main__":
    unittest.main(verbosity=2)
