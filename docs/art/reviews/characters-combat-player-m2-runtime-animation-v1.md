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

## Remaining gate

The bake is not yet production-integrated. Runtime mapping, action priority,
removal of the standalone rotating 2D rifle, and a real 1280x720 gameplay capture
must pass before promotion is unblocked.
