# Combat VFX Runtime v1 Review

Date: 2026-08-18
Review state: gameplay-approved

## Decision

The combat-feedback renderer is approved for the five-minute-overdrive branch with
a single bounded draw-command system and no per-impact scene nodes. The visual
language now separates direction, energy, and impact through cyan, magenta, and
orange respectively.

## Visual result

- ordinary hits use an orange outer spark with a pale hot core;
- kills combine cyan/magenta debris, directional sparks, and a split energy ring;
- heavy hits use complementary cyan and magenta ring segments rather than an
  undifferentiated full circle;
- explosions add an orange pressure field, broken outer ring, and magenta inner
  energy arc;
- dash afterimages form directional chevrons instead of generic diamonds;
- overdrive projectiles use a cyan axial streak and tapered magenta trail;
- arc pulses preserve the accepted electric waveform while batching the outline
  into two antialiased polylines.

The real combat capture confirms that the effects remain legible on the dark grid
without hiding the opaque player or animated Dasher silhouettes.

## Technical result

- Spark, debris, ring, and afterimage records remain capped at 96, 48, 16, and 24.
- Requests do not allocate persistent children; `CombatFeedbackTest` passes 36
  assertions and explicitly verifies the blast decomposition.
- The old per-projectile `GPUParticles2D` allocation was removed. Each overdrive
  projectile now has zero GPU emitter children and draws its trail once on itself.
- Projectile collision, radius, speed, damage, pierce, lifetime, and target groups
  are unchanged; `ProjectilePickupTest` passes 20 assertions and `OverdriveTest`
  passes 6 assertions.
- `PerformanceTest` passes 29 assertions with all VFX arrays filled to their caps
  and released after expiry. It also enforces a 48-segment, two-call arc-pulse
  rendering budget.

## Evidence

- isolated runtime board:
  `docs/art/previews/characters-combat/combat-vfx-runtime-v1.png`;
- real combat capture:
  `docs/art/previews/characters-combat/player-m2-runtime-combat-v1.png`;
- deterministic board renderer:
  `scripts/art/RenderCombatVfxRuntimePreview.gd`.

No generated source or third-party material was added in this increment, so it
does not introduce a new asset-license dependency.
