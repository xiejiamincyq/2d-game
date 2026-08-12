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
- [ ] REVIEW: obtain modeling-sheet approval before another reconstruction
- [ ] BUILD: reconstruct the body from the approved canonical modeling sheet
- [ ] BUILD: author the rifle as an independent 3D object and attachment layer
- [x] PROBE: render the failed reconstruction as an exact-camera 12-angle board
- [ ] PREVIEW: render the corrected exact-camera 12-angle diagnostic board
- [ ] REVIEW: obtain corrected mesh approval before generating 120 production frames
- [ ] INTEGRATE: update runtime assets only after approval and regression tests
