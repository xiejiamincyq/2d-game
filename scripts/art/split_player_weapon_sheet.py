"""Split the approved weapon orthographic sheet into canonical MV inputs."""

from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image


CANVAS_SIZE = (1024, 1024)
PANEL_BOUNDARIES = (0.0, 0.4346, 0.8374, 1.0)
PANEL_NAMES = ("front", "back", "right")


def split_sheet(source_path: Path, output_dir: Path) -> dict[str, Path]:
    with Image.open(source_path) as source_image:
        source = source_image.convert("RGBA")
    aspect_ratio = source.width / source.height
    if abs(aspect_ratio - 3.0) > 0.02:
        raise ValueError(
            "weapon sheet must use a 3:1 horizontal layout; "
            f"got {source.width}x{source.height}"
        )

    background = source.getpixel((0, 0))
    output_dir.mkdir(parents=True, exist_ok=True)
    outputs: dict[str, Path] = {}
    for index, view in enumerate(PANEL_NAMES):
        box = (
            round(source.width * PANEL_BOUNDARIES[index]),
            0,
            round(source.width * PANEL_BOUNDARIES[index + 1]),
            source.height,
        )
        panel = source.crop(box)
        available_width = CANVAS_SIZE[0] - 8
        available_height = CANVAS_SIZE[1] - 8
        scale = min(
            available_width / panel.width,
            available_height / panel.height,
            1.0,
        )
        if scale < 1.0:
            panel = panel.resize(
                (round(panel.width * scale), round(panel.height * scale)),
                Image.Resampling.LANCZOS,
            )
        canvas = Image.new("RGBA", CANVAS_SIZE, background)
        offset = (
            (CANVAS_SIZE[0] - panel.width) // 2,
            (CANVAS_SIZE[1] - panel.height) // 2,
        )
        canvas.alpha_composite(panel, offset)
        output_path = output_dir / f"player_weapon_modeling_{view}_v1.png"
        canvas.save(output_path)
        outputs[view] = output_path
    return outputs


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("source", type=Path)
    parser.add_argument("output_dir", type=Path)
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    outputs = split_sheet(args.source, args.output_dir)
    for view, path in outputs.items():
        print(f"WEAPON SPLIT PASS: {view}={path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
