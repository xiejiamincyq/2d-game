"""Generate the player's stable turnaround mesh with Hunyuan3D 2.1.

The model runtime and weights intentionally live outside the repository. This
script only writes the generated GLB requested through ``--output``.
"""

from __future__ import annotations

import argparse
import gc
import os
import sys
from pathlib import Path


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--image", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument(
        "--source-root",
        type=Path,
        default=Path.home() / ".codex/cache/Hunyuan3D-2.1-src/hy3dshape",
    )
    parser.add_argument(
        "--model-root",
        type=Path,
        default=Path.home() / ".codex/cache/hy3dgen/tencent/Hunyuan3D-2.1",
    )
    parser.add_argument("--seed", type=int, default=20260805)
    parser.add_argument("--steps", type=int, default=30)
    parser.add_argument("--octree-resolution", type=int, default=256)
    parser.add_argument("--num-chunks", type=int, default=2000)
    parser.add_argument("--load-only", action="store_true")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    if not args.image.is_file():
        raise FileNotFoundError(f"Input image not found: {args.image}")
    if not args.source_root.is_dir():
        raise FileNotFoundError(f"Hunyuan3D source not found: {args.source_root}")
    if not (args.model_root / "hunyuan3d-dit-v2-1/config.yaml").is_file():
        raise FileNotFoundError(f"Hunyuan3D model config not found: {args.model_root}")

    sys.path.insert(0, str(args.source_root))
    os.environ.setdefault("HY3DGEN_MODELS", str(args.model_root.parent.parent))

    import torch
    import yaml
    from PIL import Image
    from hy3dshape.pipelines import (
        Hunyuan3DDiTFlowMatchingPipeline,
        instantiate_from_config,
    )

    if not torch.cuda.is_available():
        raise RuntimeError("A CUDA GPU is required for Hunyuan3D shape generation")
    if "sm_120" not in torch.cuda.get_arch_list():
        raise RuntimeError("Installed PyTorch does not support this RTX 50-series GPU")

    image = Image.open(args.image).convert("RGBA")
    config_path = args.model_root / "hunyuan3d-dit-v2-1/config.yaml"
    checkpoint_path = args.model_root / "hunyuan3d-dit-v2-1/model.fp16.ckpt"
    if not checkpoint_path.is_file():
        raise FileNotFoundError(f"Hunyuan3D checkpoint not found: {checkpoint_path}")
    with config_path.open("r", encoding="utf-8") as config_file:
        config = yaml.safe_load(config_file)
    checkpoint = torch.load(
        checkpoint_path,
        map_location="cpu",
        weights_only=True,
        mmap=True,
    )
    # The official loader constructs a second full parameter set before copying
    # the 7.37 GB checkpoint. Meta initialization and assign=True keep the peak
    # within a 16 GB workstation while preserving the official architecture.
    with torch.device("meta"):
        model = instantiate_from_config(config["model"])
        vae = instantiate_from_config(config["vae"])
        conditioner = instantiate_from_config(config["conditioner"])
    model.load_state_dict(checkpoint["model"], assign=True)
    vae.load_state_dict(checkpoint["vae"], strict=False, assign=True)
    conditioner.load_state_dict(checkpoint["conditioner"], assign=True)
    vae.fourier_embedder.frequencies = 2.0 ** torch.arange(
        config["vae"]["params"]["num_freqs"],
        dtype=torch.float32,
    )
    for component_name, component in (
        ("model", model),
        ("vae", vae),
        ("conditioner", conditioner),
    ):
        unresolved = [
            name
            for name, tensor in (*component.named_parameters(), *component.named_buffers())
            if tensor.is_meta
        ]
        if unresolved:
            raise RuntimeError(
                f"{component_name} retained unresolved meta tensors: {unresolved[:5]}"
            )
    image_processor = instantiate_from_config(config["image_processor"])
    scheduler = instantiate_from_config(config["scheduler"])
    pipeline = Hunyuan3DDiTFlowMatchingPipeline(
        vae=vae,
        model=model,
        scheduler=scheduler,
        conditioner=conditioner,
        image_processor=image_processor,
        device="cpu",
        dtype=torch.float16,
        from_pretrained_kwargs={
            "model_path": str(args.model_root),
            "subfolder": "hunyuan3d-dit-v2-1",
            "use_safetensors": False,
            "variant": "fp16",
            "dtype": torch.float16,
            "device": "cpu",
        },
    )
    del checkpoint
    gc.collect()
    # Hunyuan3D 2.1 ships Diffusers-style offload methods but omits the
    # component registry they expect. Supply the exact official execution
    # sequence without patching the cached upstream source.
    pipeline.components = {
        "conditioner": pipeline.conditioner,
        "model": pipeline.model,
        "vae": pipeline.vae,
    }
    pipeline.enable_model_cpu_offload(device="cuda")
    # The upstream pipeline uses ``self.device`` for latent allocation even
    # after Accelerate installs CUDA execution hooks. Update only the logical
    # execution marker; the components remain CPU-offloaded by those hooks.
    pipeline.device = torch.device("cuda")
    if args.load_only:
        parameter_count = sum(
            parameter.numel()
            for component in (pipeline.model, pipeline.vae, pipeline.conditioner)
            for parameter in component.parameters()
        )
        print(f"LOADER PASS: parameters={parameter_count}")
        return 0

    generator = torch.Generator(device="cuda").manual_seed(args.seed)
    mesh = pipeline(
        image=image,
        generator=generator,
        num_inference_steps=args.steps,
        octree_resolution=args.octree_resolution,
        num_chunks=args.num_chunks,
        output_type="trimesh",
    )[0]
    if mesh is None or len(mesh.vertices) == 0 or len(mesh.faces) == 0:
        raise RuntimeError("Hunyuan3D returned an empty mesh")

    args.output.parent.mkdir(parents=True, exist_ok=True)
    mesh.export(args.output)
    if not args.output.is_file() or args.output.stat().st_size == 0:
        raise RuntimeError(f"Mesh export failed: {args.output}")
    print(
        "MODEL PASS:",
        f"vertices={len(mesh.vertices)}",
        f"faces={len(mesh.faces)}",
        f"output={args.output}",
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
