# Player Turnaround Technical Proof v2 — Audit

Date: 2026-08-12

## Outcome

The attempted repair was not promoted. All experimental renderer code and generated
preview assets were removed, and the production player path was left untouched.

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

The first checkpoint acquisition attempt was stopped after ten minutes because the
Xet transfer had not completed. Only metadata and resumable cache fragments exist
outside the repository; no incomplete weights or generated model were committed.

## Recovery gate

Resume only when the official multi-view weights are complete and load successfully.
Then create a review-only 12-angle board at exact 45-degree pitch. It must show body,
separate rifle/depth, composite, and alpha diagnostics. Do not generate the 120-frame
runtime set or change `Player.gd` until that board receives explicit approval.
