"""Remove studio backgrounds from canonical Player A modeling views."""

from __future__ import annotations

import argparse
import subprocess
from collections.abc import Callable
from pathlib import Path

from PIL import Image


VIEW_FILES = {
    "front": "player_a_modeling_front_v1.png",
    "right": "player_a_modeling_right_v1.png",
    "back": "player_a_modeling_back_v1.png",
}


def validate_cutout(image: Image.Image, label: str) -> None:
    rgba = image.convert("RGBA")
    alpha = rgba.getchannel("A")
    alpha_min, alpha_max = alpha.getextrema()
    if alpha_min == 255:
        raise RuntimeError(f"{label} cutout is still fully opaque")
    if alpha_max == 0:
        raise RuntimeError(f"{label} cutout has an empty alpha mask")
    for corner in ((0, 0), (rgba.width - 1, 0), (0, rgba.height - 1), (rgba.width - 1, rgba.height - 1)):
        if alpha.getpixel(corner) != 0:
            raise RuntimeError(f"{label} cutout retained background at a canvas corner")


def remove_background(
    source_path: Path,
    output_path: Path,
    remover: Callable[[Image.Image], Image.Image],
) -> Path:
    with Image.open(source_path) as source_image:
        source = source_image.convert("RGBA")
    result = remover(source).convert("RGBA")
    validate_cutout(result, source_path.name)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    result.save(output_path)
    return output_path


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("input_dir", type=Path)
    parser.add_argument("output_dir", type=Path)
    parser.add_argument(
        "--helper",
        type=Path,
        default=Path.home()
        / ".codex/skills/.system/imagegen/scripts/remove_chroma_key.py",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    if not args.helper.is_file():
        raise FileNotFoundError(f"imagegen background-removal helper not found: {args.helper}")
    for view, filename in VIEW_FILES.items():
        source = args.input_dir / filename
        output = args.output_dir / filename.replace("_v1.png", "_alpha_v1.png")
        if not source.is_file():
            raise FileNotFoundError(f"{view} modeling view not found: {source}")
        subprocess.run(
            [
                "python",
                str(args.helper),
                "--input",
                str(source),
                "--out",
                str(output),
                "--auto-key",
                "border",
                "--soft-matte",
                "--transparent-threshold",
                "18",
                "--opaque-threshold",
                "72",
                "--despill",
                "--force",
            ],
            check=True,
        )
        with Image.open(output) as cutout:
            validate_cutout(cutout, view)
        print(f"BACKGROUND PASS: {view}={output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
