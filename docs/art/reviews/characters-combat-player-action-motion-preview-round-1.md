# Player action motion preview — round 1

## Review gate

Choose one motion language before any layered production animation is generated. All three candidates lock the same approved player identity, down-right facing, 45-degree orthographic camera, 64px target, and two-hand rifle relationship.

The five rows are `idle`, `run`, `fire`, `dash`, and `hit`; the six columns are chronological frames.

## Candidates

- **A — grounded tactical:** restrained recoil and compact weight shifts. It is the calmest option, but the idle frames are close together and the dash reads less strongly at 64px.
- **B — snappy arcade:** stronger anticipation, stride spacing, recoil, dash lean, and hit silhouette. This is the recommended fit for the current top-down shooter because each action survives the 64px reduction without turning the rifle into a separate spinning object.
- **C — heavy cinematic:** slow armor inertia, deeper recoil absorption, a low dash, and the strongest stagger. It conveys mass well, but baked dust and the slower cadence may reduce clarity when many enemies and effects overlap.

## What is deliberately not approved yet

- These are composite motion studies, not production sprites.
- The body, `weapon_behind`, and `weapon_front` layers have not been generated.
- Grip and muzzle sockets have not been authored.
- No candidate has been expanded to the full 24-direction set.
- No candidate has replaced the current player scene or control code.

## Next step after selection

Use only the chosen candidate as a cadence and pose reference. Produce one down-right vertical slice with separately aligned body, rear weapon mask, front weapon mask, composite reference, grip socket, and muzzle socket. Import that slice into a dedicated Godot preview scene and validate alpha, pivot, occlusion, and playback before generating more directions.

Prompt references were adapted from the local YouMind community prompt library entries `27303` and `26830`.
