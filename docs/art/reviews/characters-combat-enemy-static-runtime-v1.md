# Scrapper and Bruiser Static Runtime v1 Review

Date: 2026-08-18

Review state: gameplay-approved

## Decision

Approve one right-facing static master each for Scrapper and Bruiser. This removes
the obvious red and purple placeholder squares while respecting the approved
single-frame scope for non-Dasher enemies. Horizontal flipping keeps both units
facing the player; no unsupported rotation or invented animation is added.

## Identity and scale

- Scrapper is a small, fragile, improvised salvage drone with thin limbs, one cyan
  sensor, and a short orange cutter. Its 128px canvas displays at 0.44 scale.
- Bruiser is a wide heavy frame with thick asymmetric armor, a magenta core, and
  an orange claw. Its 128px canvas displays at 0.66 scale.
- Both retain an opaque body, transparent exterior, one-runtime-pixel cyan alpha
  outline, linear filtering, independent hit flash, and health/status bars above
  the silhouette.

## Gameplay invariants

Scrapper retains a 14-pixel collision radius and 8 contact damage. Bruiser retains
a 24-pixel collision radius and 18 contact damage. Speed, health, drops, attack
timing, AI, groups, collision masks, and wave behavior are unchanged.

## Evidence

- isolated size and flip board:
  `docs/art/previews/characters-combat/enemy-static-runtime-v1.png`;
- high-density combat:
  `docs/art/previews/characters-combat/art-stress-combat-runtime-v1.png`;
- runtime contract: `EnemyStaticArtTest`, 24 assertions;
- deterministic packer: `scripts/art/prepare_static_enemy_sprite.py`.

Spitter, Marksman, Lobber, and Overseer remain procedural single-frame visuals and
are not presented as finished character art. Project-level license review remains
pending for the generated Scrapper and Bruiser sources.
