# Player M2 Runtime Animation v1 Review

## Decision

The deterministic M2/A2 action bake passes the technical and visual review gate
for runtime integration. This approval covers the READY, MOVE, and FIRE player
atlases only; it does not approve Dasher animation or any new visual style.

## Visual inspection

- The fixed camera remains pitched down exactly 45 degrees while the character
  turns through 120 real world-yaw samples in three-degree steps.
- Front, rear, and both side profiles remain readable. The body and rifle preserve
  their shared 3D occlusion, so the rifle moves behind the torso when appropriate
  instead of spinning as a screen-space overlay.
- The two reviewed gait phases show alternating support legs without floor
  penetration. FIRE peak and recovery remain attached at both hands and stock.
- The M2 cyan armor accents, neutral industrial body, and orange-brown rifle remain
  consistent with the accepted READY reference. No broad translucency is visible.

## Measured gates

- 1,440 MOVE/FIRE direction-action samples rendered; all atlas cells populated.
- Minimum opaque-visible ratio: 0.922271758092654.
- Minimum mean visible alpha: 0.959927633355822; maximum alpha remains 1.0.
- Maximum measured hand/stock contact error: 0.00000014901161193, inside the rig
  tolerance.
- READY + MOVE + FIRE PNG size: 4,071,754 bytes, below the 12 MiB cap.
- Twelve recoverable GPU batches completed in 10,788 milliseconds total.

## Runtime integration result

Production now selects a 120-yaw composite frame from M2 READY, MOVE, or FIRE.
FIRE overrides MOVE, MOVE overrides READY, and dash temporarily reuses the
approved READY pose. The old turnaround atlas, standalone screen-space rotating
rifle, and single-direction action-slice exception have been removed from
`Player.gd`.

The 1280x720 gameplay capture confirms that the M2 player renders in the real
combat scene with an opaque silhouette and attached rifle while the existing HUD,
projectiles, enemies, collision, movement, damage, and controls remain unchanged.
Its renderer now targets the production M2 FIRE state directly; the removed
single-direction action-slice preview properties are no longer referenced.
The asset is gameplay-approved; final status remains separate from the pending
project-wide license review.
