"""Crop and pack one transparent enemy master into a bounded runtime canvas."""

from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image

try:
    from .repack_animation_sheet import bake_alpha_outline
except ImportError:  # Direct script execution keeps scripts/art on sys.path.
    from repack_animation_sheet import bake_alpha_outline


def prepare_sprite(
    source: Image.Image,
    canvas_size: int = 128,
    padding: int = 8,
    outline_width: int = 1,
) -> Image.Image:
    rgba = source.convert("RGBA")
    bbox = rgba.getchannel("A").getbbox()
    if bbox is None:
        raise RuntimeError("source has no visible subject")
    subject = rgba.crop(bbox)
    usable = canvas_size - padding * 2
    scale = min(usable / subject.width, usable / subject.height)
    subject = subject.resize(
        (max(1, round(subject.width * scale)), max(1, round(subject.height * scale))),
        Image.Resampling.LANCZOS,
    )
    output = Image.new("RGBA", (canvas_size, canvas_size), (0, 0, 0, 0))
    output.alpha_composite(
        subject,
        ((canvas_size - subject.width) // 2, (canvas_size - subject.height) // 2),
    )
    output = bake_alpha_outline(output, "#33fff2e0", outline_width)
    validate_sprite(output, canvas_size, max(1, padding - outline_width))
    return output


def validate_sprite(image: Image.Image, canvas_size: int, safe_padding: int) -> None:
    if image.size != (canvas_size, canvas_size):
        raise RuntimeError("runtime sprite has incorrect dimensions")
    alpha = image.getchannel("A")
    if alpha.getextrema() != (0, 255):
        raise RuntimeError("runtime sprite must contain transparent and opaque pixels")
    bbox = alpha.getbbox()
    if bbox is None:
        raise RuntimeError("runtime sprite is empty")
    if bbox[0] < safe_padding or bbox[1] < safe_padding or bbox[2] > canvas_size - safe_padding or bbox[3] > canvas_size - safe_padding:
        raise RuntimeError(f"runtime sprite violates safe padding: {bbox}")
    for corner in ((0, 0), (canvas_size - 1, 0), (0, canvas_size - 1), (canvas_size - 1, canvas_size - 1)):
        if alpha.getpixel(corner) != 0:
            raise RuntimeError("runtime sprite retained an opaque corner")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("input", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument("--canvas-size", type=int, default=128)
    parser.add_argument("--padding", type=int, default=8)
    parser.add_argument("--outline-width", type=int, default=1)
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    with Image.open(args.input) as source:
        result = prepare_sprite(source, args.canvas_size, args.padding, args.outline_width)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    result.save(args.output)
    print(f"STATIC ENEMY PASS: {args.output} {result.width}x{result.height} RGBA")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
