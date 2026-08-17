# High-Density Art Stress Gate v1

Date: 2026-08-18
Review state: gameplay-approved

## Scene contents

The deterministic 1536x900 runtime capture contains:

- one opaque M2/A2 player in active overdrive FIRE state;
- sixteen Dashers split across A/B identities and all six run/attack frames;
- six Scrappers and four Bruisers using their approved static 45-degree masters;
- twelve independently aimed overdrive projectiles;
- two simultaneous batched arc pulses;
- four hit/effect clusters mixing sparks, rings, and blasts;
- the revised industrial floor and active overdrive HUD.

## Decision

The combined visual system passes the high-density readability gate. Dasher action
frames do not synchronize into one repeated pose, cyan outlines survive overlapping
energy effects, and the player remains identifiable inside the two pulse rings. The
magenta, cyan, and orange channels retain their energy, direction, and impact roles.

The top HUD remains separated from the playfield by opaque card fields. The centered
bottom overdrive capsule stays clear of the player and projectile fan at this aspect
ratio. Floor major lines provide orientation while the minor lines remain quieter
than actors.

## Known bounded scope

Scrapper and Bruiser now use formal single-frame sprite masters and flip toward
the player. This is not presented as finished animation; the approved scope still
prioritizes full action animation for Dasher A/B while allowing other enemies to
remain single-frame for now. Spitter, Marksman, Lobber, and Overseer retain their
procedural placeholder visuals.

## Evidence

- capture: `docs/art/previews/characters-combat/art-stress-combat-runtime-v1.png`;
- renderer: `scripts/art/RenderArtStressCombatPreview.gd`;
- renderer result: real Vulkan/OpenGL-capable Godot path, 1536x900, clean exit and
  no ObjectDB leak marker.

## Single-machine performance baseline

`scripts/art/BenchmarkArtStressCombat.gd` reuses this exact fixture rather than a
reduced synthetic scene. On an NVIDIA GeForce RTX 5060 Laptop GPU with Godot 4.7
Forward+, a 120-frame warmup followed by 180 sampled frames measured after the
Scrapper/Bruiser sprite integration:

- 11.336 ms average and 12.155 ms P95 process time;
- 210 maximum draw calls;
- 37.84 MiB reported texture memory and 62.69 MiB reported total video memory;
- 251 nodes in the complete fixture.

The raw record is `docs/art/reviews/art-stress-performance-v1.json`. This is a
debug, single-machine regression baseline, not a minimum-hardware release claim.
Godot's built-in monitors may update with up to a one-second delay, so the report
uses a warmup and a multi-second sample window rather than interpreting one frame.

This gate adds deterministic evidence only and introduces no generated or
third-party asset source.
