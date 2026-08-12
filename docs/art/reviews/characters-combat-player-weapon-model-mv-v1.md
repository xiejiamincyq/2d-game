# Independent Player Rifle Model v1 Review

Date: 2026-08-12
Review state: awaiting weapon geometry and attachment-depth approval

## Output

- 12-angle weapon and attachment board:
  `docs/art/previews/characters-combat/player-weapon-model-12-angle-attachment-v1.png`
- review-only 64-pixel weapon atlas:
  `assets/art/actors/player/technical_previews/player_weapon_model_mv_v1.png`
- independent weapon mesh:
  `assets/art/source/player/player_weapon_model_mv_v1.glb`

The first two rows show only the independent rifle through twelve real 30-degree yaw
rotations. The lower two rows show the approved body and the same rifle attached at a
low right-hand calibration socket. The orange material is a technical separation
color used to expose occlusion; it is not final weapon texturing.

## Technical result

- weapon identity inherited from the already-approved `player_weapon.png`: charcoal
  hard-surface casing, orange energy core, and thin cyan edge lights;
- a new orthographic source sheet provides distinct left-side, right-side, and
  muzzle/end views rather than a mirrored or rotating billboard;
- official `tencent/Hunyuan3D-2mv`, seed 20260812, 30 steps, octree 256;
- 52,646 vertices and 105,292 faces;
- extent ratios are height/length 0.3743 and thickness/length 0.1308;
- Godot contract passed 15 assertions, including an explicit non-flat thickness
  gate and rejection of any `Sprite2D` weapon path;
- all views use a measured 45-degree-pitch orthographic camera.

## Review interpretation

This gate asks whether the rifle has believable length, height, muzzle thickness,
stock volume, and a stable body-relative attachment/depth path. The lower rows are
not a final firing pose: the approved body remains in a neutral A-pose, so hand grip,
arm IK, recoil, muzzle flash, and locomotion belong to the next animation/rig gate.

The weapon is a separate GLB and is never welded into the body mesh. Its front/behind
relationship in the lower rows is produced by one 3D depth buffer while body and
weapon yaw together. `Player.gd`, the production atlas, and the current game remain
unchanged.

## Promotion limits

- no production material or neon emission has been approved by this board;
- no claim is made that the temporary low socket is a final two-hand grip;
- 120 three-degree frames, runtime front/behind raster layers, rigging, animation,
  and gameplay integration remain blocked until this geometry/depth gate passes;
- license review remains pending, so the asset cannot be marked `final`.

Prompt lineage uses the locally cached YouMind game-asset references `27303` and
`26830`, adapted to the already-approved project rifle and strict orthographic
multiview reconstruction constraints.
