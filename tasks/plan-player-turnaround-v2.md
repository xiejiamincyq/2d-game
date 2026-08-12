# Implementation Plan: Player Turnaround Technical Proof v2

## Status

The failed single-image proof was rejected and removed. Candidate A v3 body geometry,
independent rifle volume/depth architecture, and grip/action candidate A are approved.
The approved body GLB began as an unskinned static mesh. A review-only eight-bone
skeleton, continuous four-weight skin, two-hand constraint, and independent rifle
attachment now produce a clean 36-sample v7 proof. The user approved this technical
gate on 2026-08-13 by asking to continue. That approval covers grip structure,
two-hand contact, weapon depth, and the measured camera only; it does not approve
the neutral diagnostic materials as final art. Production integration remains
unchanged pending the next motion review.

## Locked requirements

- The gameplay camera is orthographic at exactly 45 degrees downward.
- The body turns through real world yaw; front, side, and rear silhouettes must be
  geometrically coherent.
- The rifle is authored and rendered as a separate 3D object with correct depth
  occlusion. It never rotates as a 2D screen-space sprite.
- Final output may use 120 three-degree samples, but only after a 12-angle review
  board is approved.
- Grip candidate A is locked: standard shoulder weld, firing hand on the pistol
  grip, support hand at a medium-forward handguard point, and restrained elbows.
- The body and rifle remain separate resources. A weapon bone attachment may drive
  the rifle, but the rifle cannot be baked into the body mesh.

## Approved technical route

1. Acquire and checksum the official `tencent/Hunyuan3D-2mv` multi-view weights in
   the external Codex cache. Do not commit model weights.
2. Run a load-only smoke test and confirm the pipeline uses the multi-view image
   conditioner (`MVImageProcessorV2`), not the existing single-image encoder.
3. Build the body mesh from the approved front, left, rear, and right references.
   Keep the rifle out of the body references.
4. Model or reconstruct the rifle separately, then attach it to a stable hand/root
   transform so body yaw and weapon pose are independent.
5. Render only twelve 30-degree samples under the exact 45-degree camera, including
   body-only, rifle-only/depth, composite, and alpha diagnostic rows.
6. Stop for visual approval. Only an approved proof may expand to 120 frames and
   replace the runtime atlas.
7. Audit the approved body GLB for an existing skeleton, skin weights, and animation
   channels before authoring motion.
8. Because the audit found no skin or animation data, create a non-destructive
   review rig from the existing mesh, with named firing/support arm chains and a
   firing-hand weapon attachment.
9. Render READY, MOVE, and FIRE through twelve real 30-degree yaw samples under the
   same camera. Measure firing-hand, support-hand, and stock-contact error in 3D.
10. Stop again for rig/deformation approval. Do not expand to 120 frames or modify
    `Player.gd` until the proof passes visually and structurally.
11. After rig approval, extend the review rig non-destructively with left/right
    thigh, shin, and foot chains. Preserve the approved eight-bone grip rig and
    complete source topology rather than rewriting the accepted proof.
12. Produce three motion profiles at one fixed down-right yaw: six gait phases and
    six recoil phases per profile. A is a stable tactical stride, B is a compact
    shuffle, and C is an aggressive advance.
13. Render one independent preview per profile plus one comparison board under the
    same exact 45-degree orthographic camera. Stop for user selection before any
    production animation, 120-frame expansion, or `Player.gd` change.

## Acceptance gates

- Front, profile, and rear silhouettes retain the same anatomy and armor volumes.
- Opaque armor pixels stay opaque; transparency is sourced only from real alpha.
- Rifle position is stable in the hands and its front/behind relationship changes
  through 3D depth, not manual sprite spinning.
- Every sample uses identical framing, scale, lighting, and a measured 45-degree
  orthographic camera.
- No `Player.gd` or production atlas change occurs before review approval.
- The rig proof contains a real `Skeleton3D`, weighted vertices, two arm chains,
  and an independent rifle under `BoneAttachment3D`.
- All three contact errors remain within the declared tolerance at every sampled
  action and yaw; test assertions and a rendered review board must agree.
- The motion proof adds exactly two three-bone leg chains and continuous lower-body
  weights while preserving all 94,652 vertices and 567,888 source indices.
- Each candidate contains six non-empty gait frames and six non-empty recoil frames;
  the candidate ordering is measurable: C stride/recoil > A > B.
- Feet never penetrate below the declared floor contact in sampled gait phases, and
  both hand contacts plus stock contact remain inside the 0.006-unit tolerance.

## Stop conditions

- Reject any single-image reconstruction, screen-projected color shader, or
  procedural placeholder as a production candidate.
- Stop if the official multi-view checkpoint cannot be completely acquired or
  loaded; do not silently fall back to the cached single-view model.
- Stop if the 12-angle board contains anatomy collapse, floating equipment,
  partial transparency, or camera drift.
- Stop if automatic weight regions pull the torso, legs, or backpack into an arm
  bone, or if rigid-joint deformation creates a visibly broken silhouette.
- Stop if the gait reads as whole-body yaw spinning, skating without alternating
  foot travel, foot-floor penetration, detached weapon motion, or a one-handed
  recoil pose.

