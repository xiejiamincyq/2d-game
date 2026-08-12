import importlib.util
import tempfile
import unittest
from pathlib import Path

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
