# Player High-Speed Overdrive Runtime v1 Review

Date: 2026-08-18
Review state: gameplay-approved

## Decision

The existing M2/A2 player is approved for the five-minute-overdrive branch with
speed-aware animation playback and a restrained cyan/magenta overdrive read. The
change is runtime-only and does not regenerate or modify the accepted 120-yaw
READY, MOVE, or FIRE atlases.

## Visual result

- MOVE playback follows the effective movement-speed ratio. Normal movement is
  1.00x and the branch's 1.30x overdrive movement is visibly faster.
- FIRE playback follows the effective fire-rate multiplier but is capped at 1.50x
  so the six recoil frames remain readable instead of flickering at 2.00x.
- A low-alpha magenta field, cyan/magenta orbit arcs, and three velocity-aligned
  streaks sit behind the opaque player silhouette. The streak direction follows
  actual movement rather than aim.
- The runtime gate samples eight headings from the full set of 120 real world-yaw
  frames. Front, rear, side, and diagonal silhouettes remain distinct.

## Body and rifle architecture

The approved source rig keeps the body mesh and rifle as separate 3D objects. The
runtime PNG deliberately stores their shared-depth composite for each yaw and
action frame, because this preserves hand contact and allows the rifle to pass
behind the torso correctly. Reintroducing a standalone screen-space rifle texture
would recreate the rejected yo-yo rotation failure and is therefore prohibited.

## Evidence and invariants

- Runtime review board:
  `docs/art/previews/characters-combat/player-overdrive-runtime-v1.png`.
- Real combat capture:
  `docs/art/previews/characters-combat/player-m2-runtime-combat-v1.png`.
- `PlayerM2RuntimeAnimationTest` passes 153 assertions, including direct runtime
  checks for 1.30x MOVE playback and the 1.50x FIRE readability cap.
- `OverdriveTest` passes 6 assertions and `MovementTest` passes 26 assertions.
- Collision radius, base speed, damage, fire rate, overdrive multipliers, input,
  projectile spawn, and camera contracts are unchanged.

License review remains pending at the project level, so gameplay approval does not
promote the asset to final licensing status.
