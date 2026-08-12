import importlib.util
import tempfile
import unittest
from pathlib import Path

from PIL import Image

import yaml


SCRIPT_PATH = (
    Path(__file__).resolve().parents[1]
    / "art"
    / "generate_player_turnaround_model_mv.py"
)


def load_script():
    spec = importlib.util.spec_from_file_location(
        "generate_player_turnaround_model_mv", SCRIPT_PATH
    )
    module = importlib.util.module_from_spec(spec)
    assert spec.loader is not None
    spec.loader.exec_module(module)
    return module


class GeneratePlayerTurnaroundModelMVTest(unittest.TestCase):
    def test_validate_reference_alpha_rejects_fully_opaque_input(self):
        module = load_script()
        image = Image.new("RGBA", (32, 32), (255, 255, 255, 255))

        with self.assertRaisesRegex(RuntimeError, "fully opaque"):
            module.validate_reference_alpha(image, "front")

    def test_validate_reference_alpha_accepts_real_cutout(self):
        module = load_script()
        image = Image.new("RGBA", (32, 32), (255, 255, 255, 0))
        for x in range(8, 24):
            for y in range(4, 28):
                image.putpixel((x, y), (40, 40, 40, 255))

        module.validate_reference_alpha(image, "front")

    def test_prune_unused_vae_encoder_removes_unpublished_generation_weights(self):
        module = load_script()

        class FakeVAE:
            def __init__(self):
                self.encoder = object()
                self.pre_kl = object()

        vae = FakeVAE()
        module.prune_unused_vae_encoder(vae)

        self.assertFalse(hasattr(vae, "encoder"))
        self.assertFalse(hasattr(vae, "pre_kl"))

    def test_component_key_map_strips_only_the_requested_prefix(self):
        module = load_script()
        keys = [
            "conditioner.encoder.weight",
            "model.blocks.0.weight",
            "model.blocks.0.bias",
            "vae.decoder.weight",
        ]

        result = module.component_key_map(keys, "model")

        self.assertEqual(
            result,
            {
                "blocks.0.weight": "model.blocks.0.weight",
                "blocks.0.bias": "model.blocks.0.bias",
            },
        )

    def test_validate_source_root_requires_official_hy3dgen_package(self):
        module = load_script()
        with tempfile.TemporaryDirectory() as directory:
            source_root = Path(directory)
            official_package = source_root / "hy3dgen" / "shapegen"
            official_package.mkdir(parents=True)
            (official_package / "__init__.py").write_text("", encoding="utf-8")

            module.validate_source_root(source_root)

            wrong_root = source_root / "renamed-2.1-source"
            (wrong_root / "hy3dshape").mkdir(parents=True)
            with self.assertRaisesRegex(RuntimeError, "hy3dgen/shapegen"):
                module.validate_source_root(wrong_root)

    def test_build_image_paths_uses_three_approved_views_without_mirroring(self):
        module = load_script()
        paths = {
            "front": Path("front.png"),
            "back": Path("back.png"),
            "right": Path("right.png"),
        }

        result = module.build_image_paths(**paths, left=None)

        self.assertEqual(result, paths)

    def test_build_image_paths_inserts_optional_left_in_official_view_order(self):
        module = load_script()

        result = module.build_image_paths(
            front=Path("front.png"),
            left=Path("left.png"),
            back=Path("back.png"),
            right=Path("right.png"),
        )

        self.assertEqual(list(result), ["front", "left", "back", "right"])

    def test_build_image_paths_requires_at_least_one_side_view(self):
        module = load_script()

        with self.assertRaisesRegex(ValueError, "at least one side view"):
            module.build_image_paths(
                front=Path("front.png"),
                left=None,
                back=Path("back.png"),
                right=None,
            )

    def test_validate_config_requires_multiview_processor_and_encoder(self):
        module = load_script()
        valid = {
            "conditioner": {
                "params": {"main_image_encoder": {"type": "DinoImageEncoderMV"}}
            },
            "image_processor": {
                "target": "hy3dgen.shapegen.preprocessors.MVImageProcessorV2"
            },
        }
        module.validate_multiview_config(valid)

        invalid = yaml.safe_load(yaml.safe_dump(valid))
        invalid["image_processor"]["target"] = (
            "hy3dgen.shapegen.preprocessors.ImageProcessorV2"
        )
        with self.assertRaisesRegex(RuntimeError, "MVImageProcessorV2"):
            module.validate_multiview_config(invalid)


if __name__ == "__main__":
    unittest.main()
