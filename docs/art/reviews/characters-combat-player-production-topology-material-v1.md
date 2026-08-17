# Player Production Topology and Material Candidates v1 Review

Date: 2026-08-13; selection recorded 2026-08-17
Review state: M2 selected for bounded technical bake proof

## Outputs and reading order

- material comparison board:
  `docs/art/previews/characters-combat/player-production-material-comparison-v1.png`
- M1, M2, and M3 separate sheets:
  `docs/art/previews/characters-combat/player-production-material-m1-v1.png`,
  `player-production-material-m2-v1.png`, and
  `player-production-material-m3-v1.png`
- source/candidate topology board:
  `docs/art/previews/characters-combat/player-production-topology-comparison-v1.png`
- transparent 64-pixel technical atlas:
  `assets/art/actors/player/technical_previews/player_production_material_candidates.png`
- metrics:
  `docs/art/reviews/characters-combat-player-production-topology-material-metrics-v1.json`

On the material board, rows are M1, M2, and M3. Columns are real world yaw 0, 90,
180, and 270 degrees. Every cell uses the same A2 pose, compact candidate mesh,
separate rifle, fixed-world lighting, framing, and exact 45-degree orthographic
camera.

On the topology board, the first two rows are the full source body mesh at 0 through
330 degrees, and the last two rows are the automatic LOD topology candidate at the
same angles. The unchanged rifle is hidden in this board so it cannot bias the body-
silhouette IoU. The grey top bars mark source rows; cyan bars mark candidate rows.

## Topology result and classification

Godot's `ImporterMesh.generate_lods()` path, backed by meshoptimizer, generated
twelve LOD index levels. The review candidate selects the first level, then
deterministically removes unreferenced vertices:

- source: 94,652 vertices, 567,888 indices, 189,296 triangles;
- candidate: 47,326 vertices, 283,944 indices, 94,648 triangles;
- vertex and index ratios: 50 percent;
- four-slot bone indices and weights: preserved;
- body-only minimum silhouette IoU across twelve angles: 0.995536;
- declared silhouette gate: 0.97.

This is an automatic LOD topology candidate. It is useful and reproducible for the
sprite-render pipeline, but it is not described or promoted as hand-authored
production retopology. Formal deformation topology, UV seams, material masks, and
authoring ergonomics still require a separate production decision.

## Material directions

- **M1 — Charcoal tactical composite.** Worn carbon-like dark panels, restrained
  cyan identifier bands, and a warm independent rifle. It matches the established
  palette closely, but fixed-world shadow makes profile and rear views quieter.
- **M2 — Industrial salvage alloy.** Weathered light-grey armor, dark flexible
  underlayer, cool blue conduits, and a warm rifle. It has the strongest anatomy
  separation at the eventual 64-pixel scale and is the readability recommendation.
- **M3 — Smoked ceramic stealth.** Dark ceramic surfaces, concentrated cyan bands,
  a measured magenta waist accent, and a brighter amber-orange rifle. It has the
  strongest neon identity but the darkest non-emissive body mass.

The preview-only generated material-language board established surface roughness,
wear, and metal/nonmetal separation. It contained material tiles only and did not
generate or edit the character. The final comparison boards are deterministic
Godot renders and preserve all geometry/camera invariants.

## Technical and alpha result

- four cardinal yaw samples per material, twelve material frames total;
- minimum high-opacity share among visible pixels: 92.45 percent;
- partial alpha is limited to MSAA silhouette edges; no broad body transparency is
  visible and transparent atlas corners remain zero alpha;
- maximum firing-hand error: 0.0000001341 world units;
- maximum support-hand error: 0.0000000745 world units;
- maximum shoulder-stock error: zero;
- all contact errors remain far below the 0.006-unit tolerance;
- M2 mean visible luminance is 0.4679 versus M1 at 0.2416 and M3 at 0.1999;
- M3 magenta visible-pixel share is 1.68 percent, preventing it from collapsing
  into a duplicate of M1.

## Reference handling

The prompt-reference library was refreshed on 2026-08-13 and supplied three
sample-backed references: prompt 27303 for matte-black brutalist composite, prompt
25446 for light/dark industrial recovery-unit blocking, and prompt 27028 for
cyan/amber low-key separation. Their sample images were inspected from the supplied
YouMind URLs but were not committed, copied into runtime assets, or used as texture
inputs. Third-party reference licensing therefore remains pending and isolated from
the project deliverables.

## Selection and next bounded gate

M2 was selected on 2026-08-17 because its body masses remain readable under the real
camera and at 64-pixel runtime scale. The selection authorizes one bounded READY-pose
120-yaw technical bake proof with separate 3D body and rifle source objects. It does
not authorize `Player.gd` changes, production atlas replacement, collision changes,
gameplay integration, or promotion of this LOD candidate as hand-authored retopology.
