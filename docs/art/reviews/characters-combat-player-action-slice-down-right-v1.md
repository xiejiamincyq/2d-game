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

## Deliberate limitations

- The slice is not connected to `Player.gd` or the main game scene.
- Only one facing direction exists; front, rear, side, and intermediate directions remain ungenerated.
- The dash trail, muzzle flash, shells, and hit burst are intentionally absent from the actor layers and should remain separate effects.
- License review is still pending, so the manifest remains `draft`.
- The layer split is suitable for this down-right view, but each additional direction must receive its own occlusion review.

## Next gate

The user should review the Godot capture. If accepted, the next safe increment is to integrate this single direction behind a preview-only player visual path and verify it in actual combat before producing more directions.

Prompt lineage uses the local YouMind community prompt references `27303` and `26830`, adapted to the project's locked camera, palette, and runtime contract.
