"""Build one layered 64px player action slice with stable weapon sockets."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))
from scripts.art.build_player_action_preview import build_action_atlas


ACTIONS = ("idle", "run", "fire", "dash", "hit")
FRAME_SIZE = 64
FRAMES_PER_ACTION = 6
WEAPON_DIRECTION_INDEX = 1
GRIP_POSITIONS = {
    "idle": ((34, 31), (34, 31), (35, 31), (34, 31), (33, 32), (34, 32)),
    "run": ((35, 33), (35, 31), (36, 31), (34, 30), (33, 32), (35, 33)),
    "fire": ((35, 30), (34, 29), (33, 29), (33, 29), (34, 30), (35, 30)),
    "dash": ((36, 31), (36, 31), (36, 31), (36, 31), (35, 32), (34, 31)),
    "hit": ((34, 29), (33, 29), (32, 30), (31, 31), (32, 31), (34, 31)),
}


def _weapon_template(
    weapon_source_path: Path,
) -> tuple[Image.Image, Image.Image, tuple[int, int], tuple[int, int]]:
    with Image.open(weapon_source_path) as source_image:
        source = source_image.convert("RGBA")
        if source.size == (512, 64):
            left = WEAPON_DIRECTION_INDEX * FRAME_SIZE
            weapon = source.crop((left, 0, left + FRAME_SIZE, FRAME_SIZE))
        else:
            weapon = source
    bounds = weapon.getchannel("A").getbbox()
    if bounds is None:
        raise ValueError(f"weapon direction {WEAPON_DIRECTION_INDEX} is empty")

    subject = weapon.crop(bounds)
    scale = min(34 / subject.width, 20 / subject.height)
    if scale != 1.0:
        subject = subject.resize(
            (max(1, round(subject.width * scale)), max(1, round(subject.height * scale))),
            Image.Resampling.LANCZOS,
        )
    weapon = Image.new("RGBA", (FRAME_SIZE, FRAME_SIZE), (0, 0, 0, 0))
    weapon.alpha_composite(subject, ((FRAME_SIZE - subject.width) // 2, (FRAME_SIZE - subject.height) // 2))
    bounds = weapon.getchannel("A").getbbox()
    assert bounds is not None

    grip_x = bounds[0] + round((bounds[2] - bounds[0]) * 0.42)
    grip_pixels = [
        (x, y)
        for x in range(max(bounds[0], grip_x - 1), min(bounds[2], grip_x + 2))
        for y in range(bounds[1], bounds[3])
        if weapon.getpixel((x, y))[3] > 32
    ]
    grip_y = round(sum(y for _x, y in grip_pixels) / len(grip_pixels)) if grip_pixels else (bounds[1] + bounds[3]) // 2

    muzzle_x = bounds[2] - 1
    muzzle_pixels = [
        (x, y)
        for x in range(max(bounds[0], muzzle_x - 2), bounds[2])
        for y in range(bounds[1], bounds[3])
        if weapon.getpixel((x, y))[3] > 32
    ]
    muzzle_y = round(sum(y for _x, y in muzzle_pixels) / len(muzzle_pixels))

    behind = Image.new("RGBA", weapon.size, (0, 0, 0, 0))
    front = Image.new("RGBA", weapon.size, (0, 0, 0, 0))
    behind.alpha_composite(weapon.crop((0, 0, grip_x + 1, FRAME_SIZE)), (0, 0))
    front.alpha_composite(weapon.crop((grip_x + 1, 0, FRAME_SIZE, FRAME_SIZE)), (grip_x + 1, 0))
    return behind, front, (grip_x, grip_y), (muzzle_x - grip_x, muzzle_y - grip_y)


def _shifted(template: Image.Image, grip: tuple[int, int], template_grip: tuple[int, int]) -> Image.Image:
    frame = Image.new("RGBA", (FRAME_SIZE, FRAME_SIZE), (0, 0, 0, 0))
    frame.alpha_composite(template, (grip[0] - template_grip[0], grip[1] - template_grip[1]))
    return frame


def build_action_slice(body_source: Path, weapon_atlas: Path, output_dir: Path) -> dict[str, Path]:
    output_dir.mkdir(parents=True, exist_ok=True)
    stem = "player_b_action_slice_down_right"
    body_path = output_dir / f"{stem}_body.png"
    build_action_atlas(body_source, body_path)

    behind_template, front_template, template_grip, muzzle_vector = _weapon_template(weapon_atlas)
    atlases = {
        "weapon_behind": Image.new("RGBA", (384, 320), (0, 0, 0, 0)),
        "weapon_front": Image.new("RGBA", (384, 320), (0, 0, 0, 0)),
    }
    socket_actions: dict[str, list[dict[str, list[int]]]] = {}
    for action_index, action in enumerate(ACTIONS):
        frames: list[dict[str, list[int]]] = []
        for frame_index, grip in enumerate(GRIP_POSITIONS[action]):
            destination = (frame_index * FRAME_SIZE, action_index * FRAME_SIZE)
            atlases["weapon_behind"].alpha_composite(_shifted(behind_template, grip, template_grip), destination)
            atlases["weapon_front"].alpha_composite(_shifted(front_template, grip, template_grip), destination)
            muzzle = (grip[0] + muzzle_vector[0], grip[1] + muzzle_vector[1])
            frames.append({"grip": list(grip), "muzzle": list(muzzle)})
        socket_actions[action] = frames

    outputs: dict[str, Path] = {"body": body_path}
    for name, atlas in atlases.items():
        path = output_dir / f"{stem}_{name}.png"
        atlas.save(path)
        outputs[name] = path

    with Image.open(body_path) as body_image:
        composite = Image.new("RGBA", body_image.size, (0, 0, 0, 0))
        composite.alpha_composite(atlases["weapon_behind"])
        composite.alpha_composite(body_image.convert("RGBA"))
        composite.alpha_composite(atlases["weapon_front"])
    composite_path = output_dir / f"{stem}_composite.png"
    composite.save(composite_path)
    outputs["composite"] = composite_path

    sockets_path = output_dir / f"{stem}_sockets.json"
    sockets_path.write_text(
        json.dumps(
            {
                "schema_version": 1,
                "facing": "down_right",
                "frame_size": [FRAME_SIZE, FRAME_SIZE],
                "layer_order": ["weapon_behind", "body", "weapon_front"],
                "actions": socket_actions,
            },
            ensure_ascii=False,
            indent=2,
        ) + "\n",
        encoding="utf-8",
    )
    outputs["sockets"] = sockets_path
    return outputs


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("body_source", type=Path)
    parser.add_argument("weapon_atlas", type=Path)
    parser.add_argument("output_dir", type=Path)
    args = parser.parse_args()
    for name, path in build_action_slice(args.body_source, args.weapon_atlas, args.output_dir).items():
        print(f"WROTE {name}: {path}")


if __name__ == "__main__":
    main()
