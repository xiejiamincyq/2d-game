"""Build 72 deterministic 5-degree player direction frames from the approved master."""

from __future__ import annotations

import math
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "assets/art/actors/player/player_base.png"
DIRECTIONS = ROOT / "assets/art/actors/player/directions"
ATLAS = ROOT / "assets/art/actors/player/player_directional_atlas.png"
PREVIEW = ROOT / "docs/art/previews/characters-combat/player-directional-runtime-preview-v1.png"
ATLAS_PREVIEW = ROOT / "docs/art/previews/characters-combat/player-directional-atlas-preview-v1.png"
WEAPON_PREVIEW = ROOT / "docs/art/previews/characters-combat/player-directional-weapon-preview-v1.png"

FRAME_SIZE = 64
FRAME_STEP_DEGREES = 5
FRAME_COUNT = 360 // FRAME_STEP_DEGREES
ATLAS_COLUMNS = 9
ATLAS_ROWS = 8
MAX_SUBJECT_DIAGONAL = 60.0
BACKGROUND = (6, 16, 25, 255)


def build_base_frame(source: Image.Image) -> Image.Image:
    alpha_bounds = source.getchannel("A").getbbox()
    if alpha_bounds is None:
        raise ValueError("player master has no visible pixels")
    subject = source.crop(alpha_bounds)
    diagonal = math.hypot(subject.width, subject.height)
    scale = MAX_SUBJECT_DIAGONAL / diagonal
    target_size = (
        max(1, round(subject.width * scale)),
        max(1, round(subject.height * scale)),
    )
    subject = subject.resize(target_size, Image.Resampling.LANCZOS)
    frame = Image.new("RGBA", (FRAME_SIZE, FRAME_SIZE), (0, 0, 0, 0))
    position = (
        (FRAME_SIZE - subject.width) // 2,
        (FRAME_SIZE - subject.height) // 2,
    )
    frame.alpha_composite(subject, position)
    return frame


def build_frames(base_frame: Image.Image) -> list[Image.Image]:
    return [
        base_frame.rotate(
            -frame * FRAME_STEP_DEGREES,
            resample=Image.Resampling.BICUBIC,
            expand=False,
        )
        for frame in range(FRAME_COUNT)
    ]


def write_frames(frames: list[Image.Image]) -> None:
    DIRECTIONS.mkdir(parents=True, exist_ok=True)
    expected_names = {
        f"angle_{frame * FRAME_STEP_DEGREES:03d}.png"
        for frame in range(FRAME_COUNT)
    }
    for existing in DIRECTIONS.glob("angle_*.png"):
        if existing.name not in expected_names:
            existing.unlink()
    for frame, image in enumerate(frames):
        angle = frame * FRAME_STEP_DEGREES
        image.save(DIRECTIONS / f"angle_{angle:03d}.png", optimize=True)


def write_atlas(frames: list[Image.Image]) -> None:
    atlas = Image.new(
        "RGBA",
        (ATLAS_COLUMNS * FRAME_SIZE, ATLAS_ROWS * FRAME_SIZE),
        (0, 0, 0, 0),
    )
    for frame, image in enumerate(frames):
        column = frame % ATLAS_COLUMNS
        row = frame // ATLAS_COLUMNS
        atlas.alpha_composite(image, (column * FRAME_SIZE, row * FRAME_SIZE))
    ATLAS.parent.mkdir(parents=True, exist_ok=True)
    atlas.save(ATLAS, optimize=True)


def write_previews(frames: list[Image.Image]) -> None:
    PREVIEW.parent.mkdir(parents=True, exist_ok=True)

    sample_indices = range(0, FRAME_COUNT, 6)
    sample_scale = 2
    sample_cell = FRAME_SIZE * sample_scale
    preview = Image.new("RGBA", (6 * sample_cell, 2 * sample_cell), BACKGROUND)
    for position, frame in enumerate(sample_indices):
        image = frames[frame].resize(
            (sample_cell, sample_cell), Image.Resampling.NEAREST
        )
        preview.alpha_composite(
            image,
            ((position % 6) * sample_cell, (position // 6) * sample_cell),
        )
    preview.convert("RGB").save(PREVIEW, optimize=True)

    atlas_scale = 2
    atlas_preview = Image.new(
        "RGBA",
        (
            ATLAS_COLUMNS * FRAME_SIZE * atlas_scale,
            ATLAS_ROWS * FRAME_SIZE * atlas_scale,
        ),
        BACKGROUND,
    )
    for frame, image in enumerate(frames):
        scaled = image.resize(
            (FRAME_SIZE * atlas_scale, FRAME_SIZE * atlas_scale),
            Image.Resampling.NEAREST,
        )
        atlas_preview.alpha_composite(
            scaled,
            (
                (frame % ATLAS_COLUMNS) * FRAME_SIZE * atlas_scale,
                (frame // ATLAS_COLUMNS) * FRAME_SIZE * atlas_scale,
            ),
        )
    atlas_preview.convert("RGB").save(ATLAS_PREVIEW, optimize=True)


def write_weapon_preview(frames: list[Image.Image], weapon_master: Image.Image) -> None:
    sample_indices = range(0, FRAME_COUNT, 6)
    composite_size = 96
    display_scale = 2
    display_size = composite_size * display_scale
    preview = Image.new("RGBA", (6 * display_size, 2 * display_size), BACKGROUND)
    weapon = weapon_master.resize((FRAME_SIZE, FRAME_SIZE), Image.Resampling.LANCZOS)

    for position, frame in enumerate(sample_indices):
        angle = frame * FRAME_STEP_DEGREES
        composite = Image.new("RGBA", (composite_size, composite_size), (0, 0, 0, 0))
        body_position = ((composite_size - FRAME_SIZE) // 2,) * 2
        composite.alpha_composite(frames[frame], body_position)

        weapon_layer = Image.new("RGBA", composite.size, (0, 0, 0, 0))
        center = composite_size // 2
        weapon_layer.alpha_composite(weapon, (center - 25, center - 34))
        weapon_layer = weapon_layer.rotate(
            -angle, resample=Image.Resampling.BICUBIC, expand=False
        )
        composite.alpha_composite(weapon_layer)

        displayed = composite.resize(
            (display_size, display_size), Image.Resampling.NEAREST
        )
        preview.alpha_composite(
            displayed,
            ((position % 6) * display_size, (position // 6) * display_size),
        )
    preview.convert("RGB").save(WEAPON_PREVIEW, optimize=True)


def main() -> None:
    source = Image.open(SOURCE).convert("RGBA")
    if source.size != (1024, 1024):
        raise ValueError(f"expected 1024x1024 player master, got {source.size}")
    frames = build_frames(build_base_frame(source))
    write_frames(frames)
    write_atlas(frames)
    write_previews(frames)
    weapon = Image.open(ROOT / "assets/art/actors/player/player_weapon.png").convert("RGBA")
    write_weapon_preview(frames, weapon)
    print(
        f"Built {len(frames)} frames at {FRAME_STEP_DEGREES}-degree steps, "
        f"atlas {ATLAS_COLUMNS * FRAME_SIZE}x{ATLAS_ROWS * FRAME_SIZE}."
    )


if __name__ == "__main__":
    main()
