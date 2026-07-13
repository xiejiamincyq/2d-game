from __future__ import annotations

import json
import re
import sys
from pathlib import Path
from typing import Any


REQUIRED_TYPES: dict[str, type] = {
    "schema_version": int,
    "asset_id": str,
    "batch": str,
    "asset_class": str,
    "purpose": str,
    "runtime_path": str,
    "source_dimensions": dict,
    "runtime_target": dict,
    "aspect_ratio": str,
    "background": str,
    "camera": str,
    "facing": str,
    "palette": list,
    "lighting": str,
    "prompt": str,
    "negative_constraints": list,
    "references": list,
    "generation_model": str,
    "license_review_state": str,
    "review_state": str,
}
BATCHES = {"characters-combat", "environment", "ui"}
ASSET_CLASSES = {"actor", "enemy", "effect", "pickup", "background", "environment", "ui-panel", "ui-icon"}
BACKGROUNDS = {"transparent", "opaque", "overlay"}
REVIEW_STATES = {"draft", "style-approved", "gameplay-approved", "final"}
LICENSE_STATES = {"pending", "approved"}
ASSET_ID = re.compile(r"^[a-z0-9]+(?:_[a-z0-9]+)*$")
RUNTIME_PATH = re.compile(r"^res://assets/art/[a-z0-9_/]+\.png$")
HEX_COLOR = re.compile(r"^#[0-9a-fA-F]{6}$")


def validate_dimensions(name: str, value: Any, errors: list[str]) -> None:
    if not isinstance(value, dict):
        return
    if set(value) != {"width", "height"}:
        errors.append(f"{name} must contain only width and height")
        return
    for axis in ("width", "height"):
        if not isinstance(value[axis], int) or value[axis] <= 0:
            errors.append(f"{name}.{axis} must be a positive integer")


def validate(data: Any) -> list[str]:
    errors: list[str] = []
    if not isinstance(data, dict):
        return ["manifest root must be an object"]
    for key, expected_type in REQUIRED_TYPES.items():
        if key not in data:
            errors.append(f"missing required field: {key}")
        elif not isinstance(data[key], expected_type):
            errors.append(f"{key} must be {expected_type.__name__}")
    if errors:
        return errors
    if data["schema_version"] != 1:
        errors.append("schema_version must be 1")
    if not ASSET_ID.fullmatch(data["asset_id"]):
        errors.append("asset_id must use lowercase snake_case")
    if data["batch"] not in BATCHES:
        errors.append(f"batch must be one of {sorted(BATCHES)}")
    if data["asset_class"] not in ASSET_CLASSES:
        errors.append(f"asset_class must be one of {sorted(ASSET_CLASSES)}")
    if not RUNTIME_PATH.fullmatch(data["runtime_path"]):
        errors.append("runtime_path must be a lowercase PNG path below res://assets/art/")
    validate_dimensions("source_dimensions", data["source_dimensions"], errors)
    validate_dimensions("runtime_target", data["runtime_target"], errors)
    if data["background"] not in BACKGROUNDS:
        errors.append(f"background must be one of {sorted(BACKGROUNDS)}")
    if data["review_state"] not in REVIEW_STATES:
        errors.append(f"review_state must be one of {sorted(REVIEW_STATES)}")
    if data["license_review_state"] not in LICENSE_STATES:
        errors.append(f"license_review_state must be one of {sorted(LICENSE_STATES)}")
    if not data["purpose"].strip() or not data["prompt"].strip():
        errors.append("purpose and prompt must not be empty")
    if not data["negative_constraints"] or not all(isinstance(item, str) and item.strip() for item in data["negative_constraints"]):
        errors.append("negative_constraints must contain non-empty strings")
    if not data["palette"] or not all(isinstance(color, str) and HEX_COLOR.fullmatch(color) for color in data["palette"]):
        errors.append("palette must contain six-digit hex colors")
    if data["review_state"] == "final" and data["license_review_state"] != "approved":
        errors.append("license_review_state must be approved before review_state can be final")
    return errors


def main() -> int:
    if len(sys.argv) != 2:
        print("ERROR usage: validate_manifest.py <manifest.json>")
        return 2
    path = Path(sys.argv[1])
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        print(f"ERROR {error}")
        return 1
    errors = validate(data)
    if errors:
        for error in errors:
            print(f"ERROR {error}")
        return 1
    print(f"VALID {path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
