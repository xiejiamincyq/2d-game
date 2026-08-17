# Non-Dasher Enemy Static Runtime v1 Review

Date: 2026-08-18

Review state: gameplay-approved

## Decision

Approve one right-facing static master for Scrapper, Spitter, Bruiser, Marksman,
Lobber, and Overseer. This completes the approved single-frame scope for every
non-Dasher enemy. Horizontal flipping keeps each silhouette facing the player;
no unsupported full rotation or invented locomotion is added.

## Identity and scale

- Scrapper: small salvage cutter, 0.44 runtime scale.
- Spitter: light canister drone with a short acid nozzle, 0.45 scale.
- Bruiser: wide heavy claw frame, 0.66 scale.
- Marksman: lean biped with a long orange rail rifle, 0.55 scale.
- Lobber: squat four-legged mortar chassis, 0.60 scale.
- Overseer: crowned command machine, 1.00 legacy-enemy scale and 1.25 independent-Boss scale.

All six use a bounded 128px RGBA canvas, opaque subject, transparent exterior,
one-runtime-pixel cyan alpha outline, linear filtering, independent hit flash,
and health/status bars above the silhouette. The independent Overseer Boss keeps
its own collision, attacks, entrance reveal, phases, health contract, and cue rings.

## Gameplay invariants

The integration changes presentation only. Collision radii and contact damage
remain 14/8 (Scrapper), 14/5 (Spitter), 24/18 (Bruiser), 14/5 (Marksman),
17/8 (Lobber), and 40/24 (legacy Overseer). The independent Boss retains its
56px collision radius and all existing combat contracts.

## Pipeline hardening

The deterministic packer now clears source alpha below 24 before measuring the
subject. This prevents tiny low-alpha chroma noise from being expanded into a
cyan rectangle by outline dilation. Validation also rejects sprites whose visible
alpha occupies 72% or more of the runtime canvas.

## Evidence

- six-identity size and flip board: `docs/art/previews/characters-combat/enemy-static-runtime-v1.png`;
- high-density combat: `docs/art/previews/characters-combat/art-stress-combat-runtime-v1.png`;
- runtime contract: `EnemyStaticArtTest`, 72 assertions, plus `BossTest`;
- deterministic packer: `scripts/art/prepare_static_enemy_sprite.py`.

Project-level license review remains pending for generated sources. Additional
enemy animation is a future expansion, not part of the approved one-frame scope.
