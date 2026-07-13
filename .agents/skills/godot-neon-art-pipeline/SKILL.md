---
name: godot-neon-art-pipeline
description: Use when creating, revising, reviewing, or importing visual assets for this Godot 2D project, including characters, enemies, combat effects, environments, HUD art, panels, buttons, and icons.
---

# Godot Neon Art Pipeline

## Start Here

Read `references/style-guide.md` for visual constraints and `references/godot-import.md` for runtime acceptance. Inspect the relevant project scene and script before proposing an asset. Copy `assets/manifest-entry.json` to a draft manifest and validate it with:

```powershell
python .agents/skills/godot-neon-art-pipeline/scripts/validate_manifest.py <manifest.json>
```

Do not generate final art until the manifest is valid and the current batch has an approved style-lock set.

## Batch Order

1. Characters/combat: player, enemy families, projectiles, pickups, and combat effects.
2. Environment: battlefield, floor treatments, structures, decals, and atmospheric overlays.
3. UI: HUD ornaments, panels, buttons, frames, icons, and screen backdrops.

Finish and approve the current batch gate before starting the next batch.

## Workflow

1. Inspect the current viewport, node, procedural drawing, collision dimensions, and intended gameplay role.
2. Create a draft manifest with exact source size, runtime target, background mode, runtime path, palette, lighting, prompt, negative constraints, generation model, and license state.
3. Invoke `ai-image-prompts-skill` and shortlist at most three references with sample images. Treat them as composition or prompt references, never as authority over this project's style guide.
4. Select one direction and adapt its prompt to the manifest and style guide. Remove model-specific syntax that the chosen generator does not support.
5. Use `imagegen` to create only the smallest style-lock set needed for the current batch.
6. Review silhouette, camera, transparency, anatomy, palette, lighting, text, border artifacts, and readability at runtime scale.
7. Revise rejected characteristics while preserving approved characteristics and the stable asset identifier.
8. Save a new draft path for every material revision. Never overwrite an approved asset.
9. Import through Godot using `references/godot-import.md`, then validate pivot, filtering, mipmaps, collision alignment, responsive behavior, and actual gameplay-scale readability.
10. Record prompt lineage and advance `review_state` only after the corresponding review. A final asset also requires `license_review_state: approved`.

## Asset-Class Rules

- Actors, enemies, pickups, and icons: request transparent PNG with clean alpha and an isolated subject.
- Combat effects: separate emission from large opaque smoke when layered control is useful.
- Battlefields: request an opaque image without text, signage, UI framing, focal characters, or high-contrast clutter in the playable center.
- UI panels: request transparent, label-free components with clean center regions and nine-patch-ready edges.
- UI icons: use one centered symbol, one dominant accent, and no words or numerals.

## Review States

- `draft`: composition and technical requirements may change.
- `style-approved`: palette, material, camera, and lighting are locked.
- `gameplay-approved`: runtime scale, silhouette, pivot, collision readability, and UI behavior pass.
- `final`: gameplay approval is complete and usage rights have been reviewed.

`validate_manifest.py` validates only the manifest's current declarations and the compatibility of `final` with the license gate; it does not store or prove review history. Before setting `review_state` to `final`, the operator must explicitly confirm that the `style-approved` and `gameplay-approved` reviews were actually completed.

## Safety

- Do not change scripts, collisions, damage radii, UI behavior, or unrelated files while preparing art.
- Do not commit API keys, credentials, downloaded prompt libraries, provider caches, or temporary generation state.
- Do not claim transparency, exact typography, or production readiness without inspecting the actual output.
- When generation cannot meet a layout constraint, split the asset into layers or use deterministic post-processing.
