# Implementation Plan: Player Turnaround Technical Proof v2

## Status

The failed single-image proof was rejected and removed. Candidate A v3 body geometry
is now approved, and an independent rifle mesh plus 12-angle attachment-depth probe
is ready for review. Production integration remains unchanged.

## Locked requirements

- The gameplay camera is orthographic at exactly 45 degrees downward.
- The body turns through real world yaw; front, side, and rear silhouettes must be
  geometrically coherent.
- The rifle is authored and rendered as a separate 3D object with correct depth
  occlusion. It never rotates as a 2D screen-space sprite.
- Final output may use 120 three-degree samples, but only after a 12-angle review
  board is approved.

## Approved technical route

1. Acquire and checksum the official `tencent/Hunyuan3D-2mv` multi-view weights in
   the external Codex cache. Do not commit model weights.
2. Run a load-only smoke test and confirm the pipeline uses the multi-view image
   conditioner (`MVImageProcessorV2`), not the existing single-image encoder.
3. Build the body mesh from the approved front, left, rear, and right references.
   Keep the rifle out of the body references.
4. Model or reconstruct the rifle separately, then attach it to a stable hand/root
   transform so body yaw and weapon pose are independent.
5. Render only twelve 30-degree samples under the exact 45-degree camera, including
   body-only, rifle-only/depth, composite, and alpha diagnostic rows.
6. Stop for visual approval. Only an approved proof may expand to 120 frames and
   replace the runtime atlas.

## Acceptance gates

- Front, profile, and rear silhouettes retain the same anatomy and armor volumes.
- Opaque armor pixels stay opaque; transparency is sourced only from real alpha.
- Rifle position is stable in the hands and its front/behind relationship changes
  through 3D depth, not manual sprite spinning.
- Every sample uses identical framing, scale, lighting, and a measured 45-degree
  orthographic camera.
- No `Player.gd` or production atlas change occurs before review approval.

## Stop conditions

- Reject any single-image reconstruction, screen-projected color shader, or
  procedural placeholder as a production candidate.
- Stop if the official multi-view checkpoint cannot be completely acquired or
  loaded; do not silently fall back to the cached single-view model.
- Stop if the 12-angle board contains anatomy collapse, floating equipment,
  partial transparency, or camera drift.
