"""Align the eight approved turnaround views to the rendered 3D silhouettes."""

from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image


CELL_SIZE = 512
VIEW_COUNT = 8
BACKGROUND = (6, 16, 25, 255)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--source", type=Path, required=True)
    parser.add_argument("--frames", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    return parser.parse_args()


def foreground_bbox(image: Image.Image, threshold: int = 34) -> tuple[int, int, int, int]:
    rgba = image.convert("RGBA")
    pixels = rgba.load()
    xs: list[int] = []
    ys: list[int] = []
    for y in range(rgba.height):
        for x in range(rgba.width):
            red, green, blue, alpha = pixels[x, y]
            if alpha > 0 and max(red, green, blue) >= threshold:
                xs.append(x)
                ys.append(y)
    if not xs:
        raise RuntimeError("Could not locate subject foreground")
    return min(xs), min(ys), max(xs) + 1, max(ys) + 1


def alpha_bbox(image: Image.Image) -> tuple[int, int, int, int]:
    alpha = image.convert("RGBA").getchannel("A")
    bbox = alpha.getbbox()
    if bbox is None:
        raise RuntimeError("Rendered direction frame has no alpha silhouette")
    return bbox


def main() -> int:
    args = parse_args()
    source = Image.open(args.source).convert("RGBA")
    if source.width < 4 or source.height < 2:
        raise RuntimeError(f"Source sheet is too small: {source.size}")

    output = Image.new("RGBA", (CELL_SIZE * 4, CELL_SIZE * 2), BACKGROUND)
    for view_index in range(VIEW_COUNT):
        column = view_index % 4
        row = view_index // 4
        source_cell = source.crop((
            round(column * source.width / 4),
            round(row * source.height / 2),
            round((column + 1) * source.width / 4),
            round((row + 1) * source.height / 2),
        )).resize((CELL_SIZE, CELL_SIZE), Image.Resampling.LANCZOS)
        source_bbox = foreground_bbox(source_cell)
        subject = source_cell.crop(source_bbox)

        runtime_angle = (90 - view_index * 45) % 360
        frame = Image.open(args.frames / f"angle_{runtime_angle:03d}.png")
        frame_bbox = alpha_bbox(frame)
        target_bbox = tuple(value * (CELL_SIZE // frame.width) for value in frame_bbox)
        target_width = target_bbox[2] - target_bbox[0]
        target_height = target_bbox[3] - target_bbox[1]
        subject = subject.resize((target_width, target_height), Image.Resampling.LANCZOS)

        cell = Image.new("RGBA", (CELL_SIZE, CELL_SIZE), BACKGROUND)
        cell.alpha_composite(subject, (target_bbox[0], target_bbox[1]))
        output.alpha_composite(cell, ((view_index % 4) * CELL_SIZE, (view_index // 4) * CELL_SIZE))

    args.output.parent.mkdir(parents=True, exist_ok=True)
    output.save(args.output, optimize=True)
    print(f"PROJECTION PASS: views={VIEW_COUNT} output={args.output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
