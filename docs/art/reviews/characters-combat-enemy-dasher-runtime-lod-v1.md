# Dasher Runtime Texture LOD v1 Review

Date: 2026-08-18
Review state: gameplay-approved

## Decision

Approve the 128-pixel-per-frame candidate for both Dasher action atlases. The
high-resolution transparent source sheets remain unchanged and can regenerate a
larger runtime LOD if a future camera scale requires it.

## Comparison gate

The deterministic board compares 128, 192, 256, and the previous 512-pixel cells.
Every sample is displayed at the exact 64-pixel runtime canvas with linear
filtering. Both A and B are shown in all three run poses plus windup, strike, and
recovery.

At 128 pixels, A's head/torso/limb separation, B's low mechanical silhouette, the
six action poses, transparent gaps, and the one-runtime-pixel cyan outline remain
equivalent at gameplay scale. No visible benefit justifies the larger candidates.

## Resource result

- previous: two 1536x1024 RGBA atlases, 12,582,912 uncompressed bytes (12.00 MiB);
- selected: two 384x256 RGBA atlases, 786,432 uncompressed bytes (0.75 MiB);
- reduction: 11.25 MiB, or 93.75 percent;
- runtime display remains 64x64 through a scale change from 0.125 to 0.5;
- collision, speed, damage, AI, animation states, frame order, phase offset,
  horizontal facing, and hit-flash shader remain unchanged.

## Evidence

- comparison: `docs/art/previews/characters-combat/dasher-runtime-lod-comparison-v1.png`;
- real action board: `docs/art/previews/characters-combat/enemy-dasher-actions-runtime-v1.png`;
- dense combat: `docs/art/previews/characters-combat/art-stress-combat-runtime-v1.png`.

The reusable repacker now derives validation padding from configured padding minus
outline width. Default 512-pixel generation still resolves to the original 24-pixel
gate, while scaled technical candidates receive proportional validation.

Reproduce the board by running
`python scripts/art/build_dasher_runtime_lod_candidates.py`, followed by the real
Godot renderer `scripts/art/RenderDasherRuntimeLodPreview.gd`. Candidate atlases are
temporary `.godot` files; only the comparison board and selected runtime LOD are
versioned.
