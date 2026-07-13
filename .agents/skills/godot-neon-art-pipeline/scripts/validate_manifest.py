from __future__ import annotations

import json
import math
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
ASSET_CONTRACTS: dict[str, tuple[str, str, tuple[int, int]]] = {
    "actor": ("characters-combat", "actors", (1024, 1024)),
    "enemy": ("characters-combat", "actors", (1024, 1024)),
    "effect": ("characters-combat", "effects", (1024, 1024)),
    "pickup": ("characters-combat", "pickups", (512, 512)),
    "background": ("environment", "environment", (2560, 1440)),
    "environment": ("environment", "environment", (1024, 1024)),
    "ui-panel": ("ui", "ui", (2048, 1024)),
    "ui-icon": ("ui", "ui", (256, 256)),
}
ASSET_CLASSES = set(ASSET_CONTRACTS)
RUNTIME_ROOTS = {"actors", "effects", "pickups", "environment", "ui"}
BACKGROUNDS = {"transparent", "opaque", "overlay"}
REVIEW_STATES = {"draft", "style-approved", "gameplay-approved", "final"}
LICENSE_STATES = {"pending", "approved"}
ASSET_ID = re.compile(r"^[a-z0-9]+(?:_[a-z0-9]+)*$")
PATH_SEGMENT = re.compile(r"^[a-z0-9]+(?:_[a-z0-9]+)*$")
ASPECT_RATIO = re.compile(r"^([1-9][0-9]*):([1-9][0-9]*)$")
HEX_COLOR = re.compile(r"^#[0-9a-fA-F]{6}$")


def validate_dimensions(name: str, value: Any, errors: list[str]) -> bool:
    if not isinstance(value, dict):
        return False
    if set(value) != {"width", "height"}:
        errors.append(f"{name} must contain only width and height")
        return False
    valid = True
    for axis in ("width", "height"):
        if type(value[axis]) is not int or value[axis] <= 0:
            errors.append(f"{name}.{axis} must be a positive integer")
            valid = False
    return valid


def runtime_root(value: str) -> str | None:
    prefix = "res://assets/art/"
    if not value.startswith(prefix) or not value.endswith(".png"):
        return None
    segments = value[len(prefix) : -len(".png")].split("/")
    if len(segments) < 2 or any(not segment for segment in segments):
        return None
    root, *path_segments = segments
    if root not in RUNTIME_ROOTS:
        return None
    if not all(PATH_SEGMENT.fullmatch(segment) for segment in path_segments):
        return None
    return root


def validate_aspect_ratio(value: str, source_dimensions: dict[str, Any], errors: list[str]) -> None:
    match = ASPECT_RATIO.fullmatch(value)
    if match is None:
        errors.append("aspect_ratio must use positive integers in W:H form")
        return
    width, height = (int(component) for component in match.groups())
    divisor = math.gcd(source_dimensions["width"], source_dimensions["height"])
    expected = (source_dimensions["width"] // divisor, source_dimensions["height"] // divisor)
    if (width, height) != expected:
        errors.append(f"aspect_ratio must match the reduced source_dimensions ratio {expected[0]}:{expected[1]}")


def validate(data: Any) -> list[str]:
    errors: list[str] = []
    if not isinstance(data, dict):
        return ["manifest root must be an object"]
    for key, expected_type in REQUIRED_TYPES.items():
        if key not in data:
            errors.append(f"missing required field: {key}")
        elif expected_type is int and type(data[key]) is not int:
            errors.append(f"{key} must be {expected_type.__name__}")
        elif expected_type is not int and not isinstance(data[key], expected_type):
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
    path_root = runtime_root(data["runtime_path"])
    if path_root is None:
        errors.append("runtime_path must be a lowercase snake_case PNG path below an approved art root")
    source_dimensions_valid = validate_dimensions("source_dimensions", data["source_dimensions"], errors)
    validate_dimensions("runtime_target", data["runtime_target"], errors)
    if data["asset_class"] in ASSET_CONTRACTS:
        expected_batch, expected_root, expected_source = ASSET_CONTRACTS[data["asset_class"]]
        if data["batch"] != expected_batch:
            errors.append(f"batch must be {expected_batch} for asset_class {data['asset_class']}")
        if path_root is not None and path_root != expected_root:
            errors.append(
                f"runtime_path must use the {expected_root} root "
                f"for asset_class {data['asset_class']}"
            )
        if source_dimensions_valid:
            actual_source = (
                data["source_dimensions"]["width"],
                data["source_dimensions"]["height"],
            )
            if actual_source != expected_source:
                errors.append(
                    f"source_dimensions must be {expected_source[0]}x{expected_source[1]} "
                    f"for asset_class {data['asset_class']}"
                )
    if source_dimensions_valid:
        validate_aspect_ratio(data["aspect_ratio"], data["source_dimensions"], errors)
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
