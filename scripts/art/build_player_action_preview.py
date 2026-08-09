"""Pack 6x5 player motion studies into 64px atlases and one review board."""

from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


COLUMN_COUNT = 6
ROW_NAMES = ("IDLE", "RUN", "FIRE", "DASH", "HIT")
FRAME_SIZE = 64


def _frame_centers(row_image: Image.Image, row: int) -> list[int]:
    alpha = row_image.getchannel("A")
    threshold = max(4, round(row_image.height * 0.04))
    counts = [
        sum(1 for y in range(row_image.height) if alpha.getpixel((x, y)) > 32)
        for x in range(row_image.width)
    ]
    runs: list[tuple[int, int, int]] = []
    start: int | None = None
    for x, count in enumerate(counts + [0]):
        if count >= threshold and start is None:
            start = x
        elif count < threshold and start is not None:
            runs.append((start, x, sum(counts[start:x])))
            start = None
    subjects = sorted(runs, key=lambda run: run[2], reverse=True)[:COLUMN_COUNT]
    if len(subjects) != COLUMN_COUNT:
        detected_centers = sorted((left + right) // 2 for left, right, _mass in subjects)
        missing_column = len(subjects)
        if len(detected_centers) == COLUMN_COUNT - 1:
            gaps = [right - left for left, right in zip(detected_centers, detected_centers[1:])]
            typical_gap = sorted(gaps)[len(gaps) // 2]
            widest_gap = max(gaps)
            if widest_gap >= typical_gap * 1.5:
                missing_column = gaps.index(widest_gap) + 1
            elif detected_centers[0] > typical_gap * 1.25:
                missing_column = 0
        raise ValueError(f"empty action cell at row {row} column {missing_column}")
    return sorted((left + right) // 2 for left, right, _mass in subjects)


def _frame_bounds(width: int, centers: list[int]) -> list[tuple[int, int]]:
    boundaries = [0]
    boundaries.extend((left + right) // 2 for left, right in zip(centers, centers[1:]))
    boundaries.append(width)
    return list(zip(boundaries, boundaries[1:]))


def _fit_cell(cell: Image.Image, row: int, column: int) -> Image.Image:
    alpha_bounds = cell.getchannel("A").getbbox()
    if alpha_bounds is None:
        raise ValueError(f"empty action cell at row {row} column {column}")
    subject = cell.crop(alpha_bounds)
    scale = min(58 / subject.width, 58 / subject.height)
    target_size = (
        max(1, round(subject.width * scale)),
        max(1, round(subject.height * scale)),
    )
    subject = subject.resize(target_size, Image.Resampling.LANCZOS)
    alpha = subject.getchannel("A").point(
        lambda value: 0 if value < 24 else 255 if value >= 232 else value
    )
    subject.putalpha(alpha)
    frame = Image.new("RGBA", (FRAME_SIZE, FRAME_SIZE), (0, 0, 0, 0))
    frame.alpha_composite(subject, ((FRAME_SIZE - subject.width) // 2, 62 - subject.height))
    return frame


def build_action_atlas(source_path: Path, output_path: Path) -> Path:
    output_path.parent.mkdir(parents=True, exist_ok=True)
    atlas = Image.new(
        "RGBA",
        (COLUMN_COUNT * FRAME_SIZE, len(ROW_NAMES) * FRAME_SIZE),
        (0, 0, 0, 0),
    )
    with Image.open(source_path) as source_image:
        source = source_image.convert("RGBA")
        for row in range(len(ROW_NAMES)):
            top = round(row * source.height / len(ROW_NAMES))
            bottom = round((row + 1) * source.height / len(ROW_NAMES))
            row_image = source.crop((0, top, source.width, bottom))
            centers = _frame_centers(row_image, row)
            frame_bounds = _frame_bounds(source.width, centers)
            for column in range(COLUMN_COUNT):
                left, right = frame_bounds[column]
                cell = row_image.crop((left, 0, right, row_image.height))
                frame = _fit_cell(cell, row, column)
                atlas.alpha_composite(frame, (column * FRAME_SIZE, row * FRAME_SIZE))
    atlas.save(output_path)
    return output_path


def build_comparison_board(candidates: dict[str, Path], output_path: Path) -> Path:
    if tuple(candidates) != ("A", "B", "C"):
        raise ValueError("comparison board requires candidates A, B, and C in order")
    output_path.parent.mkdir(parents=True, exist_ok=True)
    board = Image.new("RGBA", (1280, 448), (4, 15, 24, 255))
    draw = ImageDraw.Draw(board)
    font = ImageFont.load_default()
    start_x, start_y, gap = 96, 64, 16
    for row, row_name in enumerate(ROW_NAMES):
        y = start_y + row * FRAME_SIZE
        draw.text((12, y + 27), row_name, fill=(190, 214, 226, 255), font=font)
        draw.line((start_x, y, 1280, y), fill=(18, 46, 60, 255), width=1)
    for candidate_index, (label, atlas_path) in enumerate(candidates.items()):
        x = start_x + candidate_index * (COLUMN_COUNT * FRAME_SIZE + gap)
        with Image.open(atlas_path) as atlas_image:
            board.alpha_composite(atlas_image.convert("RGBA"), (x, start_y))
        draw.text((x + 188, 26), label, fill=(51, 255, 242, 255), font=font)
        for column in range(COLUMN_COUNT + 1):
            grid_x = x + column * FRAME_SIZE
            draw.line((grid_x, start_y, grid_x, start_y + 320), fill=(13, 35, 48, 255), width=1)
    draw.line((start_x, start_y + 320, 1280, start_y + 320), fill=(18, 46, 60, 255), width=1)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    board.save(output_path)
    return output_path


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--a", required=True, type=Path)
    parser.add_argument("--b", required=True, type=Path)
    parser.add_argument("--c", required=True, type=Path)
    parser.add_argument("--output-dir", required=True, type=Path)
    args = parser.parse_args()

    atlases: dict[str, Path] = {}
    for label, source in (("A", args.a), ("B", args.b), ("C", args.c)):
        output = args.output_dir / f"player_b_action_motion_preview_{label.lower()}_64.png"
        atlases[label] = build_action_atlas(source, output)
        print(f"WROTE {label}: {output}")
    comparison = build_comparison_board(
        atlases,
        args.output_dir / "player-b-action-motion-comparison-64-v1.png",
    )
    print(f"WROTE comparison: {comparison}")


if __name__ == "__main__":
    main()
