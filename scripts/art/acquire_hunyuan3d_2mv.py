"""Acquire and verify the official Hunyuan3D-2mv shape checkpoint.

Weights are stored in an external Codex cache and must never be committed.
"""

from __future__ import annotations

import argparse
import hashlib
from pathlib import Path
from typing import Callable


REPO_ID = "tencent/Hunyuan3D-2mv"
MODEL_SUBFOLDER = "hunyuan3d-dit-v2-mv"
CHECKPOINT_SIZE = 4_928_151_562
CHECKPOINT_SHA256 = "d36f5881bcdc56726b73e517cd444c13c60732431622da7268145355c8d38e9c"
ALLOW_PATTERNS = [
    "LICENSE",
    "NOTICE",
    "README.md",
    f"{MODEL_SUBFOLDER}/config.yaml",
    f"{MODEL_SUBFOLDER}/model.fp16.safetensors",
]


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--target",
        type=Path,
        default=Path.home() / ".codex/cache/hy3dgen/tencent/Hunyuan3D-2mv",
    )
    parser.add_argument("--verify-only", action="store_true")
    return parser.parse_args()


def download_checkpoint(
    target: Path,
    snapshot_download: Callable[..., str],
) -> Path:
    target.mkdir(parents=True, exist_ok=True)
    result = snapshot_download(
        repo_id=REPO_ID,
        local_dir=str(target),
        allow_patterns=ALLOW_PATTERNS,
        max_workers=1,
    )
    return Path(result)


def validate_checkpoint(
    checkpoint: Path,
    *,
    expected_size: int = CHECKPOINT_SIZE,
    expected_sha256: str = CHECKPOINT_SHA256,
) -> str:
    if not checkpoint.is_file():
        raise FileNotFoundError(f"Checkpoint not found: {checkpoint}")
    actual_size = checkpoint.stat().st_size
    if actual_size != expected_size:
        raise RuntimeError(
            f"Checkpoint size mismatch: expected {expected_size}, got {actual_size}"
        )
    digest = hashlib.sha256()
    with checkpoint.open("rb") as checkpoint_file:
        for chunk in iter(lambda: checkpoint_file.read(8 * 1024 * 1024), b""):
            digest.update(chunk)
    actual_sha256 = digest.hexdigest()
    if actual_sha256 != expected_sha256:
        raise RuntimeError(
            "Checkpoint SHA256 mismatch: "
            f"expected {expected_sha256}, got {actual_sha256}"
        )
    return actual_sha256


def main() -> int:
    args = parse_args()
    if not args.verify_only:
        from huggingface_hub import snapshot_download

        print(f"DOWNLOAD START: repo={REPO_ID} target={args.target}", flush=True)
        download_checkpoint(args.target, snapshot_download)
        print("DOWNLOAD COMPLETE: starting SHA256 verification", flush=True)

    checkpoint = args.target / MODEL_SUBFOLDER / "model.fp16.safetensors"
    digest = validate_checkpoint(checkpoint)
    print(
        "CHECKPOINT PASS:",
        f"bytes={checkpoint.stat().st_size}",
        f"sha256={digest}",
        f"path={checkpoint}",
        flush=True,
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
