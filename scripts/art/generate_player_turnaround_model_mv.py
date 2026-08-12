"""Generate a review-only player body mesh from approved multi-view references."""

from __future__ import annotations

import argparse
import os
import sys
from pathlib import Path


MODEL_SUBFOLDER = "hunyuan3d-dit-v2-mv"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--front", type=Path, required=True)
    parser.add_argument("--left", type=Path)
    parser.add_argument("--back", type=Path, required=True)
    parser.add_argument("--right", type=Path, required=True)
    parser.add_argument("--output", type=Path)
    parser.add_argument(
        "--source-root",
        type=Path,
        default=Path.home() / ".codex/cache/Hunyuan3D-2-src",
    )
    parser.add_argument(
        "--model-root",
        type=Path,
        default=Path.home() / ".codex/cache/hy3dgen/tencent/Hunyuan3D-2mv",
    )
    parser.add_argument("--seed", type=int, default=20260812)
    parser.add_argument("--steps", type=int, default=30)
    parser.add_argument("--octree-resolution", type=int, default=256)
    parser.add_argument("--num-chunks", type=int, default=2000)
    parser.add_argument("--load-only", action="store_true")
    return parser.parse_args()


def build_image_paths(
    *,
    front: Path,
    left: Path | None,
    back: Path,
    right: Path,
) -> dict[str, Path]:
    paths = {"front": front}
    if left is not None:
        paths["left"] = left
    paths["back"] = back
    paths["right"] = right
    return paths


def validate_multiview_config(config: dict) -> None:
    processor = config.get("image_processor", {}).get("target", "")
    if not processor.endswith("MVImageProcessorV2"):
        raise RuntimeError(
            "Official multi-view config must use MVImageProcessorV2; "
            f"got {processor or 'missing'}"
        )
    encoder = (
        config.get("conditioner", {})
        .get("params", {})
        .get("main_image_encoder", {})
        .get("type", "")
    )
    if encoder != "DinoImageEncoderMV":
        raise RuntimeError(
            "Official multi-view config must use DinoImageEncoderMV; "
            f"got {encoder or 'missing'}"
        )


def validate_source_root(source_root: Path) -> None:
    package = source_root / "hy3dgen" / "shapegen" / "__init__.py"
    if not package.is_file():
        raise RuntimeError(
            "Official Hunyuan3D-2 source must contain hy3dgen/shapegen; "
            f"got {source_root}"
        )


def main() -> int:
    args = parse_args()
    image_paths = build_image_paths(
        front=args.front,
        left=args.left,
        back=args.back,
        right=args.right,
    )
    for view, path in image_paths.items():
        if not path.is_file():
            raise FileNotFoundError(f"{view} reference not found: {path}")
    if not args.load_only and args.output is None:
        raise ValueError("--output is required unless --load-only is used")
    validate_source_root(args.source_root)

    config_path = args.model_root / MODEL_SUBFOLDER / "config.yaml"
    checkpoint_path = args.model_root / MODEL_SUBFOLDER / "model.fp16.safetensors"
    if not config_path.is_file():
        raise FileNotFoundError(f"Multi-view config not found: {config_path}")
    if not checkpoint_path.is_file():
        raise FileNotFoundError(f"Multi-view checkpoint not found: {checkpoint_path}")

    import yaml

    with config_path.open("r", encoding="utf-8") as config_file:
        config = yaml.safe_load(config_file)
    validate_multiview_config(config)

    sys.path.insert(0, str(args.source_root))
    os.environ.setdefault("HY3DGEN_MODELS", str(args.model_root.parent.parent))

    import torch
    from PIL import Image
    from hy3dgen.shapegen import Hunyuan3DDiTFlowMatchingPipeline

    if not torch.cuda.is_available():
        raise RuntimeError("A CUDA GPU is required for Hunyuan3D shape generation")
    if "sm_120" not in torch.cuda.get_arch_list():
        raise RuntimeError("Installed PyTorch does not support this RTX 50-series GPU")

    images = {
        view: Image.open(path).convert("RGBA")
        for view, path in image_paths.items()
    }
    pipeline = Hunyuan3DDiTFlowMatchingPipeline.from_pretrained(
        str(args.model_root),
        device="cpu",
        dtype=torch.float16,
        use_safetensors=True,
        variant="fp16",
        subfolder=MODEL_SUBFOLDER,
    )
    if pipeline.image_processor.__class__.__name__ != "MVImageProcessorV2":
        raise RuntimeError("Loaded pipeline silently fell back to a single-view processor")
    pipeline.components = {
        "conditioner": pipeline.conditioner,
        "model": pipeline.model,
        "vae": pipeline.vae,
    }
    pipeline.enable_model_cpu_offload(device="cuda")
    pipeline.device = torch.device("cuda")

    processed = pipeline.image_processor(images)
    expected_view_indices = tuple(
        {"front": 0, "left": 1, "back": 2, "right": 3}[view]
        for view in image_paths
    )
    if tuple(processed["view_idxs"]) != expected_view_indices:
        raise RuntimeError(
            "Multi-view processor returned unexpected view indices: "
            f"{processed['view_idxs']}"
        )
    if args.load_only:
        parameter_count = sum(
            parameter.numel()
            for component in (pipeline.model, pipeline.vae, pipeline.conditioner)
            for parameter in component.parameters()
        )
        print(
            "MULTIVIEW LOADER PASS:",
            f"parameters={parameter_count}",
            f"views={','.join(image_paths)}",
        )
        return 0

    generator = torch.Generator(device="cuda").manual_seed(args.seed)
    mesh = pipeline(
        image=images,
        generator=generator,
        num_inference_steps=args.steps,
        octree_resolution=args.octree_resolution,
        num_chunks=args.num_chunks,
        output_type="trimesh",
    )[0]
    if mesh is None or len(mesh.vertices) == 0 or len(mesh.faces) == 0:
        raise RuntimeError("Hunyuan3D-2mv returned an empty mesh")

    args.output.parent.mkdir(parents=True, exist_ok=True)
    mesh.export(args.output)
    if not args.output.is_file() or args.output.stat().st_size == 0:
        raise RuntimeError(f"Mesh export failed: {args.output}")
    print(
        "MULTIVIEW MODEL PASS:",
        f"vertices={len(mesh.vertices)}",
        f"faces={len(mesh.faces)}",
        f"views={','.join(image_paths)}",
        f"output={args.output}",
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
