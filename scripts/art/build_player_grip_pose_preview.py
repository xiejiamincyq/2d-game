"""Build 64px grip-pose frames and a three-candidate review board."""

from __future__ import annotations

import argparse
import math
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont


CANDIDATE_LABELS = ("A", "B", "C")
POSE_NAMES = ("READY", "MOVE", "FIRE")
FRAME_SIZE = 64


def _pose_bounds(source: Image.Image, label: str) -> list[tuple[int, int, int, int]]:
    alpha = source.getchannel("A")
    scale = min(1.0, 320 / max(source.size))
    small_size = (
        max(1, round(source.width * scale)),
        max(1, round(source.height * scale)),
    )
    mask = alpha.resize(small_size, Image.Resampling.BILINEAR).point(
        lambda value: 255 if value > 32 else 0
    )
    # Close tiny gaps between a hand, rifle, and body without joining neighboring poses.
    mask = mask.filter(ImageFilter.MaxFilter(5))
    width, height = mask.size
    pixels = mask.load()
    visited = bytearray(width * height)
    components: list[tuple[int, int, int, int, int]] = []

    for y in range(height):
        for x in range(width):
            index = y * width + x
            if visited[index] or pixels[x, y] == 0:
                continue
            visited[index] = 1
            stack = [(x, y)]
            left = right = x
            top = bottom = y
            area = 0
            while stack:
                current_x, current_y = stack.pop()
                area += 1
                left = min(left, current_x)
                right = max(right, current_x)
                top = min(top, current_y)
                bottom = max(bottom, current_y)
                for neighbor_y in range(max(0, current_y - 1), min(height, current_y + 2)):
                    for neighbor_x in range(max(0, current_x - 1), min(width, current_x + 2)):
                        neighbor_index = neighbor_y * width + neighbor_x
                        if visited[neighbor_index] or pixels[neighbor_x, neighbor_y] == 0:
                            continue
                        visited[neighbor_index] = 1
                        stack.append((neighbor_x, neighbor_y))
            components.append((area, left, top, right + 1, bottom + 1))

    largest_area = max((component[0] for component in components), default=0)
    minimum_area = max(20, round(largest_area * 0.2))
    subjects = [component for component in components if component[0] >= minimum_area]
    if len(subjects) != 3:
        raise ValueError(
            f"candidate {label} must contain exactly three poses; found {len(subjects)}"
        )

    bounds = [
        (
            max(0, math.floor(left / scale)),
            max(0, math.floor(top / scale)),
            min(source.width, math.ceil(right / scale)),
            min(source.height, math.ceil(bottom / scale)),
        )
        for _, left, top, right, bottom in subjects
    ]
    return sorted(bounds, key=lambda bounds_item: bounds_item[0])


