# Player B cardinal layered previews v1 — style approved

## Scope

This batch covers three true-yaw directions only: front, right-side profile, and rear. On 2026-08-12 the user explicitly approved A/front, B/right side, and C/rear with the decision `可以通过`. This approval locks the visual direction but does not add the previews to `Player.gd` or claim production-ready animation coverage.

## Preview contract

- The same Player B armor identity, proportions, cyan visor, backpack, and restrained neon accents are preserved across all three views.
- The camera target remains the project's locked 45-degree orthographic look; each result exposes the helmet crown and upper planes instead of rotating a horizontal sprite.
- The body and rifle are separate assets. No complete character sprite is rotated to aim.
- Runtime composition uses `weapon_behind -> body -> weapon_front`.
- Front places the foreshortened rifle in front, right-side splits stock/barrel around the body, and rear places the rifle behind the body.
- The Godot review board shows enlarged composites, separated layers, and the actual 64px gameplay result over the unchanged 13px collision marker.

## Review findings

The front, profile, and rear silhouettes are materially different constructions rather than rotated copies. All source bodies have real transparent backgrounds and complete alpha bounds; the runtime atlases have transparent corners and no full-frame haze. At 64px the visor, backpack, stance, and cardinal yaw remain readable.

The raster output cannot independently prove a numerical camera pitch, so the review board exposed the 45-degree target for human judgment instead of treating the prompt text as proof. The user accepted that visual result; it is now the camera reference for further Player B direction work.

## Deliberate limitations

- These are neutral pose direction samples, not run, fire, dash, hit, or enemy motion animations.
- Left-side mirroring is not approved by this batch; only the right profile is shown.
- The rear rifle is mostly occluded in the composite by design, but remains inspectable in the separated layer row.
- Intermediate yaws may now be developed against this style lock, but each new angle still requires anatomy, silhouette, camera, and occlusion review.
- Gameplay integration, motion coverage, pivot behavior, and collision readability outside these three static samples remain unapproved.
- License review is pending, so the asset cannot advance to `final`.

## Approval result

`style-approved`: A/front, B/right side, and C/rear are accepted as the production reference for Player B's true-yaw body turn and `weapon_behind -> body -> weapon_front` occlusion model.

Prompt lineage uses the local YouMind community prompt references `27303` and `26830`, adapted to the project's camera, palette, identity, and runtime-layer contract.
