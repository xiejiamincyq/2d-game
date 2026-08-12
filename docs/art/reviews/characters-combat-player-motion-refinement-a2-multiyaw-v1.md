# Player Motion Refinement A2 Multi-Yaw v1 Review

Date: 2026-08-13
Review state: awaiting explicit pass or return

## Output and reading order

- review board: `docs/art/previews/characters-combat/player-motion-refinement-a2-48-frame-v1.png`
- transparent technical atlas: `assets/art/actors/player/technical_previews/player_motion_refinement_a2_multiyaw.png`
- metrics: `docs/art/reviews/characters-combat-player-motion-refinement-a2-multiyaw-metrics-v1.json`

The board contains four colored state bands, each split across two rows. Within a
band, read left to right: 0, 30, 60, 90, 120, and 150 degrees on the first row;
180, 210, 240, 270, 300, and 330 degrees on the second. Cyan is left step,
magenta is right step, orange is peak recoil, and grey is the A2 recovery tail.

## Locked scope

A2 remains locked to profile A's 0.15 stride, 0.085 foot lift, 0.010 shoulder bob,
and four-degree peak recoil. Its mechanics remain a 0.028 hip shift, 1.8-degree
pelvis yaw, 3.2-degree torso counter-yaw, 1.8-degree lateral lean, and two-stage
recovery. The camera is orthographic at exactly 45 degrees downward. Only real
world yaw changes between columns.

## Technical result

- 48 non-empty samples: 12 directions times four motion states;
- all 94,652 source vertices and 567,888 source indices remain present;
- maximum firing-hand error: 0.0000000472 world units;
- maximum support-hand error: 0.0000001333 world units;
- maximum shoulder-stock error: 0.0000000149 world units;
- all contact errors are far below the 0.006-unit tolerance;
- minimum foot height: 0.0999999940 against a 0.1000000015 floor, inside the
  explicit 0.0001 floating-point tolerance;
- visible-subject high-opacity share: 100 percent;
- transparent atlas corner alpha: zero;
- rifle remains a separate object under `BoneAttachment3D:firing_hand`.

## Original-resolution visual inspection

The board and transparent atlas were inspected at original resolution. Front,
profile, rear, and intermediate silhouettes are materially different and track one
continuous 3D body. The two gait bands reverse the loaded leg and foot travel. Peak
recoil and recovery preserve two-hand shoulder-weld contact. The rifle changes
front/behind relationships through real 3D depth while staying attached to the body;
it is not a screen-space sprite rotating around the player. No broad translucency,
cropped anatomy, detached rifle, mesh hole, limb spike, floor penetration, or
whole-character 2D spin is visible.

These remain neutral diagnostic materials, not final character texturing. Fixed
world lighting produces intentionally brighter and darker sides as the body turns;
that is illumination, not alpha transparency.

## Renderer root-cause and upgrade

The initial long render attempts used Godot `--headless`. On this Windows build,
that flag selects the headless/dummy rendering driver, so it is not a valid 3D art
capture path. Reducing resolution and adding processes could not fix the wrong
driver and made resource contention worse.

The corrected pipeline now:

1. stores the deterministic 14-bone skinned review mesh in versioned cache
   `player_motion_review_skinned_mesh_v1.res` while preserving source topology;
2. loads and validates one cached rig in about 0.28 seconds instead of rebuilding
   all four-slot weights in GDScript on every run;
3. uses the Windows display driver and OpenGL3 compatibility renderer on the local
   NVIDIA RTX 5060 GPU;
4. submits all twelve directions for one motion state in one render frame;
5. saves each state immediately as a recoverable batch, then assembles four batches
   without rerendering.

The batch entry point now rejects the headless display driver immediately; only the
no-render assembly mode may run headless. This prevents the same failure mode from
silently consuming minutes again.

With the correct GPU path, each 192-pixel twelve-direction state batch completes in
about 2.7 to 2.8 seconds and assembly completes in about 2.3 seconds. Any future
weighting-algorithm change must increment the cache schema and regenerate the cache.

## Gate and limits

This board is ready for a binary technical decision: pass or return. Passing it
only authorizes the next production-retopology and final-material preview gate. It
does not authorize a 120-frame production atlas, `Player.gd` integration, collision
changes, combat changes, enemy animation work, or final texturing.
