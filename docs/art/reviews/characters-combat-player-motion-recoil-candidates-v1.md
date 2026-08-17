# Player Motion and Recoil Candidates v1 Review

Date: 2026-08-13
Review state: candidate A approved for bounded mechanics refinement

## Outputs

- comparison board:
  `docs/art/previews/characters-combat/player-motion-recoil-candidates-comparison-v1.png`
- candidate A:
  `docs/art/previews/characters-combat/player-motion-recoil-candidate-a-v1.png`
- candidate B:
  `docs/art/previews/characters-combat/player-motion-recoil-candidate-b-v1.png`
- candidate C:
  `docs/art/previews/characters-combat/player-motion-recoil-candidate-c-v1.png`
- review-only 36-frame atlas:
  `assets/art/actors/player/technical_previews/player_motion_recoil_candidates.png`
- measured report:
  `docs/art/reviews/characters-combat-player-motion-recoil-metrics-v1.json`

The comparison board is split into three 384-pixel columns: A on the left, B in the
middle, and C on the right. Within every column, the top two rows are six gait phases
and the bottom two rows are six recoil phases. Each separate candidate sheet places
the six gait frames on top and the six recoil frames below, both read left to right.

## Candidate intent

- A, stable tactical stride: stride 0.15, lift 0.085, shoulder bob 0.010, and
  four-degree peak recoil. This is the balanced option.
- B, compact shuffle: stride 0.09, lift 0.045, shoulder bob 0.006, and two-degree
  peak recoil. This keeps the smallest combat silhouette.
- C, aggressive advance: stride 0.22, lift 0.125, shoulder bob 0.018, and
  seven-degree peak recoil. This produces the strongest motion statement.

All dimensions except degrees are normalized rig-space units. Candidate ordering is
explicitly tested as C greater than A greater than B for stride, lift, and recoil.

## Technical construction

- `PlayerMotionRig` inherits the approved eight-bone `PlayerGripRig` and adds left
  and right thigh, shin, and foot chains, for fourteen named bones total;
- the source body remains one complete 94,652-vertex, 567,888-index mesh;
- 32,255 vertices receive lower-body influence, including 25,696 vertices with
  continuous multi-bone or pelvis blend weights;
- the rifle remains a separate GLB under `BoneAttachment3D:firing_hand`;
- every sampled pose retains the analytic firing-hand, support-hand, and
  shoulder-stock constraints;
- all samples use one orthographic camera pitched downward exactly 45 degrees and
  one fixed down-right yaw of 45 degrees. This preview tests motion only, not turn
  sampling.

## Measured result

- 36 bounded samples: three candidates times six gait and six recoil frames;
- maximum firing-hand error: 0.0000001342 world units;
- maximum support-hand error: 0.0000001406 world units;
- maximum stock-contact error: 0 world units;
- declared contact tolerance: 0.006 world units;
- 26,749 vertices lie in the declared leg region, with zero below 0.80 total leg
  weight;
- declared foot floor: 0.1000000015; measured minimum: 0.0999999642, a floating-
  point difference inside the explicit 0.0001 tolerance;
- minimum high-opacity share among visible subject pixels: 96.52 percent;
- runtime atlas and all three transparent candidate sheets have zero-alpha corners.

## Original-resolution visual inspection

The comparison board and all three separate sheets were inspected at their original
resolution. The legs alternate rather than translating together; C has visibly more
foot travel and recoil than A, and B has less. No whole-body yaw spin, detached gun,
one-handed recoil, arm/leg spike, deleted-mesh hole, or broad body translucency is
visible. The orange rifle remains in the same 3D depth buffer as the opaque neutral
body and pivots around the shoulder stock contact.

## Honest limits

- these are six-frame technical choices, not interpolated production animation;
- the body and rifle retain neutral diagnostic materials and are not final textured
  art;
- pelvis twist, torso counter-rotation, backpack secondary motion, landing settle,
  reload, dash, hit, death, and enemy motion are outside this gate;
- `Player.gd`, collision, gameplay behavior, and production atlases remain
  unchanged;
- selection authorizes refinement of one motion profile only. It does not authorize
  120-frame expansion or runtime integration.

## Selection question

Choose A for balanced tactical movement, B for compact stability, or C for a more
aggressive advance. A selection locks only motion amplitude and recoil language for
the next refinement pass.

## Selection record

The user answered `继续` after the result explicitly recommended A. This is recorded
as approval of A's balanced tactical stride, foot lift, shoulder bob, and four-degree
recoil for the next bounded refinement preview. It does not approve production
animation, 120-frame expansion, final materials, or runtime integration.
