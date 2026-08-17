# Player M2 Runtime Animation v1 Plan

## Objective

Replace the current production player visual path that combines an old turnaround
body with one screen-space rotating weapon. Ship the approved M2/A2 player as true
45-degree-camera READY, MOVE, and FIRE sprite animation at 120 real world-yaw
angles without changing collision, movement speed, weapons, damage, or controls.

## Architecture decisions

- READY uses the accepted 120-yaw shared-depth composite proof.
- MOVE and FIRE each use six animation frames at every three-degree yaw, for 720
  composite frames per action.
- Every composite frame is rendered from separate 3D body and rifle objects inside
  one `SubViewport`; runtime never rotates one 2D rifle texture around the player.
- Runtime atlases use 20 yaw columns and six yaw rows per animation frame. A six-
  frame action atlas is therefore 1280 by 2304 pixels.
- Dash and hit keep their existing gameplay effects and temporarily draw READY;
  inventing unreviewed dash/hit animation is outside this increment.
- Dasher movement animation is the next independent increment. It is not mixed
  into the player runtime migration commit.

## Increment 1: Shared deterministic M2 material support

**Acceptance criteria:**

- Extract the approved M2 body and weapon material construction into one art-only
  helper without changing the accepted READY renders.
- Existing READY renderer and its 400 assertions remain green.

**Verification:** `PlayerM2Ready120YawBakeTest.gd`, locked material parameters, and
an image diff with unchanged alpha and no more than one least-significant color
step. Exact PNG hashes are not a valid gate because repeated OpenGL/MSAA renders
show bounded one-LSB rounding in one to three pixels.

## Increment 2: MOVE and FIRE 120-yaw bake

**Acceptance criteria:**

- Render six A2 gait phases and six A2 recoil phases across 120 three-degree yaws.
- Produce compact production candidate atlases plus a 12-angle action review board.
- Every frame is populated, opaque-material gates pass, hand/stock contacts remain
  inside tolerance, and file/render costs are measured.

**Verification:** New bake test, manifest validation, alpha metrics, and full-size
board inspection.

## Increment 3: Runtime migration

**Acceptance criteria:**

- `Player.gd` loads only M2 READY/MOVE/FIRE atlases for its body/weapon composite.
- Direction mapping is 120 angles at three-degree steps with a 20-by-6 yaw block.
- MOVE animates while velocity is nonzero; FIRE overrides MOVE while shots are
  active; no `draw_set_transform` weapon spin or one-direction action-slice branch
  remains.
- Collision radius, gun direction, projectile spawn, damage, movement, dash, and
  hit behavior remain unchanged.

**Verification:** Runtime unit tests, full regression suite, and a 1280-by-720
combat screenshot inspected at gameplay scale.

## Stop gate

After runtime gameplay evidence is delivered, stop before Dasher animation. The
enemy animation gets its own preview and regression-backed increment next.
