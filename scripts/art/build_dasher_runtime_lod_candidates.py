"""Build temporary Dasher runtime LOD candidates for the Godot comparison gate."""

from __future__ import annotations

from pathlib import Path

from PIL import Image

from repack_animation_sheet import (
    bake_alpha_outline,
    repack_sheet,
    validate_repacked_sheet,
    validation_padding,
)


ROOT = Path(__file__).resolve().parents[2]
CANDIDATE_SIZES = (128, 192, 256, 512)


def build_candidate(
    variant: str,
    cell_size: int,
    output_root: Path | None = None,
) -> Path:
    padding = round(cell_size / 16)
    outline_width = round(cell_size / 64)
    source_path = (
        ROOT
        / "assets"
        / "art"
        / "source"
        / "enemies"
        / f"enemy_dasher_{variant}_actions_alpha_v1.png"
    )
    destination = output_root if output_root is not None else ROOT / ".godot"
    output_path = destination / f"dasher_lod_{variant}_{cell_size}.png"
    with Image.open(source_path) as source:
        result = repack_sheet(source, cell_size=cell_size, padding=padding)
    result = bake_alpha_outline(result, width=outline_width)
    validate_repacked_sheet(
        result,
        cell_size=cell_size,
        padding=validation_padding(padding, outline_width),
    )
    output_path.parent.mkdir(parents=True, exist_ok=True)
    result.save(output_path)
    return output_path


def main() -> int:
    for variant in ("a", "b"):
        for cell_size in CANDIDATE_SIZES:
            output_path = build_candidate(variant, cell_size)
            print(f"LOD CANDIDATE PASS: {output_path.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
