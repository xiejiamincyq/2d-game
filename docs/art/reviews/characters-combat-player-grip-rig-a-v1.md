# Player Grip Rig A v1 Review

Date: 2026-08-12; approved 2026-08-13
Review state: technical rig gate approved; motion preview authorized

## Output

- 36-sample review board:
  `docs/art/previews/characters-combat/player-grip-rig-a-36-frame-v7.png`
- review-only 64-pixel atlas:
  `assets/art/actors/player/technical_previews/player_grip_rig_a_preview_v7.png`
- measured contact report:
  `docs/art/reviews/characters-combat-player-grip-rig-a-metrics-v7.json`

Rows are grouped by colored separators: cyan is READY, magenta is MOVE, and orange
is FIRE. Each action contains twelve real 30-degree world-yaw samples rendered by
one orthographic camera pitched downward exactly 45 degrees. The orange rifle is a
separate GLB rendered in the same depth buffer as the body.

## What was built

- eight named bones: root, torso, and firing/support upper-arm, forearm, and hand;
- all 94,652 source vertices and all 567,888 source indices are retained;
- each source vertex has four skin slots spanning torso and the appropriate arm
  chain, with continuous shoulder, elbow, and wrist transitions;
- the rifle remains an independent object under `BoneAttachment3D:firing_hand`;
- analytic two-bone solving places both hand bones on the locked candidate-A
  pistol-grip and medium-forward handguard anchors;
- stock contact is solved against a stable shoulder point rather than a screen-space
  rotation or post-render layer swap.

## Measured result

- 36 action/yaw samples;
- maximum firing-hand error: 0.0000001342 world units;
- maximum support-hand error: 0.0000001342 world units;
- maximum stock-contact error: 0 world units;
- all contact errors are below the 0.006-unit gate;
- 14,679 vertices fall inside the declared source-arm region, with zero receiving
  less than 0.80 total arm weight in v7;
- an additional arm-region test rejects the rig if at least two percent of the
  original arm-space vertices receive less than 0.80 total arm weight.

## Rejected iterations

- v1 used rigid one-bone regions and produced long stretched spikes;
- v2-v5 removed source-arm triangles and tried capsule/sphere proxies, causing
  holes, floating fragments, or obviously synthetic ball joints;
- v6 introduced continuous weights and preserved the full mesh, but left several
  underweighted dangling vertex strands;
- v7 added a spatial arm-coverage gate and is the first version that passes both
  structural tests and visual inspection. Rejected images were removed; their
  failure causes remain recorded here.

## Honest limits

- the source Hunyuan body is a single fused component: 94,632 of 94,652 vertices
  belong to one topology island. This proof does not turn it into production-quality
  animation topology;
- body and rifle use neutral diagnostic materials, not the approved final palette or
  texture treatment;
- READY/MOVE/FIRE validate upper-body grip stability. MOVE does not yet contain a
  lower-body walk cycle, foot planting, or backpack secondary motion;
- no facial, finger, recoil, reload, hit, dash, muzzle-flash, or enemy animation is
  included in this gate;
- `Player.gd`, collision, production atlases, and gameplay remain unchanged;
- 120 three-degree frames remain blocked until this proof is approved, followed by
  a separate locomotion/recoil preview and formal production-topology decision.

## Approval question

Approve only if the body/rifle front-behind relationship, shoulder weld, and both-arm
silhouette remain believable across front, side, and rear yaw. Approval authorizes
the next small preview: locomotion leg cycle plus recoil on this same rig. It does
not authorize final 120-frame generation or runtime integration.

## Approval record

The user answered `继续` on 2026-08-13. This approves the v7 grip structure,
independent-rifle depth behavior, exact 45-degree camera, skeletal deformation, and
both-hand plus shoulder-stock constraint as the basis for the next bounded preview.
It does not approve the neutral diagnostic material as final art, formal production
topology, 120-frame generation, or runtime integration.