def _fit_runtime_frame(subject: Image.Image) -> Image.Image:
    scale = min(58 / subject.width, 58 / subject.height)
    target = (
        max(1, round(subject.width * scale)),
        max(1, round(subject.height * scale)),
    )
    subject = subject.resize(target, Image.Resampling.LANCZOS)
    alpha = subject.getchannel("A").point(
        lambda value: 0 if value < 24 else 255 if value >= 232 else value
    )
    subject.putalpha(alpha)
    frame = Image.new("RGBA", (FRAME_SIZE, FRAME_SIZE), (0, 0, 0, 0))
    frame.alpha_composite(subject, ((FRAME_SIZE - subject.width) // 2, 62 - subject.height))
    return frame


def build_runtime_atlas(candidates: dict[str, Path], output_path: Path) -> Path:
    if tuple(candidates) != CANDIDATE_LABELS:
        raise ValueError("runtime atlas requires candidates A, B, and C in order")
    atlas = Image.new(
        "RGBA",
        (len(CANDIDATE_LABELS) * len(POSE_NAMES) * FRAME_SIZE, FRAME_SIZE),
        (0, 0, 0, 0),
    )
    for candidate_index, (label, source_path) in enumerate(candidates.items()):
        with Image.open(source_path) as source_image:
            source = source_image.convert("RGBA")
        for pose_index, bounds in enumerate(_pose_bounds(source, label)):
            frame = _fit_runtime_frame(source.crop(bounds))
            frame_index = candidate_index * len(POSE_NAMES) + pose_index
            atlas.alpha_composite(frame, (frame_index * FRAME_SIZE, 0))
    output_path.parent.mkdir(parents=True, exist_ok=True)
    atlas.save(output_path)
    return output_path


def _fit_sheet(source: Image.Image, size: tuple[int, int]) -> Image.Image:
    alpha_bounds = source.getchannel("A").getbbox()
    if alpha_bounds is None:
        raise ValueError("candidate sheet has no visible subject")
    subject = source.crop(alpha_bounds)
    scale = min(size[0] / subject.width, size[1] / subject.height)
    return subject.resize(
        (max(1, round(subject.width * scale)), max(1, round(subject.height * scale))),
        Image.Resampling.LANCZOS,
    )


def build_comparison_board(
    candidates: dict[str, Path],
    runtime_atlas_path: Path,
    output_path: Path,
) -> Path:
    if tuple(candidates) != CANDIDATE_LABELS:
        raise ValueError("comparison board requires candidates A, B, and C in order")
    board = Image.new("RGBA", (1280, 720), (4, 15, 24, 255))
    draw = ImageDraw.Draw(board)
    font = ImageFont.load_default()
    draw.text((32, 18), "PLAYER GRIP / ACTION LANGUAGE - 45 DEG CAMERA", fill=(51, 255, 242, 255), font=font)
    draw.text((32, 38), "BODY + RIFLE IDENTITY LOCKED / READY + MOVE + FIRE / 64PX CHECK", fill=(190, 214, 226, 255), font=font)

    with Image.open(runtime_atlas_path) as runtime_image:
        runtime = runtime_image.convert("RGBA")
    column_width = 400
    column_gap = 16
    start_x = 24
    focus = {
        "A": "STANDARD SHOULDER WELD",
        "B": "COMPACT CQB HIGH-READY",
        "C": "FORWARD SUPPORT / LONG BRACE",
    }
    for candidate_index, (label, source_path) in enumerate(candidates.items()):
        x = start_x + candidate_index * (column_width + column_gap)
        draw.rectangle((x, 70, x + column_width, 684), outline=(18, 56, 72, 255), width=1)
        draw.text((x + 12, 82), f"{label} / {focus[label]}", fill=(51, 255, 242, 255), font=font)
        with Image.open(source_path) as source_image:
            preview = _fit_sheet(source_image.convert("RGBA"), (376, 390))
        board.alpha_composite(preview, (x + (column_width - preview.width) // 2, 112 + (390 - preview.height) // 2))

        runtime_start = candidate_index * len(POSE_NAMES) * FRAME_SIZE
        for pose_index, pose_name in enumerate(POSE_NAMES):
            frame_x = x + 88 + pose_index * 80
            source_x = runtime_start + pose_index * FRAME_SIZE
            frame = runtime.crop((source_x, 0, source_x + FRAME_SIZE, FRAME_SIZE))
            board.alpha_composite(frame, (frame_x, 536))
            center = (frame_x + 32, 568)
            draw.ellipse(
                (center[0] - 13, center[1] - 13, center[0] + 13, center[1] + 13),
                outline=(255, 87, 31, 210),
                width=1,
            )
            draw.line((center[0] - 4, center[1], center[0] + 4, center[1]), fill=(255, 255, 255, 220), width=1)
            draw.line((center[0], center[1] - 4, center[0], center[1] + 4), fill=(255, 255, 255, 220), width=1)
            draw.text((frame_x + 16, 610), pose_name, fill=(190, 214, 226, 255), font=font)
        draw.text((x + 12, 650), "64PX + 13PX COLLISION MARKER", fill=(255, 87, 31, 255), font=font)

    output_path.parent.mkdir(parents=True, exist_ok=True)
    board.save(output_path)
    return output_path


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--a", type=Path, required=True)
    parser.add_argument("--b", type=Path, required=True)
    parser.add_argument("--c", type=Path, required=True)
    parser.add_argument("--runtime", type=Path, required=True)
    parser.add_argument("--board", type=Path, required=True)
    args = parser.parse_args()
    candidates = {"A": args.a, "B": args.b, "C": args.c}
    build_runtime_atlas(candidates, args.runtime)
    build_comparison_board(candidates, args.runtime, args.board)
    print(f"GRIP PREVIEW PASS: runtime={args.runtime} board={args.board}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
