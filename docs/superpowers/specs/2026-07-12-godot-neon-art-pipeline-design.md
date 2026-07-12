# Godot Neon Art Pipeline Design

## Objective

Create a project-local Codex skill that guides production of cohesive, high-resolution neon science-fiction artwork for this Godot 2D game. The skill will turn art requests into repeatable batches that are easy to review, name, import, and replace without changing gameplay behavior.

The first implementation establishes the workflow and standards only. Image generation begins after the workflow has been reviewed and validated.

## Visual Direction

- High-resolution illustrated assets rather than grid-constrained pixel art.
- Dark cyber-wasteland setting with cyan-blue and magenta neon accents.
- Strong silhouettes and controlled rim lighting so combat entities remain readable against effects and scenery.
- Detail concentrated inside major forms; avoid noisy edges that obscure collisions or movement.
- No embedded text in generated gameplay art or backgrounds.
- Consistent camera angle, material language, lighting direction, and accent palette across every batch.

## Project-Local Skill

Create `.agents/skills/godot-neon-art-pipeline/` with a concise `SKILL.md` and only the references needed by this project. The skill will trigger when creating, revising, evaluating, or importing visual assets for the game.

The skill will coordinate two existing capabilities:

1. Use `ai-image-prompts-skill` to search for suitable prompt structures and visual references.
2. Use `imagegen` to generate or revise the selected artwork.

The project-local skill remains the authority for style, dimensions, filenames, review gates, and Godot import requirements. External prompt examples may inspire composition but cannot override project constraints.

## Batch Sequence

### Batch 1: Characters, Enemies, and Combat Effects

Define the player, enemy families, projectiles, pickups, and major combat effects first. Generate isolated subjects on transparent backgrounds where possible. Review silhouettes at actual gameplay scale before approving detail or variants.

### Batch 2: Battlefield and Environment

Generate floor treatments, battlefield backgrounds, environmental structures, decals, and atmospheric overlays. These assets must preserve clear play space and remain lower contrast than actors and hazards.

### Batch 3: User Interface

Generate HUD ornaments, panels, buttons, frames, icons, and screen backdrops. UI components must support localization, avoid baked-in labels, and be suitable for stretch or nine-patch use where applicable.

Each batch requires approval of a small style-lock set before producing the remainder. A later batch must inherit the approved palette, lighting, materials, and shape language from earlier batches.

## Asset Contract

Every requested asset will have a compact manifest entry containing:

- Stable asset identifier and batch.
- Gameplay purpose and required silhouette.
- Target dimensions and aspect ratio.
- Background requirement: transparent, opaque, or composited overlay.
- Camera and facing direction.
- Palette and lighting notes.
- Expected Godot resource path and filename.
- Generation prompt, negative constraints, and reference lineage.
- Review state: draft, style-approved, gameplay-approved, or final.

Filenames will use lowercase snake case and semantic folders, for example `assets/art/actors/player/player_base.png`. Generated drafts will not overwrite approved assets.

## Godot Import Rules

- Prefer PNG for transparent actors, effects, icons, and UI components.
- Use lossless compression for interface and sharp-edged gameplay elements.
- Use mipmaps only for assets that are meaningfully downscaled or transformed in play.
- Choose filtering per asset class; high-resolution illustration may use linear filtering, while masks and intentionally crisp graphic elements must remain sharp.
- Keep source artwork separate from runtime-ready exports when source files exist.
- Verify pivot, scale, transparent padding, collision readability, and appearance at the project's actual viewport before approval.
- Treat generated artwork as presentation only; scene logic and collision shapes remain controlled by Godot resources and scripts.

## Workflow

1. Inspect the current scene, script, and viewport context for the requested asset.
2. Create or update the asset manifest entry.
3. Search the installed prompt library for up to three useful visual directions.
4. Select one direction and adapt it to the project style contract.
5. Generate a small style-lock set with `imagegen`.
6. Review transparency, anatomy, silhouette, palette, lighting, and gameplay-scale readability.
7. Iterate on rejected issues without changing approved characteristics.
8. Export the approved runtime asset to its semantic path.
9. Configure and verify Godot import behavior.
10. Record the approved prompt and lineage before proceeding to the next asset or batch.

## Error Handling and Safety

- Reject outputs with unreadable silhouettes, inconsistent perspective, baked-in text, accidental borders, opaque backgrounds where transparency is required, or palette drift.
- Never silently replace an approved resource; create a versioned draft and request comparison.
- Keep third-party prompt licenses separate from generated-output usage rights. Before shipping, confirm the image model's commercial-use terms and retain generation provenance.
- Do not commit API keys, provider credentials, temporary downloads, model caches, or tool-local state.
- If an output cannot satisfy transparency or exact layout constraints, generate separate layers or use a deterministic post-processing step rather than pretending the output is production-ready.

## Validation

Validate the skill itself with the repository's available skill validator. Then run representative workflow checks for one actor, one battlefield asset, and one UI component without requiring all final images to be generated.

For generated assets, acceptance requires:

- Correct format, dimensions, filename, and destination.
- Visual consistency with the approved style-lock set.
- Clear gameplay readability at intended scale.
- Correct import and rendering in Godot without warnings.
- No unintended changes to gameplay scripts, collisions, or unrelated user work.

## Out of Scope

- Generating all final assets during the workflow implementation.
- Replacing gameplay code, collision logic, or UI behavior.
- Installing the entire `simota/agent-skills` collection.
- Building a general-purpose art pipeline for unrelated projects.
