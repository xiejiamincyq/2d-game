from __future__ import annotations

import json
import sys
import tempfile
import unittest
from pathlib import Path


ART_SCRIPTS = Path(__file__).resolve().parents[1] / "art"
sys.path.insert(0, str(ART_SCRIPTS))

from validate_asset_registry import validate_registry  # noqa: E402


HEADER = """# Registry

| Asset ID | Category | Purpose | Source | Runtime | Path | State |
|---|---|---|---:|---:|---|---|
"""


def row(asset_id: str, runtime_path: str, state: str) -> str:
    return f"| `{asset_id}` | actor | test | 64×64 | 64×64 | `{runtime_path}` | {state} |\n"


def write_manifest(directory: Path, asset_id: str, state: str, evidence: dict[str, str] | None = None) -> None:
    data: dict[str, object] = {
        "asset_id": asset_id,
        "runtime_path": f"res://assets/art/actors/{asset_id}.png",
        "review_state": state,
    }
    if evidence is not None:
        data["runtime_evidence"] = evidence
    (directory / f"{asset_id}.production-v1.json").write_text(
        json.dumps(data), encoding="utf-8"
    )


class AssetRegistryValidationTest(unittest.TestCase):
    def test_planned_missing_asset_is_allowed(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            registry = root / "registry.md"
            manifests = root / "manifests"
            manifests.mkdir()
            registry.write_text(
                HEADER + row("future_actor", "res://assets/art/actors/future_actor.png", "planned"),
                encoding="utf-8",
            )

            self.assertEqual(validate_registry(registry, root, manifests), [])

    def test_approved_asset_must_exist(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            registry = root / "registry.md"
            manifests = root / "manifests"
            manifests.mkdir()
            registry.write_text(
                HEADER + row("missing_actor", "res://assets/art/actors/missing_actor.png", "style-approved"),
                encoding="utf-8",
            )
            write_manifest(manifests, "missing_actor", "style-approved")

            errors = validate_registry(registry, root, manifests)

            self.assertTrue(any("runtime asset does not exist" in error for error in errors))

    def test_registry_and_production_manifest_states_must_match(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            runtime = root / "assets/art/actors/player.png"
            runtime.parent.mkdir(parents=True)
            runtime.write_bytes(b"fixture")
            registry = root / "registry.md"
            manifests = root / "manifests"
            manifests.mkdir()
            registry.write_text(
                HEADER + row("player", "res://assets/art/actors/player.png", "draft"),
                encoding="utf-8",
            )
            write_manifest(manifests, "player", "gameplay-approved")

            errors = validate_registry(registry, root, manifests)

            self.assertTrue(any("does not match production manifest" in error for error in errors))

    def test_gameplay_approval_requires_existing_runtime_evidence(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            runtime = root / "assets/art/actors/player.png"
            runtime.parent.mkdir(parents=True)
            runtime.write_bytes(b"fixture")
            registry = root / "registry.md"
            manifests = root / "manifests"
            manifests.mkdir()
            registry.write_text(
                HEADER + row("player", "res://assets/art/actors/player.png", "gameplay-approved"),
                encoding="utf-8",
            )
            write_manifest(manifests, "player", "gameplay-approved")

            errors = validate_registry(registry, root, manifests)

            self.assertTrue(any("runtime_evidence" in error for error in errors))

    def test_gameplay_approval_accepts_complete_runtime_evidence(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            runtime = root / "assets/art/actors/player.png"
            runtime.parent.mkdir(parents=True)
            runtime.write_bytes(b"fixture")
            evidence = {
                "gameplay_capture": "docs/evidence/player.png",
                "alpha_report": "docs/evidence/player-alpha.json",
                "review_document": "docs/reviews/player.md",
            }
            for relative in evidence.values():
                path = root / relative
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text("fixture", encoding="utf-8")
            registry = root / "registry.md"
            manifests = root / "manifests"
            manifests.mkdir()
            registry.write_text(
                HEADER + row("player", "res://assets/art/actors/player.png", "gameplay-approved"),
                encoding="utf-8",
            )
            write_manifest(manifests, "player", "gameplay-approved", evidence)

            self.assertEqual(validate_registry(registry, root, manifests), [])

    def test_duplicate_asset_ids_are_rejected(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            registry = root / "registry.md"
            manifests = root / "manifests"
            manifests.mkdir()
            duplicate = row("same_actor", "res://assets/art/actors/same_actor.png", "planned")
            registry.write_text(HEADER + duplicate + duplicate, encoding="utf-8")

            errors = validate_registry(registry, root, manifests)

            self.assertTrue(any("duplicate asset_id" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
