"""Repack six disconnected animation poses into a strict 3x2 sprite grid."""

from __future__ import annotations

import argparse
from collections import deque
from pathlib import Path

from PIL import Image, ImageChops, ImageColor, ImageFilter


class Component:
    def __init__(
        self,
        pixels: list[tuple[int, int]],
        bbox: tuple[int, int, int, int],
        center: tuple[float, float],
    ) -> None:
        self.pixels = pixels
        self.bbox = bbox
        self.center = center


def find_components(image: Image.Image, minimum_area: int = 1000) -> list[Component]:
    rgba = image.convert("RGBA")
    width, height = rgba.size
    alpha = rgba.getchannel("A")
    alpha_pixels = alpha.load()
    visited = bytearray(width * height)
    components: list[Component] = []

    for y in range(height):
        for x in range(width):
            index = y * width + x
            if visited[index] or alpha_pixels[x, y] == 0:
                continue
            visited[index] = 1
            queue: deque[tuple[int, int]] = deque([(x, y)])
            pixels: list[tuple[int, int]] = []
            left = right = x
            top = bottom = y
            while queue:
                px, py = queue.popleft()
                pixels.append((px, py))
                left = min(left, px)
                right = max(right, px)
                top = min(top, py)
                bottom = max(bottom, py)
                for nx, ny in ((px - 1, py), (px + 1, py), (px, py - 1), (px, py + 1)):
                    if nx < 0 or nx >= width or ny < 0 or ny >= height:
                        continue
                    neighbor = ny * width + nx
                    if visited[neighbor] or alpha_pixels[nx, ny] == 0:
                        continue
                    visited[neighbor] = 1
                    queue.append((nx, ny))
            if len(pixels) >= minimum_area:
                components.append(
                    Component(
                        pixels=pixels,
                        bbox=(left, top, right + 1, bottom + 1),
                        center=((left + right + 1) * 0.5, (top + bottom + 1) * 0.5),
                    )
                )
    return components


def ordered_six_components(image: Image.Image) -> list[Component]:
    components = find_components(image)
    if len(components) != 6:
        areas = sorted((len(component.pixels) for component in components), reverse=True)
        raise RuntimeError(f"expected exactly 6 connected poses, found {len(components)}: {areas}")
    components.sort(key=lambda component: component.center[1])
    top = sorted(components[:3], key=lambda component: component.center[0])
    bottom = sorted(components[3:], key=lambda component: component.center[0])
    return top + bottom


def isolate_component(source: Image.Image, component: Component) -> Image.Image:
    left, top, right, bottom = component.bbox
    isolated = Image.new("RGBA", (right - left, bottom - top), (0, 0, 0, 0))
    source_pixels = source.load()
    output_pixels = isolated.load()
    for x, y in component.pixels:
        output_pixels[x - left, y - top] = source_pixels[x, y]
    return isolated


def repack_sheet(image: Image.Image, cell_size: int = 512, padding: int = 32) -> Image.Image:
    source = image.convert("RGBA")
    components = ordered_six_components(source)
    usable = cell_size - padding * 2
    max_width = max(component.bbox[2] - component.bbox[0] for component in components)
    max_height = max(component.bbox[3] - component.bbox[1] for component in components)
    scale = min(1.0, usable / max_width, usable / max_height)
    output = Image.new("RGBA", (cell_size * 3, cell_size * 2), (0, 0, 0, 0))

    for index, component in enumerate(components):
        frame = isolate_component(source, component)
        if scale < 1.0:
            frame = frame.resize(
                (max(1, round(frame.width * scale)), max(1, round(frame.height * scale))),
                Image.Resampling.LANCZOS,
            )
        column = index % 3
        row = index // 3
        x = column * cell_size + (cell_size - frame.width) // 2
        y = row * cell_size + (cell_size - frame.height) // 2
        output.alpha_composite(frame, (x, y))
    return output


def bake_alpha_outline(
    image: Image.Image,
    color: str = "#33fff2e0",
    width: int = 8,
) -> Image.Image:
    rgba = image.convert("RGBA")
    if width <= 0:
        return rgba
    alpha = rgba.getchannel("A")
    dilated = alpha.filter(ImageFilter.MaxFilter(width * 2 + 1))
    outline_alpha = ImageChops.subtract(dilated, alpha)
    red, green, blue, opacity = ImageColor.getcolor(color, "RGBA")
    if opacity < 255:
        outline_alpha = outline_alpha.point(lambda value: value * opacity // 255)
    outline = Image.new("RGBA", rgba.size, (red, green, blue, 0))
    outline.putalpha(outline_alpha)
    outline.alpha_composite(rgba)
    return outline


def validate_repacked_sheet(image: Image.Image, cell_size: int = 512, padding: int = 24) -> None:
    if image.size != (cell_size * 3, cell_size * 2):
        raise RuntimeError("repacked sheet has incorrect dimensions")
    alpha = image.getchannel("A")
    for row in range(2):
        for column in range(3):
            cell = alpha.crop(
                (
                    column * cell_size,
                    row * cell_size,
                    (column + 1) * cell_size,
                    (row + 1) * cell_size,
                )
            )
            bbox = cell.getbbox()
            if bbox is None:
                raise RuntimeError(f"repacked cell {column},{row} is empty")
            if bbox[0] < padding or bbox[1] < padding or bbox[2] > cell_size - padding or bbox[3] > cell_size - padding:
                raise RuntimeError(f"repacked cell {column},{row} violates safe padding: {bbox}")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("input", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument("--cell-size", type=int, default=512)
    parser.add_argument("--padding", type=int, default=32)
    parser.add_argument("--outline-color", default="#33fff2e0")
    parser.add_argument("--outline-width", type=int, default=8)
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    with Image.open(args.input) as source:
        result = repack_sheet(source, args.cell_size, args.padding)
    result = bake_alpha_outline(result, args.outline_color, args.outline_width)
    validate_repacked_sheet(result, args.cell_size)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    result.save(args.output)
    print(f"REPACK PASS: {args.output} {result.width}x{result.height} RGBA")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
