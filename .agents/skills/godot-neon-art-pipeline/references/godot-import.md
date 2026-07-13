# Godot Import and Gameplay Acceptance

## Current Project Facts

- Godot base viewport: 1280×720.
- Stretch mode: `canvas_items`; aspect: `expand`.
- Default canvas texture filtering is nearest, so high-resolution illustration assets may require per-texture linear filtering when downscaled.
- Player collision radius is 13 px.
- Standard enemy collision radius is 14 px; Bruiser collision radius is 24 px.
- Current actors and effects are procedural `_draw()` visuals. Replacing art must not change collision shapes, combat radii, movement, or damage behavior.

## Runtime Paths

Use lowercase snake_case under these roots:

- `res://assets/art/actors/`
- `res://assets/art/effects/`
- `res://assets/art/pickups/`
- `res://assets/art/environment/`
- `res://assets/art/ui/`

Keep editable source files outside runtime folders when they exist. Never commit `.godot/`, provider caches, API credentials, or temporary generation downloads.

## Import Rules

- Use PNG for transparent actors, effects, pickups, icons, and UI components.
- Use lossless compression for UI, masks, icons, and sharp gameplay elements.
- Enable mipmaps only when a texture is repeatedly downscaled, rotated, or viewed at varying scale; verify that mipmaps do not soften small icons or collision cues.
- Use linear filtering for high-resolution illustrated assets when nearest filtering causes shimmer or jagged downscaling. Keep masks and intentionally crisp graphic elements sharp.
- Do not hand-edit generated `.import` files. Configure import options through Godot and commit source assets plus stable Godot resources when needed.
- Keep actor pivots centered over collision shapes and align feet or contact shadows consistently.
- For UI panels, preserve a clean center region and explicit stretch margins suitable for `NinePatchRect`; never bake labels into nine-patch artwork.

## Acceptance Check

At actual gameplay scale, verify silhouette, faction color, facing, transparent edges, pivot, collision alignment, hit-flash readability, and visibility over the battlefield. At compact UI widths, verify nine-patch corners, label space, icon clarity, and contrast. Reject any asset that changes gameplay logic or only looks correct at source resolution.