## Rig proof result

- The source mesh is one fused component (94,632 of 94,652 vertices), so topology-
  island binding is impossible without formal retopology.
- Rigid one-bone regions caused spikes; deleting the source arms caused holes;
  geometric proxy limbs read as spheres. These approaches were rejected.
- v7 preserves all 567,888 source indices and uses continuous torso/upper-arm/
  forearm/hand weights. An arm-region coverage gate keeps underweighted vertices
  below two percent.
- The proof covers only upper-body grip stability for READY/MOVE/FIRE. MOVE does not
  yet include a leg cycle, and the diagnostic materials are not final texturing.

## Motion preview tasks

### Task 1: Additive lower-body review rig

**Acceptance criteria:**

- The approved `PlayerGripRig` remains an eight-bone proof and produces the same
  grip behavior; `PlayerMotionRig` adds six leg bones through inheritance.
- Lower-body vertices receive normalized four-slot continuous weights without
  removing source triangles or changing the independent rifle attachment.
- Rig tests prove topology preservation, lower-body coverage, alternating feet,
  profile ordering, and hand/stock contact tolerance.

**Verification:** `PlayerGripRigTest.gd` and `PlayerMotionRigTest.gd` pass.

**Dependencies:** Approved v7 grip proof.

### Task 2: Three bounded motion candidates

**Acceptance criteria:**

- A: stable tactical stride with moderate lift and recoil.
- B: compact shuffle with the smallest silhouette change and recoil.
- C: aggressive advance with the largest stride, lift, and recoil.
- Every option uses six gait phases and six recoil phases at fixed down-right yaw;
  no extra directions or production frames are generated.

**Verification:** Render metrics contain 36 samples and ordered profile parameters.

**Dependencies:** Task 1.

### Task 3: Visual review gate

**Acceptance criteria:**

- Three separate transparent preview sheets and one opaque comparison board exist.
- The board uses one exact 45-degree orthographic camera and an independent rifle
  attached to the firing hand for every sample.
- `Player.gd`, collision, combat behavior, and production atlases remain unchanged.

**Verification:** `PlayerMotionRecoilPreviewTest.gd`, manifest validation, alpha and
original-resolution visual inspection.

**Dependencies:** Task 2.

## Motion preview result

- The inherited review rig contains fourteen bones while the approved grip proof
  remains eight bones and independently testable.
- All 94,652 source vertices and 567,888 indices remain present. The declared leg
  region contains 26,749 vertices with zero underweighted vertices; 25,696 vertices
  use continuous multi-bone or pelvis blend weights.
- Thirty-six bounded samples were rendered at one fixed 45-degree down-right yaw
  under the exact 45-degree orthographic camera.
- A/B/C follow the required amplitude order, foot targets alternate without floor
  penetration beyond floating-point tolerance, and the rifle stays constrained to
  both hands and the shoulder.
- Visible subject pixels are at least 96.52 percent fully opaque across the sampled
  captures, and every transparent output has zero-alpha corners.
- Production integration remains blocked pending user selection of A, B, or C.

## Candidate A mechanics-refinement gate

The user continued after A was explicitly recommended, so A's balanced stride,
foot lift, shoulder bob, and four-degree recoil are locked for a smaller mechanics
comparison. The next preview changes only weight-transfer and recovery language:

- A1 restrained stability: subtle hip shift, small counter-rotation, minimal lean,
  and fast recoil recovery;
- A2 realistic load transfer: moderate hip shift and lean, readable torso counter-
  rotation, and a two-stage recoil recovery;
- A3 strong motion statement: the largest weight transfer and counter-rotation,
  with a slower overshoot recovery while preserving the same four-degree peak.

All options remain six gait frames plus six recoil frames at one fixed down-right
yaw under the exact 45-degree orthographic camera. A's leg target amplitudes cannot
change. The proof must expose and test pelvis/torso transforms, keep both feet above
the declared floor, retain all source topology, and keep the rifle constrained to
both hands and the shoulder. It stops again for A1/A2/A3 selection before any
production sampling or runtime integration.

## Candidate A mechanics-refinement result

- A1/A2/A3 preserve profile A's 0.15 stride, 0.085 lift, 0.010 shoulder bob, and
  four-degree peak recoil. All 94,652 vertices and 567,888 indices remain present.
- Hip shift, pelvis yaw, torso counter-yaw, and lateral lean are measured in the
  intended A3 greater than A2 greater than A1 order. A1 returns early, A2 uses a
  positive two-stage tail, and A3 reaches a controlled -0.1339 overshoot.
- Thirty-six samples retain alternating feet, floor clearance inside a 0.0001
  floating-point tolerance, and both-hand plus shoulder-stock errors below 0.00000028.
- Visible subject pixels are at least 96.50 percent fully opaque, all transparent
  outputs have zero-alpha corners, and original-resolution inspection found no spin,
  detached weapon, mesh hole, limb spike, or broad translucency.
- A2 is recommended for its readable natural load transfer without A3's larger
  silhouette disturbance. Selection remains pending, and production integration is
  still blocked.
