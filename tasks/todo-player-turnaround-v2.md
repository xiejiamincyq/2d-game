# Player Turnaround Technical Proof v2

- [x] AUDIT: confirm the old proof uses a single-image mesh, a 25.6-degree camera,
      brightness-derived alpha, and a screen-space rotating weapon
- [x] PROBE: test true RGBA projection on the existing mesh
- [x] REJECT: existing single-image mesh collapses at side/rear views
- [x] PROBE: test a stable procedural body under an exact 45-degree camera
- [x] REJECT: screen-space artwork projection does not follow real 3D geometry
- [x] CLEANUP: remove failed proof code and generated preview assets
- [x] ACQUIRE: finish the official `tencent/Hunyuan3D-2mv` checkpoint download
- [x] VERIFY: checksum and run a multi-view load-only smoke test
- [x] BUILD: reconstruct a review-only body with the official multi-view model
- [x] REJECT: gameplay-perspective references produce round, squat geometry even
      when the side-view label changes
- [x] PREVIEW: create three eye-level orthographic modeling-sheet candidates
- [x] REVIEW: Candidate A selected as the canonical modeling sheet
- [x] BUILD: reconstruct the body from Candidate A with validated transparent inputs
- [x] BUILD: author the rifle as an independent 3D object and attachment/depth preview
- [x] PROBE: render the failed reconstruction as an exact-camera 12-angle board
- [x] PREVIEW: render the corrected exact-camera 12-angle body diagnostic board
- [x] REVIEW: obtain corrected body mesh approval before generating 120 production frames
- [x] REVIEW: obtain independent rifle volume and attachment-depth approval
- [x] REVIEW: select grip/action candidate A (standard shoulder weld)
- [x] AUDIT: confirm approved body/weapon GLBs contain no skeleton, skin weights,
      or animations
- [x] BUILD: create a non-destructive review skeleton, arm weights, and firing-hand
      weapon attachment from the approved separate meshes
- [x] PROVE: render READY/MOVE/FIRE through 12 true-yaw samples and measure both
      hand contacts plus shoulder-stock contact
- [x] REVIEW: obtain skeletal deformation and two-hand constraint approval
- [x] BUILD: add an inherited six-bone lower-body review rig without changing the
      approved eight-bone grip proof or source topology
- [x] PROVE: test continuous leg weights, alternating foot travel, floor clearance,
      ordered A/B/C profile amplitudes, and retained two-hand/stock contact
- [x] PREVIEW: render three separate six-frame gait plus six-frame recoil candidates
      and one exact-45-degree comparison board
- [ ] REVIEW: obtain user selection of motion profile A, B, or C
- [ ] INTEGRATE: update runtime assets only after approval and regression tests
