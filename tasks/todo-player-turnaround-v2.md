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
- [ ] REVIEW: obtain independent rifle volume and attachment-depth approval
- [ ] INTEGRATE: update runtime assets only after approval and regression tests
