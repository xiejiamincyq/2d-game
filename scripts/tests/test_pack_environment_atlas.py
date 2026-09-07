import unittest

from PIL import Image

from scripts.art.prepare_chibi_assets import pack_regions_without_scaling


class EnvironmentAtlasPackingTest(unittest.TestCase):
    def test_regions_keep_exact_rgba_bytes_and_size(self):
        source = Image.new("RGBA", (12, 8), (11, 22, 33, 127))
        source.putpixel((2, 1), (111, 222, 33, 254))
        regions = [(1, 1, 4, 3), (6, 0, 3, 6), (0, 5, 5, 3), (10, 2, 2, 2)]
        packed, targets = pack_regions_without_scaling(source, regions, cell_size=8, padding=1)
        self.assertEqual(packed.size, (16, 16))
        self.assertEqual(packed.getpixel((0, 0)), (0, 0, 0, 0))
        for before, after in zip(regions, targets):
            x, y, w, h = before
            tx, ty, tw, th = after
            self.assertEqual((w, h), (tw, th))
            self.assertEqual(source.crop((x, y, x+w, y+h)).tobytes(),
                             packed.crop((tx, ty, tx+tw, ty+th)).tobytes())

    def test_rejects_out_of_bounds_or_oversize_regions(self):
        source = Image.new("RGBA", (12, 8))
        for region in [(10, 0, 4, 2), (0, 0, 8, 3), (-1, 0, 3, 3)]:
            with self.assertRaises(ValueError):
                pack_regions_without_scaling(source, [region] * 4, cell_size=8, padding=1)


if __name__ == "__main__":
    unittest.main()
