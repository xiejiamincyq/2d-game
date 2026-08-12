# Player Turnaround Technical Proof v2

- [x] AUDIT: confirm the old proof uses a single-image mesh, a 25.6-degree camera,
      brightness-derived alpha, and a screen-space rotating weapon
- [x] PROBE: test true RGBA projection on the existing mesh
- [x] REJECT: existing single-image mesh collapses at side/rear views
- [x] PROBE: test a stable procedural body under an exact 45-degree camera
- [x] REJECT: screen-space artwork projection does not follow real 3D geometry
- [x] CLEANUP: remove failed proof code and generated preview assets
- [ ] ACQUIRE: finish the official `tencent/Hunyuan3D-2mv` checkpoint download
- [ ] VERIFY: checksum and run a multi-view load-only smoke test
- [ ] BUILD: reconstruct the body from approved front/left/rear/right references
- [ ] BUILD: author the rifle as an independent 3D object and attachment layer
- [ ] PREVIEW: render the exact-camera 12-angle diagnostic board
- [ ] REVIEW: obtain visual approval before generating 120 production frames
- [ ] INTEGRATE: update runtime assets only after approval and regression tests
