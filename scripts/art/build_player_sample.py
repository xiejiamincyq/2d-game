"""Build aligned 64px player sample strips from an 8-column by 3-row alpha sheet."""

from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image


COLUMN_COUNT = 8
ROW_NAMES = ("body", "weapon", "composite")
FRAME_SIZE = 64


def _cell_bounds(width: int, height: int, row: int, column: int) -> tuple[int, int, int, int]:
    return (
        round(column * width / COLUMN_COUNT),
        round(row * height / len(ROW_NAMES)),
        round((column + 1) * width / COLUMN_COUNT),
        round((row + 1) * height / len(ROW_NAMES)),
    )


def _fit_cell(cell: Image.Image, row_name: str, row: int, column: int) -> Image.Image:
    alpha_bounds = cell.getchannel("A").getbbox()
    if alpha_bounds is None:
        raise ValueError(f"empty sample cell at row {row} column {column}")
    subject = cell.crop(alpha_bounds)
    max_width, max_height = (56, 28) if row_name == "weapon" else (56, 56)
    scale = min(max_width / subject.width, max_height / subject.height)
    target_size = (
        max(1, round(subject.width * scale)),
        max(1, round(subject.height * scale)),
    )
    subject = subject.resize(target_size, Image.Resampling.LANCZOS)
    alpha = subject.getchannel("A").point(
        lambda value: 0 if value < 32 else 255 if value >= 224 else value
    )
    subject.putalpha(alpha)
    frame = Image.new("RGBA", (FRAME_SIZE, FRAME_SIZE), (0, 0, 0, 0))
    x = (FRAME_SIZE - subject.width) // 2
    y = (FRAME_SIZE - subject.height) // 2 if row_name == "weapon" else 60 - subject.height
    frame.alpha_composite(subject, (x, y))
    return frame


def build_sample_strips(source_path: Path, output_dir: Path) -> dict[str, Path]:
    output_dir.mkdir(parents=True, exist_ok=True)
    outputs: dict[str, Path] = {}
    with Image.open(source_path) as source_image:
        source = source_image.convert("RGBA")
        for row, row_name in enumerate(ROW_NAMES):
            atlas = Image.new(
                "RGBA",
                (COLUMN_COUNT * FRAME_SIZE, FRAME_SIZE),
                (0, 0, 0, 0),
            )
            for column in range(COLUMN_COUNT):
                cell = source.crop(_cell_bounds(source.width, source.height, row, column))
                frame = _fit_cell(cell, row_name, row, column)
                atlas.alpha_composite(frame, (column * FRAME_SIZE, 0))
            output_path = output_dir / f"player_b_sample_{row_name}_8dir.png"
            atlas.save(output_path)
            outputs[row_name] = output_path
    return outputs


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path)
    parser.add_argument("output_dir", type=Path)
    args = parser.parse_args()
    for name, path in build_sample_strips(args.source, args.output_dir).items():
        print(f"WROTE {name}: {path}")


if __name__ == "__main__":
    main()
