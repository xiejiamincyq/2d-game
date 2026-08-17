# High-Density Art Stress Gate v1

Date: 2026-08-18
Review state: gameplay-approved

## Scene contents

The deterministic 1536x900 runtime capture contains:

- one opaque M2/A2 player in active overdrive FIRE state;
- sixteen Dashers split across A/B identities and all six run/attack frames;
- six Scrappers and four Bruisers using their intentionally retained single-frame
  scope;
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

Scrapper and Bruiser visuals remain simple single-frame enemies that may face the
player through their existing runtime rule. This is not presented as finished
animation; it is retained because the approved scope explicitly prioritized full
action animation for Dasher A/B while allowing other enemies to remain single-frame
for now.

## Evidence

- capture: `docs/art/previews/characters-combat/art-stress-combat-runtime-v1.png`;
- renderer: `scripts/art/RenderArtStressCombatPreview.gd`;
- renderer result: real Vulkan/OpenGL-capable Godot path, 1536x900, clean exit and
  no ObjectDB leak marker.

This gate adds deterministic evidence only and introduces no generated or
third-party asset source.
