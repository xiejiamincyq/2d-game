# Player Grip and Action-Language Candidates v1 Review

Date: 2026-08-12
Review state: candidate A approved for review-rig construction

User decision: A, approved on 2026-08-12. The locked direction is the standard
shoulder weld with balanced elbow clearance. This approval unlocks only the
non-destructive skeleton and cross-yaw constraint proof described below.

The resulting v7 rig proof is documented in
`docs/art/reviews/characters-combat-player-grip-rig-a-v1.md`; it is awaiting a
separate technical-deformation approval.

## Scope

This is the approval gate after independent rifle geometry/depth architecture was
approved as option A. It compares three two-hand grip directions using the locked
armored-player identity and locked independent rifle identity. Each candidate shows
READY, MOVE, and FIRE keys at the same down-right yaw under the 45-degree downward
orthographic gameplay camera.

The comparison board is
`docs/art/previews/characters-combat/player-grip-pose-candidates-runtime-v1.png`.
The lower row shows the actual deterministic 64-pixel extraction with the current
13-pixel collision marker; it is not a decorative enlargement.

## Candidate A — standard shoulder weld

- Stock-to-shoulder contact is the clearest and most conventional.
- Firing hand stays on the pistol grip; support hand sits far enough forward to
  control the barrel without locking the elbow.
- The silhouette remains readable in READY, MOVE, and FIRE without making the rifle
  look detached from the torso.
- Best baseline for realism and the recommended candidate for rig construction.

## Candidate B — compact CQB high-ready

- Elbows and rifle are pulled closer to the armored torso, reducing horizontal
  footprint and making close movement feel guarded.
- It reads slightly more upright than A under the locked camera, so the 45-degree
  gameplay pitch is less visually obvious.
- Useful if compactness is more important than an immediately readable shoulder
  weld, but it provides less forward rifle exposure at 64 pixels.

## Candidate C — forward support / long brace

- Support hand reaches farthest along the handguard and the torso leans forward.
- MOVE has the widest step and strongest aggressive action language.
- The longer brace is readable at 64 pixels but creates the widest silhouette and
  needs the most careful elbow/weapon occlusion work across rear yaw angles.

An earlier C low-ready generation was rejected because its rightmost rifle reversed
stock and muzzle. It was discarded and replaced; the rejected image is not present
in the candidate set.

## Technical gates passed

- three transparent 1254x1254 source sheets with no baked floor/background;
- exactly three detected subjects per candidate, including B where rifle projections
  overlap horizontally;
- nine non-empty RGBA runtime frames in a 576x64 review atlas;
- no change to `Player.gd`, the production player atlas, collision, or gameplay;
- source-to-runtime conversion is deterministic and covered by Python tests;
- license review remains pending, so all files remain preview-only.

## What approval unlocks

Selecting A, B, or C will lock the grip/action direction for the next technical gate:
body skeleton, two-hand weapon constraints, body/weapon front-behind render layers,
and a small cross-yaw motion proof. It does not authorize the full 120-frame atlas or
runtime integration yet.

Prompt lineage uses locally cached YouMind references `27303`, `26830`, and `1620`.
Only identity consistency, tactical two-hand load bearing, and rifle-hand contact
were retained; eye-level camera and unrelated weapon styling were explicitly rejected.
