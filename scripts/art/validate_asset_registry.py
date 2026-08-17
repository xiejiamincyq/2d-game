"""Validate that the art registry agrees with runtime files and review evidence."""

from __future__ import annotations

import json
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Any


ALLOWED_STATES = {
    "planned",
    "preview",
    "draft",
    "style-approved",
    "gameplay-approved",
    "final",
}
FILE_REQUIRED_STATES = {"draft", "style-approved", "gameplay-approved", "final"}
MANIFEST_REQUIRED_STATES = {"style-approved", "gameplay-approved", "final"}
EVIDENCE_REQUIRED_STATES = {"gameplay-approved", "final"}
EVIDENCE_FIELDS = ("gameplay_capture", "alpha_report", "review_document")


@dataclass(frozen=True)
class RegistryEntry:
    asset_id: str
    runtime_path: str
    review_state: str
    line_number: int


def _unquote(value: str) -> str:
    stripped = value.strip()
    if len(stripped) >= 2 and stripped.startswith("`") and stripped.endswith("`"):
        return stripped[1:-1]
    return stripped


def parse_registry(markdown: str) -> list[RegistryEntry]:
    entries: list[RegistryEntry] = []
    for line_number, line in enumerate(markdown.splitlines(), start=1):
        if not line.lstrip().startswith("|"):
            continue
        columns = [column.strip() for column in line.strip().strip("|").split("|")]
        if len(columns) != 7:
            continue
        asset_id = _unquote(columns[0])
        runtime_path = _unquote(columns[5])
        review_state = _unquote(columns[6])
        if asset_id in {"Asset ID", "---"} or set(asset_id) == {"-"}:
            continue
        entries.append(RegistryEntry(asset_id, runtime_path, review_state, line_number))
    return entries


def _project_path(project_root: Path, value: str) -> Path | None:
    prefix = "res://"
    if not value.startswith(prefix):
        return None
    relative = Path(value[len(prefix) :])
    if relative.is_absolute() or ".." in relative.parts:
        return None
    return project_root / relative


def _load_production_manifests(manifests_dir: Path, errors: list[str]) -> dict[str, tuple[Path, dict[str, Any]]]:
    manifests: dict[str, tuple[Path, dict[str, Any]]] = {}
    for path in sorted(manifests_dir.rglob("*.production-v*.json")):
        try:
            data = json.loads(path.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError) as error:
            errors.append(f"{path}: invalid production manifest: {error}")
            continue
        asset_id = data.get("asset_id")
        if not isinstance(asset_id, str) or not asset_id:
            errors.append(f"{path}: production manifest has no asset_id")
            continue
        if asset_id in manifests:
            errors.append(f"{path}: duplicate production manifest for {asset_id}")
            continue
        manifests[asset_id] = (path, data)
    return manifests


def _validate_evidence(
    asset_id: str,
    manifest_path: Path,
    manifest: dict[str, Any],
    project_root: Path,
    errors: list[str],
) -> None:
    evidence = manifest.get("runtime_evidence")
    if not isinstance(evidence, dict):
        errors.append(f"{asset_id}: {manifest_path} requires runtime_evidence")
        return
    for field in EVIDENCE_FIELDS:
        value = evidence.get(field)
        if not isinstance(value, str) or not value.strip():
            errors.append(f"{asset_id}: runtime_evidence.{field} is required")
            continue
        path = Path(value)
        if path.is_absolute() or ".." in path.parts or not (project_root / path).is_file():
            errors.append(f"{asset_id}: runtime_evidence.{field} does not exist: {value}")


def validate_registry(registry_path: Path, project_root: Path, manifests_dir: Path) -> list[str]:
    errors: list[str] = []
    try:
        entries = parse_registry(registry_path.read_text(encoding="utf-8"))
    except OSError as error:
        return [f"{registry_path}: {error}"]
    if not entries:
        errors.append(f"{registry_path}: no asset rows found")
        return errors

    manifests = _load_production_manifests(manifests_dir, errors)
    seen: set[str] = set()
    for entry in entries:
        label = f"{registry_path}:{entry.line_number} ({entry.asset_id})"
        if entry.asset_id in seen:
            errors.append(f"{label}: duplicate asset_id")
            continue
        seen.add(entry.asset_id)
        if entry.review_state not in ALLOWED_STATES:
            errors.append(f"{label}: invalid review state {entry.review_state}")

        runtime_path = _project_path(project_root, entry.runtime_path)
        if runtime_path is None:
            errors.append(f"{label}: runtime path must be a safe res:// path")
        elif entry.review_state in FILE_REQUIRED_STATES and not runtime_path.is_file():
            errors.append(f"{label}: runtime asset does not exist: {entry.runtime_path}")

        manifest_record = manifests.get(entry.asset_id)
        if entry.review_state in MANIFEST_REQUIRED_STATES and manifest_record is None:
            errors.append(f"{label}: production manifest is required for {entry.review_state}")
            continue
        if manifest_record is None:
            continue

        manifest_path, manifest = manifest_record
        manifest_state = manifest.get("review_state")
        if manifest_state != entry.review_state:
            errors.append(
                f"{label}: registry state {entry.review_state} does not match production manifest {manifest_state}"
            )
        manifest_runtime = manifest.get("runtime_path")
        if manifest_runtime != entry.runtime_path:
            errors.append(
                f"{label}: runtime path {entry.runtime_path} does not match production manifest {manifest_runtime}"
            )
        if entry.review_state in EVIDENCE_REQUIRED_STATES:
            _validate_evidence(entry.asset_id, manifest_path, manifest, project_root, errors)
    return errors


def main() -> int:
    project_root = Path(__file__).resolve().parents[2]
    registry = project_root / "docs/art/asset-registry.md"
    manifests = project_root / "docs/art/manifests"
    errors = validate_registry(registry, project_root, manifests)
    if errors:
        for error in errors:
            print(f"ERROR {error}")
        return 1
    print(f"VALID {registry}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
