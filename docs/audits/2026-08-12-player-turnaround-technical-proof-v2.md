# Player Turnaround Technical Proof v2 — Audit

Date: 2026-08-12

## Outcome

The original single-image repair was not promoted. A later official multi-view
reconstruction proved that the checkpoint, component-streamed loader, true-yaw
renderer, and exact 45-degree gameplay camera can run on this machine. Its visual
result was still rejected: both side-label variants produced nearly identical,
round, squat geometry that lost the approved armor identity. The production player
path remains untouched.

## What the proof established

1. The existing `player_turnaround_model_v1.glb` was reconstructed from a single
   image. Its front view is recognizable, but side and rear geometry collapse into
   dark or incomplete silhouettes. Texture and alpha changes cannot repair missing
   volume.
2. Reading actual RGBA alpha removes the old brightness-to-opacity error, but the
   approved 2D views still cannot be projected through `SCREEN_UV` onto arbitrary
   geometry. At profile angles, the artwork mask and the 3D silhouette diverge.
3. A procedural armor proxy remains stable through yaw and proves that an exact
   45-degree orthographic camera is feasible. It is only a geometry diagnostic and
   is far below the approved visual standard.
4. A rifle can be separated into its own 3D object and depth layer. This is the
   correct architecture, but it must be paired with a coherent body mesh rather
   than the rejected single-image reconstruction.

## Root cause

The failed pipeline tried to synthesize unseen anatomy after the fact: one source
image created the mesh, while unrelated 2D views were pasted in screen space. The
pipeline therefore had no shared three-dimensional identity across front, side,
and rear views. The visual failures were architectural, not tuning defects.

## Official model decision

Use Tencent's older official multi-view checkpoint, `tencent/Hunyuan3D-2mv`, for
the next proof. The repository publishes a dedicated 1.1B multi-view model and the
local Hunyuan code includes `MVImageProcessorV2`. The cached Hunyuan3D-2.1 model is
configured with a single-image encoder and must not be used as a silent fallback.

The official 4,928,151,562-byte checkpoint was subsequently acquired in the external
Codex cache. Its SHA256 matches the published value
`d36f5881bcdc56726b73e517cd444c13c60732431622da7268145355c8d38e9c`.
No model weights were committed.

The official loader exceeded the machine's practical memory limit because it held
the checkpoint and a second initialized parameter set at once. The project loader
now constructs Meta tensors, assigns the safetensors one component at a time, and
removes the VAE training-only encoder omitted from the official generation weights.
The load-only gate passed with 2,463,968,065 parameters and the approved front,
back, and right views; it did not mirror a left view or fall back to single-image
conditioning.

## Multi-view reconstruction result

Two review-only meshes were generated from the approved front, rear, and right-side
body references. Variant A treated the side reference as right; variant B treated
the same source as left. Both reconstructed coherent front/side/rear volume and
rendered twelve true-yaw frames at a measured 45-degree orthographic pitch. This
proves the technical path, but not the art.

Both variants failed the visual gate for the same reasons:

1. the armor planes collapsed into rounded, clay-like masses;
2. the body became too short and wide compared with the approved Player B identity;
3. the source views' gameplay-camera foreshortening was baked into the anatomy;
4. changing the side-view label did not materially change the failure.

The root input problem is now isolated: the approved images are gameplay views at a
45-degree pitch, not eye-level orthographic modeling views. They remain valid style
and gameplay references, but must not be used directly as canonical geometry views.

## Recovery gate

Create three review-only modeling-sheet candidates first. Each candidate must show
the same body-only character at eye level in exact orthographic front, right-profile,
and back views, with consistent scale and an empty neutral A-pose. After one sheet is
approved, use it for a new body reconstruction and render a 12-angle board at exact
45-degree gameplay pitch. Add the rifle only as a separate object/layer. Do not
generate the 120-frame runtime set or change `Player.gd` until that board receives
explicit approval.
