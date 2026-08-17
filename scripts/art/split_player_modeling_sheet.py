"""Split the approved Player A modeling sheet into canonical MV inputs."""

from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image


EXPECTED_SIZE = (1536, 1024)
CANVAS_SIZE = (1024, 1024)
PANELS = {
    "front": (0, 0, 560, 1024),
    "right": (570, 0, 970, 1024),
    "back": (970, 0, 1536, 1024),
}


def split_sheet(source_path: Path, output_dir: Path) -> dict[str, Path]:
    with Image.open(source_path) as source_image:
        source = source_image.convert("RGBA")
    if source.size != EXPECTED_SIZE:
        raise ValueError(
            f"modeling sheet must be 1536x1024; got {source.width}x{source.height}"
        )

    background = source.getpixel((0, 0))
    output_dir.mkdir(parents=True, exist_ok=True)
    outputs: dict[str, Path] = {}
    for view, box in PANELS.items():
        panel = source.crop(box)
        canvas = Image.new("RGBA", CANVAS_SIZE, background)
        offset_x = (CANVAS_SIZE[0] - panel.width) // 2
        canvas.alpha_composite(panel, (offset_x, 0))
        output_path = output_dir / f"player_a_modeling_{view}_v1.png"
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
        print(f"SPLIT PASS: {view}={path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
