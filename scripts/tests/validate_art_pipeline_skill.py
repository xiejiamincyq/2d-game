from __future__ import annotations

import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
SKILL = ROOT / ".agents" / "skills" / "godot-neon-art-pipeline"
VALIDATOR = SKILL / "scripts" / "validate_manifest.py"
TEMPLATE = SKILL / "assets" / "manifest-entry.json"


class ArtPipelineSkillTest(unittest.TestCase):
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
        data = json.loads(TEMPLATE.read_text(encoding="utf-8"))
        data["review_state"] = "final"
        data["license_review_state"] = "pending"
        with tempfile.TemporaryDirectory() as directory:
            invalid = Path(directory) / "invalid.json"
            invalid.write_text(json.dumps(data), encoding="utf-8")
            result = subprocess.run(
                [sys.executable, str(VALIDATOR), str(invalid)],
                cwd=ROOT,
                text=True,
                capture_output=True,
                check=False,
            )
        self.assertNotEqual(0, result.returncode)
        self.assertIn("license_review_state", result.stdout)


if __name__ == "__main__":
    unittest.main(verbosity=2)
