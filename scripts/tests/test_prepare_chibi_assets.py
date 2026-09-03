import unittest
from pathlib import Path

from PIL import Image, ImageDraw

from scripts.art.prepare_chibi_assets import (
    clean_generated_alpha,
    prepare_cardinal_atlas,
    prepare_single_sprite,
    validate_cardinal_atlas,
    validate_single_sprite,
)


ROOT = Path(__file__).resolve().parents[2]


class PrepareChibiAssetsTests(unittest.TestCase):
    def test_clean_generated_alpha_removes_halo_and_restores_opaque_core(self) -> None:
        source = Image.new("RGBA", (32, 32), (20, 40, 50, 0))
        alpha = source.getchannel("A")
        alpha.putpixel((2, 2), 24)
        alpha.putpixel((12, 12), 128)
        alpha.putpixel((16, 16), 254)
        source.putalpha(alpha)

        result = clean_generated_alpha(source)

        self.assertEqual(result.getpixel((2, 2))[3], 0)
        self.assertGreater(result.getpixel((12, 12))[3], 0)
        self.assertEqual(result.getpixel((16, 16))[3], 255)

    def test_single_sprite_is_centered_with_safe_padding(self) -> None:
        source = Image.new("RGBA", (240, 160), (0, 0, 0, 0))
        ImageDraw.Draw(source).rounded_rectangle((30, 20, 220, 150), 18, fill=(44, 170, 150, 254))

        result = prepare_single_sprite(source, canvas_size=128, padding=8)

        validate_single_sprite(result, canvas_size=128, safe_padding=8)
        self.assertEqual(result.size, (128, 128))

    def test_cardinal_atlas_packs_one_view_per_cell(self) -> None:
        source = Image.new("RGBA", (400, 300), (0, 0, 0, 0))
        draw = ImageDraw.Draw(source)
        for box in ((35, 20, 165, 135), (235, 25, 365, 140), (40, 165, 160, 285), (240, 160, 360, 280)):
            draw.rounded_rectangle(box, 16, fill=(44, 170, 150, 254))

        result = prepare_cardinal_atlas(source, cell_size=128, padding=8)

        validate_cardinal_atlas(result, cell_size=128, safe_padding=8)
        self.assertEqual(result.size, (256, 256))

    def test_production_chibi_assets_have_clean_alpha_and_safe_padding(self) -> None:
        player_atlas = ROOT / "assets/art/actors/player/player_chibi_b_cardinal_atlas_v1.png"
        with Image.open(player_atlas) as image:
            validate_cardinal_atlas(image, cell_size=128, safe_padding=8)

        for relative_path in (
            "assets/art/actors/player/player_chibi_b_weapon_v1.png",
            "assets/art/actors/enemies/enemy_scrapper_chibi_b_v1.png",
            "assets/art/actors/enemies/enemy_bruiser_chibi_b_v1.png",
            "assets/art/effects/combat_hit_chibi_b_v1.png",
        ):
            with Image.open(ROOT / relative_path) as image:
                validate_single_sprite(image, canvas_size=128, safe_padding=8)


if __name__ == "__main__":
    unittest.main()
