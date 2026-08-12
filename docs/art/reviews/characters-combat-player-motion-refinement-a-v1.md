# Player Motion Profile A Refinement v1 Review

Date: 2026-08-13
Review state: awaiting A1, A2, or A3 selection

## Outputs

- comparison board:
  `docs/art/previews/characters-combat/player-motion-refinement-a-comparison-v1.png`
- A1 restrained stability:
  `docs/art/previews/characters-combat/player-motion-refinement-a1-v1.png`
- A2 realistic load transfer:
  `docs/art/previews/characters-combat/player-motion-refinement-a2-v1.png`
- A3 strong motion statement:
  `docs/art/previews/characters-combat/player-motion-refinement-a3-v1.png`
- review-only 36-frame atlas:
  `assets/art/actors/player/technical_previews/player_motion_refinement_a_candidates.png`
- metrics:
  `docs/art/reviews/characters-combat-player-motion-refinement-a-metrics-v1.json`

The comparison board uses three 384-pixel columns: A1 left, A2 middle, and A3 right.
Within every column the top two rows are six gait phases and the bottom two rows are
six recoil/recovery phases. Each separate transparent sheet places gait on top and
recoil below, read left to right.

## Locked base motion

All three options retain approved profile A exactly: stride 0.15, foot lift 0.085,
shoulder bob 0.010, and four-degree peak independent-rifle recoil. The camera remains
orthographic at exactly 45 degrees downward with one fixed 45-degree down-right yaw.
This gate compares only how the body carries those same motion amplitudes.

## Refinement intent

- A1 uses a 0.012 hip shift, 0.8-degree pelvis yaw, 1.4-degree torso counter-yaw,
  0.7-degree lateral lean, and fast recoil return. It is stable but visually quiet.
- A2 uses a 0.028 hip shift, 1.8-degree pelvis yaw, 3.2-degree torso counter-yaw,
  1.8-degree lateral lean, and two-stage recoil return. It balances readable weight
  transfer with a controlled combat silhouette.
- A3 uses a 0.045 hip shift, 3.0-degree pelvis yaw, 5.5-degree torso counter-yaw,
  3.2-degree lateral lean, and a controlled negative recoil overshoot. It has the
  strongest statement but also the largest silhouette disturbance.

## Technical result

- all 94,652 source vertices and 567,888 source indices remain present;
- 36 bounded samples were rendered: three refinements times six gait and six recoil
  phases;
- maximum firing-hand error: 0.0000001366 world units;
- maximum support-hand error: 0.0000002752 world units;
- maximum shoulder-stock error: 0.0000001193 world units;
- all contact errors are far below the 0.006-unit tolerance;
- declared foot floor: 0.1000000015; measured minimum: 0.0999999046, inside the
  explicit 0.0001 floating-point tolerance;
- minimum high-opacity share among visible subject pixels: 96.50 percent;
- runtime atlas and all candidate sheets have zero-alpha corners;
- A3 records a -0.1339 recovery overshoot, while A1 completes its return before
  phase 0.75 and A2 retains a smaller positive tail.

## Original-resolution visual inspection

The comparison and three separate sheets were inspected at original resolution.
All candidates keep alternating foot travel, an intact silhouette, a separate rifle,
and two-handed shoulder-weld contact. A1 reads restrained, A2 shows the clearest
natural load transfer without overpowering the pose, and A3 visibly exaggerates the
counter-motion. No whole-body yaw spin, broad translucency, detached rifle, one-hand
recoil, floor penetration, arm/leg spike, or source-mesh hole is visible.

## Recommendation and limits

A2 is recommended for the next gate because its weight transfer reads more naturally
than A1 at gameplay scale without A3's larger silhouette disturbance. This remains a
six-frame technical comparison with neutral diagnostic materials. It does not cover
final interpolation, backpack secondary motion, landing settle, reload, dash, hit,
death, enemies, or production texturing. `Player.gd`, collision, gameplay behavior,
and production atlases remain unchanged. Selecting A1/A2/A3 still does not authorize
120-frame generation or runtime integration.
