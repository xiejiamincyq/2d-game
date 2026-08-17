# Player M2 Runtime Animation v1

- [x] AUDIT: confirm production still uses the old body atlas, one screen-space
      rotating weapon, and a one-direction action-slice exception
- [x] PLAN: lock READY/MOVE/FIRE atlas dimensions, direction mapping, depth model,
      state priority, and gameplay invariants
- [x] REFACTOR: extract shared deterministic M2 bake materials without image drift
- [x] TEST: add a failing 120-yaw MOVE/FIRE bake contract
- [x] BAKE: render six gait and six recoil frames at all 120 directions
- [x] REVIEW: inspect the 12-angle action board and measured alpha/resource report
- [x] TEST: add failing runtime mapping/state/no-screen-spin coverage
- [x] INTEGRATE: replace the old player draw path with M2 READY/MOVE/FIRE atlases
- [x] CAPTURE: inspect the actual 1280x720 combat result
- [x] VERIFY: run Godot, Python, manifest, registry, and diff checks
- [x] COMMIT: create focused local commits and send completion email
- [ ] NEXT: create a separate Dasher movement-animation preview increment
