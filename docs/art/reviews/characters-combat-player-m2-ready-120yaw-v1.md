# Player M2 READY 120-Yaw Technical Bake v1 Review

Date: 2026-08-17
Review state: technical bake proof complete; runtime integration blocked

## Outputs

- twelve-key-angle board:
  `docs/art/previews/characters-combat/player-m2-ready-120yaw-review-v1.png`
- depth-correct composite atlas:
  `assets/art/actors/player/technical_previews/player_m2_ready_120yaw_composite.png`
- body-only diagnostic atlas:
  `assets/art/actors/player/technical_previews/player_m2_ready_120yaw_body.png`
- weapon-only diagnostic atlas:
  `assets/art/actors/player/technical_previews/player_m2_ready_120yaw_weapon.png`
- metrics:
  `docs/art/reviews/characters-combat-player-m2-ready-120yaw-metrics-v1.json`

## Sampling and visual result

The bake contains 120 true world-yaw samples from 0 through 357 degrees in exact
three-degree steps. Every sample uses selected M2, bounded READY pose, fixed-world
lighting, and the same orthographic camera pitched downward exactly 45 degrees.
The camera does not orbit and no direction is mirrored.

The twelve-key-angle board covers 30-degree intervals and shows distinct front,
profile, rear, and intermediate silhouettes. Original-resolution inspection found
no screen-space rifle spin, detached weapon, collapsed profile, broad body
translucency, cropped subject, or missing directional frame.

## Body and rifle separation

The body remains a skinned `MeshInstance3D` using the approved automatic LOD bake
candidate. The rifle remains a different 3D object below
`BoneAttachment3D:firing_hand`. The composite atlas is rendered with both objects
inside one `SubViewport`, so one 3D depth buffer decides whether the body or rifle
owns each visible pixel.

The body-only and weapon-only atlases retain the same transforms and are useful for
diagnostics, authoring, and a future weapon-swap pipeline. They are not advertised
as sufficient for simple 2D recomposition: independent alpha layers cannot recover
pixels hidden by the other object in the depth-correct composite. Runtime should
use the composite atlas unless a later design adds depth masks or live 2.5D.

## Alpha and contact result

- minimum high-opacity visible-pixel ratio: composite 92.32 percent, body 91.88
  percent, and thin profile weapon 81.16 percent;
- minimum weapon mean visible alpha: 90.38 percent; every weapon angle contains
  fully opaque alpha-1 pixels;
- partial alpha is limited to MSAA silhouette edges; all atlas corners are zero
  alpha;
- maximum firing-hand error: 0.0000001341 world units;
- maximum support-hand error: 0.0000000745 world units;
- maximum shoulder-stock error: zero;
- all contacts remain far below the 0.006-unit tolerance.

## Resource and render cost

- composite atlas, 1280 by 384: 313,488 bytes;
- body-only atlas, 1280 by 384: 294,870 bytes;
- weapon-only atlas, 1280 by 384: 92,207 bytes;
- all three atlases together: 700,565 bytes, about 0.67 MiB;
- twelve-key-angle board: 111,040 bytes;
- ten recoverable twelve-angle batches: 3,739 ms of measured in-process render and
  PNG work, averaging about 374 ms per batch on the NVIDIA/OpenGL3 path.

Repeated OpenGL/MSAA reproduction changed only one to three body pixels by at most
one color step out of 255, with identical alpha. This bounded floating-point
rounding is not treated as a visual or material drift; locked parameters, alpha,
silhouette, and aggregate gates remain the reproducibility contract.

The compact 20-by-6 layout therefore supports three-degree angular resolution well
inside the declared 6 MiB proof budget. In a production runtime that only ships the
depth-correct composite, the current PNG cost is about 0.30 MiB before engine import
settings and platform texture compression are chosen.

## Classification and stop gate

The 47,326-vertex / 94,648-triangle body remains an automatic meshoptimizer LOD
candidate for offline sprite baking, not hand-authored production retopology. This
proof does not change `Player.gd`, collision, combat behavior, or any production
atlas. Runtime integration and motion-state expansion remain blocked for a separate
review decision.
