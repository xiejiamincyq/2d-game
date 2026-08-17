# Player Modeling Sheet Candidates v1

Date: 2026-08-12
Review state: Candidate A explicitly selected

## Shared hard locks

- body only; no gun, weapon, prop, or invisible grip pose;
- eye-level orthographic front, exact right profile, and back views;
- one consistent opaque character at equal scale in every view;
- neutral A-pose with visible hands and animation-safe limb separation;
- approved Player B helmet, cyan visor, charcoal/navy armor, magenta identifiers,
  backpack, boots, and gloves;
- these are modeling references, not gameplay-camera renders or runtime sprites.

## Candidate A — hard-surface hero

Path: `docs/art/previews/characters-combat/player-turnaround-modeling-sheet-a-v1.png`

Strongest armor planes, largest protective shapes, and most heroic silhouette. It is
the clearest hard-surface modeling source, but also moves furthest toward a realistic
heavy soldier and carries the most small armor detail.

Selection: approved as the canonical modeling source. This approval locks the
body-only orthographic sheet, not the reconstructed mesh or runtime sprites.

## Candidate B — compact tactical

Path: `docs/art/previews/characters-combat/player-turnaround-modeling-sheet-b-v1.png`

Closest to the approved compact Player B identity. Medium-size shapes should survive
the later 64-pixel gameplay reduction better than Candidate A, while its corrected
adult proportions avoid the rejected squat mesh. Recommended baseline.

## Candidate C — animation clearance

Path: `docs/art/previews/characters-combat/player-turnaround-modeling-sheet-c-v1.png`

Leaner armor, wider A-pose, and clearer flexible undersuit gaps at shoulders, elbows,
waist, hips, knees, and ankles. It is the easiest candidate to rig and animate, but
its slimmer silhouette is less faithful to the original compact mass.

## Prompt set used

All three candidates used the approved cardinal comparison board as the only image
reference. The shared prompt required a body-only, fully opaque, eye-level
orthographic front/right-profile/back modeling sheet; corrected the source's
45-degree gameplay-camera foreshortening; enforced one character identity, equal
scale, neutral lighting, empty hands, and no text or props. Candidate A emphasized
crisp hard-surface armor planes; B emphasized the original compact tactical mass and
64-pixel readability; C emphasized animation-ready joint clearance.

## Approval gate

Candidate A is selected. The approved sheet becomes geometry input; the body is
reconstructed alone, then reviewed as a
12-angle true-yaw board at exact 45-degree gameplay pitch. The rifle remains a
separate object and layer. No 120-frame production render or `Player.gd` integration
is allowed before that review passes.
