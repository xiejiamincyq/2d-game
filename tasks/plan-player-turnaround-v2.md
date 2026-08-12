# Implementation Plan: Player Turnaround Technical Proof v2

## Status

The failed single-image proof was rejected and removed. Candidate A v3 body geometry,
independent rifle volume/depth architecture, and grip/action candidate A are approved.
The approved body GLB began as an unskinned static mesh. A review-only eight-bone
skeleton, continuous four-weight skin, two-hand constraint, and independent rifle
attachment now produce a clean 36-sample v7 proof. Production integration remains
unchanged pending user review.

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

## Stop conditions

- Reject any single-image reconstruction, screen-projected color shader, or
  procedural placeholder as a production candidate.
- Stop if the official multi-view checkpoint cannot be completely acquired or
  loaded; do not silently fall back to the cached single-view model.
- Stop if the 12-angle board contains anatomy collapse, floating equipment,
  partial transparency, or camera drift.
- Stop if automatic weight regions pull the torso, legs, or backpack into an arm
  bone, or if rigid-joint deformation creates a visibly broken silhouette.

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
