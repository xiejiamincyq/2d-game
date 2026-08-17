"""Remove a light neutral background only when it is connected to the canvas edge."""

from __future__ import annotations

import argparse
from collections import deque
from pathlib import Path

from PIL import Image


def is_light_neutral(pixel: tuple[int, int, int], minimum: int, chroma: int) -> bool:
    return min(pixel) >= minimum and max(pixel) - min(pixel) <= chroma


def connected_background_mask(
    image: Image.Image,
    minimum: int = 224,
    chroma: int = 20,
) -> Image.Image:
    rgb = image.convert("RGB")
    width, height = rgb.size
    pixels = rgb.load()
    mask = Image.new("L", rgb.size, 0)
    mask_pixels = mask.load()
    queue: deque[tuple[int, int]] = deque()

    def enqueue(x: int, y: int) -> None:
        if mask_pixels[x, y] != 0 or not is_light_neutral(pixels[x, y], minimum, chroma):
            return
        mask_pixels[x, y] = 255
        queue.append((x, y))

    for x in range(width):
        enqueue(x, 0)
        enqueue(x, height - 1)
    for y in range(height):
        enqueue(0, y)
        enqueue(width - 1, y)

    while queue:
        x, y = queue.popleft()
        if x > 0:
            enqueue(x - 1, y)
        if x + 1 < width:
            enqueue(x + 1, y)
        if y > 0:
            enqueue(x, y - 1)
        if y + 1 < height:
            enqueue(x, y + 1)
    return mask


def remove_connected_background(
    image: Image.Image,
    minimum: int = 224,
    chroma: int = 20,
) -> Image.Image:
    rgba = image.convert("RGBA")
    background = connected_background_mask(rgba, minimum, chroma)
    alpha = background.point(lambda value: 0 if value else 255)
    rgba.putalpha(alpha)
    return rgba


def validate_sheet(image: Image.Image, columns: int, rows: int) -> None:
    if image.width % columns != 0 or image.height % rows != 0:
        raise RuntimeError("sheet dimensions are not divisible by the requested grid")
    alpha = image.getchannel("A")
    if alpha.getextrema() != (0, 255):
        raise RuntimeError("output must contain both transparent and opaque pixels")
    cell_width = image.width // columns
    cell_height = image.height // rows
    for row in range(rows):
        for column in range(columns):
            cell = alpha.crop(
                (
                    column * cell_width,
                    row * cell_height,
                    (column + 1) * cell_width,
                    (row + 1) * cell_height,
                )
            )
            if cell.getbbox() is None:
                raise RuntimeError(f"animation cell {column},{row} has no opaque subject")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("input", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument("--minimum", type=int, default=224)
    parser.add_argument("--chroma", type=int, default=20)
    parser.add_argument("--columns", type=int, default=3)
    parser.add_argument("--rows", type=int, default=2)
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    with Image.open(args.input) as source:
        result = remove_connected_background(source, args.minimum, args.chroma)
    validate_sheet(result, args.columns, args.rows)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    result.save(args.output)
    print(f"BACKGROUND PASS: {args.output} {result.width}x{result.height} RGBA")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
