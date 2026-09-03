"""Normalize generated alpha and pack B-style chibi art for Godot."""

from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image


def clean_generated_alpha(
    image: Image.Image,
    transparent_threshold: int = 48,
    opaque_threshold: int = 248,
) -> Image.Image:
    """Remove faint generated glow while retaining antialiased subject edges."""
    if not 0 <= transparent_threshold < opaque_threshold <= 255:
        raise ValueError("alpha thresholds must satisfy 0 <= transparent < opaque <= 255")
    rgba = image.convert("RGBA")

    def remap(value: int) -> int:
        if value <= transparent_threshold:
            return 0
        if value >= opaque_threshold:
            return 255
        return round((value - transparent_threshold) * 255 / (opaque_threshold - transparent_threshold))

    rgba.putalpha(rgba.getchannel("A").point(remap))
    return rgba


def _fit_subject(subject: Image.Image, usable: int, scale: float | None = None) -> Image.Image:
    if scale is None:
        scale = min(usable / subject.width, usable / subject.height)
    size = (max(1, round(subject.width * scale)), max(1, round(subject.height * scale)))
    return subject.resize(size, Image.Resampling.LANCZOS)


def _visible_subject(image: Image.Image) -> Image.Image:
    cleaned = clean_generated_alpha(image)
    bbox = cleaned.getchannel("A").getbbox()
    if bbox is None:
        raise RuntimeError("source has no visible subject")
    return cleaned.crop(bbox)


def prepare_single_sprite(
    image: Image.Image,
    canvas_size: int = 128,
    padding: int = 8,
) -> Image.Image:
    subject = _visible_subject(image)
    usable = canvas_size - padding * 2
    if usable <= 0:
        raise ValueError("padding leaves no usable canvas")
    subject = _fit_subject(subject, usable)
    output = Image.new("RGBA", (canvas_size, canvas_size), (0, 0, 0, 0))
    output.alpha_composite(
        subject,
        ((canvas_size - subject.width) // 2, canvas_size - padding - subject.height),
    )
    return output


def prepare_cardinal_atlas(
    image: Image.Image,
    cell_size: int = 128,
    padding: int = 8,
) -> Image.Image:
    source = image.convert("RGBA")
    midpoint_x = source.width // 2
    midpoint_y = source.height // 2
    boxes = (
        (0, 0, midpoint_x, midpoint_y),
        (midpoint_x, 0, source.width, midpoint_y),
        (0, midpoint_y, midpoint_x, source.height),
        (midpoint_x, midpoint_y, source.width, source.height),
    )
    subjects = [_visible_subject(source.crop(box)) for box in boxes]
    usable = cell_size - padding * 2
    if usable <= 0:
        raise ValueError("padding leaves no usable atlas cell")
    common_scale = min(
        1.0,
        usable / max(subject.width for subject in subjects),
        usable / max(subject.height for subject in subjects),
    )
    output = Image.new("RGBA", (cell_size * 2, cell_size * 2), (0, 0, 0, 0))
    for index, subject in enumerate(subjects):
        fitted = _fit_subject(subject, usable, common_scale)
        column = index % 2
        row = index // 2
        x = column * cell_size + (cell_size - fitted.width) // 2
        y = row * cell_size + cell_size - padding - fitted.height
        output.alpha_composite(fitted, (x, y))
    return output


def prepare_weapon_cardinal_atlas(
    image: Image.Image,
    cell_size: int = 128,
    padding: int = 8,
    depth_scale: float = 0.58,
) -> Image.Image:
    """Derive four held-weapon views from one right-facing master.

    Front/back use a shortened long axis so the gun reads as foreshortened
    instead of rotating like a full-length billboard across the character.
    """
    if not 0.25 <= depth_scale <= 1.0:
        raise ValueError("depth scale must stay between 0.25 and 1.0")
    right = prepare_single_sprite(image, cell_size, padding)
    left = right.transpose(Image.Transpose.FLIP_LEFT_RIGHT)

    def foreshorten(transpose: Image.Transpose) -> Image.Image:
        rotated = right.transpose(transpose)
        subject = _visible_subject(rotated)
        shortened = subject.resize(
            (subject.width, max(1, round(subject.height * depth_scale))),
            Image.Resampling.LANCZOS,
        )
        cell = Image.new("RGBA", (cell_size, cell_size), (0, 0, 0, 0))
        cell.alpha_composite(
            shortened,
            ((cell_size - shortened.width) // 2, (cell_size - shortened.height) // 2),
        )
        return cell

    front = foreshorten(Image.Transpose.ROTATE_270)
    back = foreshorten(Image.Transpose.ROTATE_90)
    output = Image.new("RGBA", (cell_size * 2, cell_size * 2), (0, 0, 0, 0))
    for index, cell in enumerate((front, back, left, right)):
        output.alpha_composite(cell, ((index % 2) * cell_size, (index // 2) * cell_size))
    return output


def _validate_cell(alpha: Image.Image, canvas_size: int, safe_padding: int) -> None:
    bbox = alpha.getbbox()
    if bbox is None:
        raise RuntimeError("runtime cell has no visible subject")
    if (
        bbox[0] < safe_padding
        or bbox[1] < safe_padding
        or bbox[2] > canvas_size - safe_padding
        or bbox[3] > canvas_size - safe_padding
    ):
        raise RuntimeError(f"runtime cell violates safe padding: {bbox}")
    if alpha.getextrema() != (0, 255):
        raise RuntimeError("runtime cell must contain transparent and opaque pixels")


def validate_single_sprite(image: Image.Image, canvas_size: int = 128, safe_padding: int = 8) -> None:
    rgba = image.convert("RGBA")
    if rgba.size != (canvas_size, canvas_size):
        raise RuntimeError("runtime sprite has incorrect dimensions")
    _validate_cell(rgba.getchannel("A"), canvas_size, safe_padding)


def validate_cardinal_atlas(image: Image.Image, cell_size: int = 128, safe_padding: int = 8) -> None:
    rgba = image.convert("RGBA")
    if rgba.size != (cell_size * 2, cell_size * 2):
        raise RuntimeError("runtime cardinal atlas has incorrect dimensions")
    alpha = rgba.getchannel("A")
    for row in range(2):
        for column in range(2):
            cell = alpha.crop(
                (
                    column * cell_size,
                    row * cell_size,
                    (column + 1) * cell_size,
                    (row + 1) * cell_size,
                )
            )
            _validate_cell(cell, cell_size, safe_padding)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("mode", choices=("single", "cardinal", "weapon-cardinal"))
    parser.add_argument("input", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument("--cell-size", type=int, default=128)
    parser.add_argument("--padding", type=int, default=8)
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    with Image.open(args.input) as source:
        if args.mode == "cardinal":
            result = prepare_cardinal_atlas(source, args.cell_size, args.padding)
            validate_cardinal_atlas(result, args.cell_size, args.padding)
        elif args.mode == "weapon-cardinal":
            result = prepare_weapon_cardinal_atlas(source, args.cell_size, args.padding)
            validate_cardinal_atlas(result, args.cell_size, args.padding)
        else:
            result = prepare_single_sprite(source, args.cell_size, args.padding)
            validate_single_sprite(result, args.cell_size, args.padding)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    result.save(args.output)
    print(f"CHIBI ASSET PASS: {args.output} {result.width}x{result.height} RGBA")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
