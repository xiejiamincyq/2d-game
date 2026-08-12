"""Build three 64px layered cardinal player previews from approved sources."""

from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image


DIRECTIONS = ("front", "side_right", "rear")
DIRECTION_COLUMNS = {"front": 2, "side_right": 4, "rear": 6}
FRAME_SIZE = 64


def _fit_body(source_path: Path) -> Image.Image:
    with Image.open(source_path) as source_image:
        source = source_image.convert("RGBA")
    bounds = source.getchannel("A").getbbox()
    if bounds is None:
        raise ValueError(f"empty player body: {source_path}")
    subject = source.crop(bounds)
    scale = min(56 / subject.width, 58 / subject.height)
    subject = subject.resize(
        (max(1, round(subject.width * scale)), max(1, round(subject.height * scale))),
        Image.Resampling.LANCZOS,
    )
    frame = Image.new("RGBA", (FRAME_SIZE, FRAME_SIZE), (0, 0, 0, 0))
    frame.alpha_composite(subject, ((FRAME_SIZE - subject.width) // 2, 61 - subject.height))
    return frame


def _weapon_frame(atlas: Image.Image, direction: str) -> Image.Image:
    column = DIRECTION_COLUMNS[direction]
    return atlas.crop((column * FRAME_SIZE, 0, (column + 1) * FRAME_SIZE, FRAME_SIZE))


def _split_weapon(weapon: Image.Image, direction: str) -> tuple[Image.Image, Image.Image]:
    behind = Image.new("RGBA", weapon.size, (0, 0, 0, 0))
    front = Image.new("RGBA", weapon.size, (0, 0, 0, 0))
    if direction == "front":
        front.alpha_composite(weapon)
    elif direction == "rear":
        behind.alpha_composite(weapon)
    else:
        split_x = FRAME_SIZE // 2
        behind.alpha_composite(weapon.crop((0, 0, split_x, FRAME_SIZE)), (0, 0))
        front.alpha_composite(weapon.crop((split_x, 0, FRAME_SIZE, FRAME_SIZE)), (split_x, 0))
    return behind, front


def build_cardinal_previews(
    body_paths: dict[str, Path], weapon_atlas_path: Path, output_dir: Path
) -> dict[str, Path]:
    if set(body_paths) != set(DIRECTIONS):
        raise ValueError(f"body paths must contain exactly: {', '.join(DIRECTIONS)}")
    output_dir.mkdir(parents=True, exist_ok=True)
    atlases = {
        name: Image.new("RGBA", (len(DIRECTIONS) * FRAME_SIZE, FRAME_SIZE), (0, 0, 0, 0))
        for name in ("body", "weapon_behind", "weapon_front")
    }
    with Image.open(weapon_atlas_path) as weapon_image:
        weapon_atlas = weapon_image.convert("RGBA")
    if weapon_atlas.size != (512, 64):
        raise ValueError(f"weapon atlas must be 512x64, got {weapon_atlas.size}")

    for index, direction in enumerate(DIRECTIONS):
        destination = (index * FRAME_SIZE, 0)
        body = _fit_body(body_paths[direction])
        behind, front = _split_weapon(_weapon_frame(weapon_atlas, direction), direction)
        atlases["body"].alpha_composite(body, destination)
        atlases["weapon_behind"].alpha_composite(behind, destination)
        atlases["weapon_front"].alpha_composite(front, destination)

    composite = Image.new("RGBA", atlases["body"].size, (0, 0, 0, 0))
    composite.alpha_composite(atlases["weapon_behind"])
    composite.alpha_composite(atlases["body"])
    composite.alpha_composite(atlases["weapon_front"])
    atlases["composite"] = composite

    outputs = {}
    stem = "player_b_cardinal_layered_preview"
    for name, atlas in atlases.items():
        output_path = output_dir / f"{stem}_{name}.png"
        atlas.save(output_path)
        outputs[name] = output_path
    return outputs


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("front", type=Path)
    parser.add_argument("side_right", type=Path)
    parser.add_argument("rear", type=Path)
    parser.add_argument("weapon_atlas", type=Path)
    parser.add_argument("output_dir", type=Path)
    args = parser.parse_args()
    body_paths = {direction: getattr(args, direction) for direction in DIRECTIONS}
    for name, path in build_cardinal_previews(body_paths, args.weapon_atlas, args.output_dir).items():
        print(f"WROTE {name}: {path}")


if __name__ == "__main__":
    main()
