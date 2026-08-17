# Player Turnaround — Candidate A Alpha v3 Review

Date: 2026-08-12
Review state: geometry approved

## Output

- 12-angle board:
  `docs/art/previews/characters-combat/player-turnaround-mv-12-angle-a-alpha-v3.png`
- review-only 64-pixel atlas:
  `assets/art/actors/player/technical_previews/player_turnaround_mv_a_alpha_v3.png`
- body-only mesh:
  `assets/art/source/player/player_turnaround_model_mv_a_alpha_v3.glb`

## Technical result

- official `tencent/Hunyuan3D-2mv`, seed 20260812, 30 steps, octree 256;
- 94,652 vertices and 189,296 faces;
- twelve real 30-degree yaw rotations under an exact 45-degree-pitch orthographic
  camera;
- width/height ratio 0.5175 and depth/height ratio 0.3001;
- Godot contract passed 14 assertions, including explicit rejection of a
  character-width background plane and insufficient front-to-back volume.

## Rejected v2 and root cause

The first Candidate A reconstruction used PNG files whose Alpha channel was fully
opaque. The official multi-view processor treats Alpha directly as the silhouette
mask and does not remove backgrounds. It therefore reconstructed the light studio
background as a rotating rectangular plane. The v2 GLB, runtime atlas, and review
board were deleted after the failure was reproduced.

The corrected pipeline removes the border-colored studio background with a soft
matte, validates transparent corners and a non-empty subject, and makes the model
generator reject fully opaque references. The v3 board contains no background plane.

## What this approval means

The user continued from this gate on 2026-08-12, approving the body volume,
proportions, backpack volume, and real front/side/rear turn. This is a neutral gray
geometry proof. It does not approve textures, armor
micro-detail, emissive colors, animation, the separate rifle, the 120-frame atlas,
or gameplay integration.

After approval, the next preview combines the approved body geometry with a separate
rifle attachment and explicit front/behind depth layers. Production rendering and
`Player.gd` remain blocked until that composite review passes.
