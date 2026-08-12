# Player B action slice — down-right v1

## Scope and decision

The user's `continue` instruction was treated as approval to proceed with the recommended **B — snappy arcade** motion language. This is still a one-direction vertical slice, not approval to expand the complete 24-direction set.

## Implemented contract

- Five actions: `idle`, `run`, `fire`, `dash`, and `hit`.
- Six chronological frames per action; 30 frames total.
- One locked down-right yaw under the approved 45-degree orthographic camera.
- Three runtime layers in this exact order: `weapon_behind`, `body`, `weapon_front`.
- One reusable rifle master translated between frames without per-frame rotation.
- `grip` and `muzzle` sockets for every frame.
- One invariant weapon vector, `(19, 4)`, across all 30 frames.
- 64×64 frames packed into 384×320 atlases.

## Runtime review

The Godot acceptance board renders all 30 layered frames at gameplay scale, shows the 13px collision radius, draws the grip and muzzle markers, and includes one live playback instance for each action. The body retains real leg and weight changes instead of whole-sprite bobbing. The rifle follows the hands and never performs screen-space rotation.

The slice is now connected to the actual `Player.gd` rendering path for the 45-degree down-right direction slot. The combat capture uses the real main scene, camera, floor, HUD, projectile container, and enemy actors. At 64px gameplay scale the actor remains centered over the unchanged 13px collision origin, the rifle reads in front of and behind the hands in the intended order, and the cyan silhouette stays readable against the battlefield.

The approved slice owns only the 37.5-52.5 degree slot. Every other aim angle falls back to the existing turnaround atlas and weapon renderer. Projectile direction remains continuous and gameplay-driven; only the visual pose is quantized inside the approved slot. Visual action priority is `hit > dash > fire > run > idle`, and the dash row plays at 36 FPS so its six frames fit the existing 0.16-second dash without changing movement timing.

## Deliberate limitations

- Only one facing direction exists; front, rear, side, and intermediate directions remain ungenerated.
- Outside the approved 15-degree slot, the legacy continuously rotated weapon remains visible until its direction receives a matching layered slice.
- The dash trail, muzzle flash, shells, and hit burst are intentionally absent from the actor layers and should remain separate effects.
- License review is still pending, so the manifest remains `draft`.
- The layer split is suitable for this down-right view, but each additional direction must receive its own occlusion review.

## Next gate

The user should review the actual combat capture. If accepted, the next safe increment is a small front/side/rear cardinal preview set with the same body/weapon split and occlusion contract. Full direction production remains blocked until that preview set is approved.

Prompt lineage uses the local YouMind community prompt references `27303` and `26830`, adapted to the project's locked camera, palette, and runtime contract.
