import hashlib
import importlib.util
import tempfile
import unittest
from pathlib import Path


SCRIPT_PATH = (
    Path(__file__).resolve().parents[1]
    / "art"
    / "acquire_hunyuan3d_2mv.py"
)


def load_script():
    spec = importlib.util.spec_from_file_location("acquire_hunyuan3d_2mv", SCRIPT_PATH)
    module = importlib.util.module_from_spec(spec)
    assert spec.loader is not None
    spec.loader.exec_module(module)
    return module


class AcquireHunyuan3D2MVTest(unittest.TestCase):
    def test_download_requests_only_the_official_multiview_checkpoint(self):
        module = load_script()
        calls = []

        def fake_snapshot_download(**kwargs):
            calls.append(kwargs)
            return kwargs["local_dir"]

        with tempfile.TemporaryDirectory() as directory:
            target = Path(directory)
            result = module.download_checkpoint(target, fake_snapshot_download)

        self.assertEqual(result, target)
        self.assertEqual(len(calls), 1)
        self.assertEqual(calls[0]["repo_id"], "tencent/Hunyuan3D-2mv")
        self.assertEqual(calls[0]["local_dir"], str(target))
        self.assertEqual(calls[0]["max_workers"], 1)
        self.assertEqual(
            calls[0]["allow_patterns"],
            [
                "LICENSE",
                "NOTICE",
                "README.md",
                "hunyuan3d-dit-v2-mv/config.yaml",
                "hunyuan3d-dit-v2-mv/model.fp16.safetensors",
            ],
        )

    def test_validate_checkpoint_rejects_wrong_size_before_hashing(self):
        module = load_script()
        with tempfile.TemporaryDirectory() as directory:
            checkpoint = Path(directory) / "model.fp16.safetensors"
            checkpoint.write_bytes(b"wrong")

            with self.assertRaisesRegex(RuntimeError, "size mismatch"):
                module.validate_checkpoint(checkpoint, expected_size=6, expected_sha256="unused")

    def test_validate_checkpoint_accepts_matching_size_and_sha256(self):
        module = load_script()
        payload = b"official multiview checkpoint fixture"
        digest = hashlib.sha256(payload).hexdigest()
        with tempfile.TemporaryDirectory() as directory:
            checkpoint = Path(directory) / "model.fp16.safetensors"
            checkpoint.write_bytes(payload)

            result = module.validate_checkpoint(
                checkpoint,
                expected_size=len(payload),
                expected_sha256=digest,
            )

        self.assertEqual(result, digest)


if __name__ == "__main__":
    unittest.main()
