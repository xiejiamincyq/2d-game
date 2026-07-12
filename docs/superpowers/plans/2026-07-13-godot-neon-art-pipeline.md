# Godot Neon Art Pipeline Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build and validate a project-local Codex skill that produces consistent, high-resolution neon science-fiction art specifications and Godot-ready asset manifests in three approved batches.

**Architecture:** Keep the orchestration workflow in a concise `SKILL.md`, move stable visual and Godot import rules into two focused references, and make asset metadata deterministic through a JSON template plus a standard-library Python validator. Static contract tests and fresh-agent pressure scenarios provide RED/GREEN evidence without generating final game art during implementation.

**Tech Stack:** Codex Agent Skills, Markdown, JSON, Python 3 standard library, Godot 4.7 project conventions, PowerShell verification.

## Global Constraints

- Target a high-resolution illustrated style, not grid-constrained pixel art.
- Preserve the dark cyber-wasteland direction with cyan-blue and magenta neon accents.
- Use the batch order: characters/combat, battlefield/environment, then user interface.
- Require a small approved style-lock set before expanding any batch.
- Use transparent PNG for isolated actors, effects, pickups, icons, and UI elements where possible.
- Do not bake text into gameplay art, backgrounds, or UI components.
- Do not replace approved assets silently; create a draft with a distinct path or version.
- Keep gameplay scripts, collisions, and UI behavior out of scope.
- Keep API keys, provider credentials, downloaded prompt JSON, model caches, and temporary generation state out of Git.
- Preserve the current 1280×720 base viewport, `canvas_items` stretch mode, and `expand` aspect behavior.
- Do not modify or stage unrelated `.superpowers/sdd/` files already present in the worktree.

---

## File Map

- Create `.agents/skills/godot-neon-art-pipeline/SKILL.md`: trigger and end-to-end art workflow.
- Create `.agents/skills/godot-neon-art-pipeline/agents/openai.yaml`: Codex UI metadata.
- Create `.agents/skills/godot-neon-art-pipeline/references/style-guide.md`: palette, hierarchy, dimensions, and batch-specific visual rules.
- Create `.agents/skills/godot-neon-art-pipeline/references/godot-import.md`: current project scale and import acceptance rules.
- Create `.agents/skills/godot-neon-art-pipeline/assets/manifest-entry.json`: valid starter manifest for the first player asset.
- Create `.agents/skills/godot-neon-art-pipeline/scripts/validate_manifest.py`: deterministic manifest validation CLI.
- Create `scripts/tests/validate_art_pipeline_skill.py`: repository-level structural and behavioral contract tests.
- Use `.superpowers/art-pipeline-evidence/` only for temporary RED/GREEN pressure-test output; do not stage it.

### Task 1: Establish RED Contract and Baseline Behavior

**Files:**
- Create: `scripts/tests/validate_art_pipeline_skill.py`
- Temporary evidence only: `.superpowers/art-pipeline-evidence/baseline/`

**Interfaces:**
- Consumes: repository root and the approved design at `docs/superpowers/specs/2026-07-12-godot-neon-art-pipeline-design.md`.
- Produces: executable contract tests that later tasks must satisfy.

- [ ] **Step 1: Write the failing repository contract test**

Create `scripts/tests/validate_art_pipeline_skill.py` with this complete content:

```python
from __future__ import annotations

import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
SKILL = ROOT / ".agents" / "skills" / "godot-neon-art-pipeline"
VALIDATOR = SKILL / "scripts" / "validate_manifest.py"
TEMPLATE = SKILL / "assets" / "manifest-entry.json"


class ArtPipelineSkillTest(unittest.TestCase):
    def test_required_skill_files_exist(self) -> None:
        required = [
            SKILL / "SKILL.md",
            SKILL / "agents" / "openai.yaml",
            SKILL / "references" / "style-guide.md",
            SKILL / "references" / "godot-import.md",
            TEMPLATE,
            VALIDATOR,
        ]
        self.assertEqual([], [str(path.relative_to(ROOT)) for path in required if not path.is_file()])

    def test_skill_routes_prompt_search_generation_and_style_lock(self) -> None:
        text = (SKILL / "SKILL.md").read_text(encoding="utf-8")
        for phrase in (
            "ai-image-prompts-skill",
            "imagegen",
            "style-lock",
            "validate_manifest.py",
            "Never overwrite an approved asset",
        ):
            self.assertIn(phrase, text)

    def test_references_pin_current_project_constraints(self) -> None:
        style = (SKILL / "references" / "style-guide.md").read_text(encoding="utf-8")
        imports = (SKILL / "references" / "godot-import.md").read_text(encoding="utf-8")
        for phrase in ("1280×720", "#33fff2", "#f559bf", "1024×1024", "2560×1440"):
            self.assertIn(phrase, style.lower())
        for phrase in ("canvas_items", "collision radius", "lossless", "mipmaps", "nine-patch"):
            self.assertIn(phrase, imports.lower())

    def test_openai_metadata_mentions_the_skill(self) -> None:
        metadata = (SKILL / "agents" / "openai.yaml").read_text(encoding="utf-8")
        self.assertIn('$godot-neon-art-pipeline', metadata)
        self.assertIn('display_name: "Godot Neon Art Pipeline"', metadata)

    def test_manifest_template_is_valid(self) -> None:
        result = subprocess.run(
            [sys.executable, str(VALIDATOR), str(TEMPLATE)],
            cwd=ROOT,
            text=True,
            capture_output=True,
            check=False,
        )
        self.assertEqual(0, result.returncode, result.stdout + result.stderr)
        self.assertIn("VALID", result.stdout)

    def test_manifest_validator_rejects_unsafe_final_asset(self) -> None:
        data = json.loads(TEMPLATE.read_text(encoding="utf-8"))
        data["review_state"] = "final"
        data["license_review_state"] = "pending"
        with tempfile.TemporaryDirectory() as directory:
            invalid = Path(directory) / "invalid.json"
            invalid.write_text(json.dumps(data), encoding="utf-8")
            result = subprocess.run(
                [sys.executable, str(VALIDATOR), str(invalid)],
                cwd=ROOT,
                text=True,
                capture_output=True,
                check=False,
            )
        self.assertNotEqual(0, result.returncode)
        self.assertIn("license_review_state", result.stdout)


if __name__ == "__main__":
    unittest.main(verbosity=2)
```

- [ ] **Step 2: Run the contract test and verify RED**

Run:

```powershell
python scripts/tests/validate_art_pipeline_skill.py
```

Expected: FAIL because `.agents/skills/godot-neon-art-pipeline/` does not exist.

- [ ] **Step 3: Capture three fresh-agent baseline failures without the new skill**

Create `.superpowers/art-pipeline-evidence/baseline/` and dispatch one fresh subagent per prompt. Do not mention the intended workflow or acceptance rubric in the prompts.

Prompt A:

```text
Prepare the first production-ready art request for replacing the current procedural player drawing in this Godot project. Do not edit the project yet.
```

Prompt B:

```text
Prepare a production-ready art request for a neon cyber-wasteland battlefield background in this Godot project. Do not generate the image yet.
```

Prompt C:

```text
Prepare a production-ready art request for the pause-screen panel artwork in this Godot project. Do not edit the UI yet.
```

Save raw outputs as `actor.md`, `environment.md`, and `ui.md`. RED is confirmed when at least one response omits one or more of these requirements: project inspection, manifest fields, exact dimensions, runtime path, style-lock gate, license state, Godot import checks, or no-overwrite rule.

- [ ] **Step 4: Commit the RED contract only**

```powershell
git add scripts/tests/validate_art_pipeline_skill.py
git commit -m "test: define neon art pipeline contract"
```

Do not stage `.superpowers/art-pipeline-evidence/`.

### Task 2: Scaffold the Skill and Implement the Manifest Contract

**Files:**
- Create: `.agents/skills/godot-neon-art-pipeline/agents/openai.yaml`
- Create: `.agents/skills/godot-neon-art-pipeline/assets/manifest-entry.json`
- Create: `.agents/skills/godot-neon-art-pipeline/scripts/validate_manifest.py`
- Scaffold: `.agents/skills/godot-neon-art-pipeline/SKILL.md`

**Interfaces:**
- Consumes: a JSON manifest path supplied as the first CLI argument.
- Produces: `validate_manifest.py <path>` with exit code `0` and `VALID <path>` on success, or exit code `1` and one `ERROR ...` line per violation.

- [ ] **Step 1: Initialize the project-local skill with the official scaffold**

Run:

```powershell
$env:PYTHONUTF8 = "1"
python "C:\Users\21604\.codex\skills\.system\skill-creator\scripts\init_skill.py" godot-neon-art-pipeline --path ".agents/skills" --resources "scripts,references,assets" --interface "display_name=Godot Neon Art Pipeline" --interface "short_description=Prepare consistent neon sci-fi game art" --interface "default_prompt=Use `$godot-neon-art-pipeline to prepare the next approved art batch for this Godot project."
```

Expected: the skill directory is created with `SKILL.md` and `agents/openai.yaml`.

- [ ] **Step 2: Replace generated UI metadata with the exact supported interface**

Set `.agents/skills/godot-neon-art-pipeline/agents/openai.yaml` to:

```yaml
interface:
  display_name: "Godot Neon Art Pipeline"
  short_description: "Prepare consistent neon sci-fi game art"
  default_prompt: "Use $godot-neon-art-pipeline to prepare the next approved art batch for this Godot project."
```

- [ ] **Step 3: Write the valid starter manifest**

Set `.agents/skills/godot-neon-art-pipeline/assets/manifest-entry.json` to:

```json
{
  "schema_version": 1,
  "asset_id": "player_base",
  "batch": "characters-combat",
  "asset_class": "actor",
  "purpose": "Replace the procedural player body while preserving top-down combat readability.",
  "runtime_path": "res://assets/art/actors/player/player_base.png",
  "source_dimensions": {"width": 1024, "height": 1024},
  "runtime_target": {"width": 64, "height": 64},
  "aspect_ratio": "1:1",
  "background": "transparent",
  "camera": "top-down three-quarter",
  "facing": "right-facing neutral master",
  "palette": ["#061019", "#33fff2", "#f559bf", "#ff571f"],
  "lighting": "cool cyan rim light with restrained magenta bounce and warm weapon accent",
  "prompt": "High-resolution top-down three-quarter cyber-wasteland player operative, compact readable silhouette, cyan armor light, magenta secondary glow, warm weapon accent, isolated full body, transparent background, no text, no border.",
  "negative_constraints": [
    "no embedded text",
    "no opaque background",
    "no cropped limbs",
    "no photorealistic scenery",
    "no thin silhouette-breaking cables"
  ],
  "references": [],
  "generation_model": "imagegen",
  "license_review_state": "pending",
  "review_state": "draft"
}
```

- [ ] **Step 4: Write the deterministic manifest validator**

Set `.agents/skills/godot-neon-art-pipeline/scripts/validate_manifest.py` to:

```python
from __future__ import annotations

import json
import re
import sys
from pathlib import Path
from typing import Any


REQUIRED_TYPES: dict[str, type] = {
    "schema_version": int,
    "asset_id": str,
    "batch": str,
    "asset_class": str,
    "purpose": str,
    "runtime_path": str,
    "source_dimensions": dict,
    "runtime_target": dict,
    "aspect_ratio": str,
    "background": str,
    "camera": str,
    "facing": str,
    "palette": list,
    "lighting": str,
    "prompt": str,
    "negative_constraints": list,
    "references": list,
    "generation_model": str,
    "license_review_state": str,
    "review_state": str,
}
BATCHES = {"characters-combat", "environment", "ui"}
ASSET_CLASSES = {"actor", "enemy", "effect", "pickup", "background", "environment", "ui-panel", "ui-icon"}
BACKGROUNDS = {"transparent", "opaque", "overlay"}
REVIEW_STATES = {"draft", "style-approved", "gameplay-approved", "final"}
LICENSE_STATES = {"pending", "approved"}
ASSET_ID = re.compile(r"^[a-z0-9]+(?:_[a-z0-9]+)*$")
RUNTIME_PATH = re.compile(r"^res://assets/art/[a-z0-9_/]+\.png$")
HEX_COLOR = re.compile(r"^#[0-9a-fA-F]{6}$")


def validate_dimensions(name: str, value: Any, errors: list[str]) -> None:
    if not isinstance(value, dict):
        return
    if set(value) != {"width", "height"}:
        errors.append(f"{name} must contain only width and height")
        return
    for axis in ("width", "height"):
        if not isinstance(value[axis], int) or value[axis] <= 0:
            errors.append(f"{name}.{axis} must be a positive integer")


def validate(data: Any) -> list[str]:
    errors: list[str] = []
    if not isinstance(data, dict):
        return ["manifest root must be an object"]
    for key, expected_type in REQUIRED_TYPES.items():
        if key not in data:
            errors.append(f"missing required field: {key}")
        elif not isinstance(data[key], expected_type):
            errors.append(f"{key} must be {expected_type.__name__}")
    if errors:
        return errors
    if data["schema_version"] != 1:
        errors.append("schema_version must be 1")
    if not ASSET_ID.fullmatch(data["asset_id"]):
        errors.append("asset_id must use lowercase snake_case")
    if data["batch"] not in BATCHES:
        errors.append(f"batch must be one of {sorted(BATCHES)}")
    if data["asset_class"] not in ASSET_CLASSES:
        errors.append(f"asset_class must be one of {sorted(ASSET_CLASSES)}")
    if not RUNTIME_PATH.fullmatch(data["runtime_path"]):
        errors.append("runtime_path must be a lowercase PNG path below res://assets/art/")
    validate_dimensions("source_dimensions", data["source_dimensions"], errors)
    validate_dimensions("runtime_target", data["runtime_target"], errors)
    if data["background"] not in BACKGROUNDS:
        errors.append(f"background must be one of {sorted(BACKGROUNDS)}")
    if data["review_state"] not in REVIEW_STATES:
        errors.append(f"review_state must be one of {sorted(REVIEW_STATES)}")
    if data["license_review_state"] not in LICENSE_STATES:
        errors.append(f"license_review_state must be one of {sorted(LICENSE_STATES)}")
    if not data["purpose"].strip() or not data["prompt"].strip():
        errors.append("purpose and prompt must not be empty")
    if not data["negative_constraints"] or not all(isinstance(item, str) and item.strip() for item in data["negative_constraints"]):
        errors.append("negative_constraints must contain non-empty strings")
    if not data["palette"] or not all(isinstance(color, str) and HEX_COLOR.fullmatch(color) for color in data["palette"]):
        errors.append("palette must contain six-digit hex colors")
    if data["review_state"] == "final" and data["license_review_state"] != "approved":
        errors.append("license_review_state must be approved before review_state can be final")
    return errors


def main() -> int:
    if len(sys.argv) != 2:
        print("ERROR usage: validate_manifest.py <manifest.json>")
        return 2
    path = Path(sys.argv[1])
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        print(f"ERROR {error}")
        return 1
    errors = validate(data)
    if errors:
        for error in errors:
            print(f"ERROR {error}")
        return 1
    print(f"VALID {path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
```

- [ ] **Step 5: Run the manifest-focused tests**

Run:

```powershell
python -m unittest scripts.tests.validate_art_pipeline_skill.ArtPipelineSkillTest.test_manifest_template_is_valid scripts.tests.validate_art_pipeline_skill.ArtPipelineSkillTest.test_manifest_validator_rejects_unsafe_final_asset -v
```

Expected: both tests PASS.

- [ ] **Step 6: Commit the manifest contract**

```powershell
git add .agents/skills/godot-neon-art-pipeline/agents/openai.yaml .agents/skills/godot-neon-art-pipeline/assets/manifest-entry.json .agents/skills/godot-neon-art-pipeline/scripts/validate_manifest.py
git commit -m "feat: add neon art manifest contract"
```

### Task 3: Implement the Visual, Import, and Orchestration Guidance

**Files:**
- Replace: `.agents/skills/godot-neon-art-pipeline/SKILL.md`
- Create: `.agents/skills/godot-neon-art-pipeline/references/style-guide.md`
- Create: `.agents/skills/godot-neon-art-pipeline/references/godot-import.md`

**Interfaces:**
- Consumes: current project files, `ai-image-prompts-skill`, `imagegen`, and a manifest based on `assets/manifest-entry.json`.
- Produces: one validated asset request at a time, with explicit review state and runtime destination.

- [ ] **Step 1: Write the visual style reference**

Set `.agents/skills/godot-neon-art-pipeline/references/style-guide.md` to:

```markdown
# Neon Science-Fiction Style Guide

## Fixed Direction

Create high-resolution illustrated assets for a dark cyber-wasteland viewed from a top-down or top-down three-quarter camera. Preserve clean outer silhouettes and concentrate detail inside large forms so artwork remains readable during dense combat at the 1280×720 base viewport.

## Palette

- Background black-blue: `#061019`
- Primary cyan: `#33fff2`
- Secondary magenta: `#f559bf`
- Weapon and warning orange: `#ff571f`
- Acid green: reserve for Spitter attacks, healing, or explicit toxic cues

Do not give every asset all accent colors. Actors receive one dominant faction accent and one small functional accent. Backgrounds use lower saturation and contrast than actors, hazards, pickups, and HUD state.

## Lighting and Materials

- Use controlled cyan rim light as the shared scene light.
- Use magenta bounce light sparingly to separate planes.
- Reserve warm orange emission for player weapons, warnings, and high-priority interaction cues.
- Favor worn composite armor, oxidized metal, dark ceramic, smoked glass, exposed energy conduits, and dusty synthetic fabric.
- Avoid glossy showroom cyberpunk, crowded signage, photorealistic street scenes, thin loose cables, and decorative highlights that resemble hit effects.

## Source and Runtime Sizes

| Asset | Source target | Runtime target | Background |
|---|---:|---:|---|
| Player or standard enemy master | 1024×1024 | 64×64 | Transparent |
| Bruiser or large enemy master | 1024×1024 | 96×96 | Transparent |
| Pickup or projectile master | 512×512 | 24×24 to 48×48 | Transparent |
| Combat effect master | 1024×1024 | Determined by gameplay radius | Transparent or overlay |
| Battlefield background | 2560×1440 | 1280×720 base viewport | Opaque |
| Environment prop | 1024×1024 | 64×64 to 256×256 | Transparent |
| UI icon | 256×256 | 24×24 to 64×64 | Transparent |
| UI panel or frame | 2048×1024 | Responsive | Transparent, nine-patch-ready |

Keep transparent padding below 10% on isolated assets unless an effect needs intentional overflow. Keep contact points stable and place actor visual centers over their collision centers.

## Batch Gates

1. Characters/combat: approve player, one standard enemy, one large enemy, and one effect as the style-lock set.
2. Environment: approve one battlefield crop, one structure, and one atmospheric overlay before expanding the batch.
3. UI: approve one panel, one button treatment, and one icon family before expanding the batch.

Do not begin the next batch until the current style-lock set is approved.

## Rejection Conditions

Reject baked-in text, accidental borders, cropped anatomy, opaque halos around transparent assets, mixed camera angles, noisy silhouettes, unreadable faction colors, excessive bloom, background contrast that competes with hazards, and UI decoration that reduces label space.
```

- [ ] **Step 2: Write the Godot import reference**

Set `.agents/skills/godot-neon-art-pipeline/references/godot-import.md` to:

```markdown
# Godot Import and Gameplay Acceptance

## Current Project Facts

- Godot base viewport: 1280×720.
- Stretch mode: `canvas_items`; aspect: `expand`.
- Default canvas texture filtering is nearest, so high-resolution illustration assets may require per-texture linear filtering when downscaled.
- Player collision radius is 13 px.
- Standard enemy collision radius is 14 px; Bruiser collision radius is 24 px.
- Current actors and effects are procedural `_draw()` visuals. Replacing art must not change collision shapes, combat radii, movement, or damage behavior.

## Runtime Paths

Use lowercase snake_case under these roots:

- `res://assets/art/actors/`
- `res://assets/art/effects/`
- `res://assets/art/pickups/`
- `res://assets/art/environment/`
- `res://assets/art/ui/`

Keep editable source files outside runtime folders when they exist. Never commit `.godot/`, provider caches, API credentials, or temporary generation downloads.

## Import Rules

- Use PNG for transparent actors, effects, pickups, icons, and UI components.
- Use lossless compression for UI, masks, icons, and sharp gameplay elements.
- Enable mipmaps only when a texture is repeatedly downscaled, rotated, or viewed at varying scale; verify that mipmaps do not soften small icons or collision cues.
- Use linear filtering for high-resolution illustrated assets when nearest filtering causes shimmer or jagged downscaling. Keep masks and intentionally crisp graphic elements sharp.
- Do not hand-edit generated `.import` files. Configure import options through Godot and commit source assets plus stable Godot resources when needed.
- Keep actor pivots centered over collision shapes and align feet or contact shadows consistently.
- For UI panels, preserve a clean center region and explicit stretch margins suitable for `NinePatchRect`; never bake labels into nine-patch artwork.

## Acceptance Check

At actual gameplay scale, verify silhouette, faction color, facing, transparent edges, pivot, collision alignment, hit-flash readability, and visibility over the battlefield. At compact UI widths, verify nine-patch corners, label space, icon clarity, and contrast. Reject any asset that changes gameplay logic or only looks correct at source resolution.
```

- [ ] **Step 3: Write the project-local skill**

Set `.agents/skills/godot-neon-art-pipeline/SKILL.md` to:

```markdown
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

## Safety

- Do not change scripts, collisions, damage radii, UI behavior, or unrelated files while preparing art.
- Do not commit API keys, credentials, downloaded prompt libraries, provider caches, or temporary generation state.
- Do not claim transparency, exact typography, or production readiness without inspecting the actual output.
- When generation cannot meet a layout constraint, split the asset into layers or use deterministic post-processing.
```

- [ ] **Step 4: Run the full contract and Codex skill validators**

Run:

```powershell
$env:PYTHONUTF8 = "1"
python scripts/tests/validate_art_pipeline_skill.py
python "C:\Users\21604\.codex\skills\.system\skill-creator\scripts\quick_validate.py" ".agents/skills/godot-neon-art-pipeline"
```

Expected: all six repository tests PASS and the validator prints `Skill is valid!`.

- [ ] **Step 5: Commit the complete skill guidance**

```powershell
git add .agents/skills/godot-neon-art-pipeline
git commit -m "feat: add Godot neon art pipeline skill"
```

### Task 4: Forward-Test, Refine, and Verify the Skill

**Files:**
- Modify only if a pressure test exposes a concrete gap: `.agents/skills/godot-neon-art-pipeline/SKILL.md`, its two references, validator, template, or contract test.
- Temporary evidence only: `.superpowers/art-pipeline-evidence/green/`

**Interfaces:**
- Consumes: the same three prompts used in Task 1, now explicitly invoking `$godot-neon-art-pipeline`.
- Produces: three compliant asset requests and final verification evidence.

- [ ] **Step 1: Run the actor pressure scenario with a fresh agent**

```text
Use $godot-neon-art-pipeline to prepare the first production-ready art request for replacing the current procedural player drawing in this Godot project. Do not edit the project or generate the image yet.
```

Save the raw response to `.superpowers/art-pipeline-evidence/green/actor.md`. It must identify the current player collision radius, use a transparent 1024×1024 source with a 64×64 runtime target, provide `res://assets/art/actors/player/player_base.png`, set `review_state` to `draft`, set `license_review_state` to `pending`, and stop before generation.

- [ ] **Step 2: Run the environment pressure scenario with a fresh agent**

```text
Use $godot-neon-art-pipeline to prepare a production-ready art request for a neon cyber-wasteland battlefield background in this Godot project. Do not generate the image yet.
```

Save the raw response to `.superpowers/art-pipeline-evidence/green/environment.md`. It must specify 2560×1440 source, 1280×720 base runtime, opaque background, lower contrast in the playable center, no text or focal actors, a runtime path below `res://assets/art/environment/`, and a draft license state.

- [ ] **Step 3: Run the UI pressure scenario with a fresh agent**

```text
Use $godot-neon-art-pipeline to prepare a production-ready art request for the pause-screen panel artwork in this Godot project. Do not edit the UI yet.
```

Save the raw response to `.superpowers/art-pipeline-evidence/green/ui.md`. It must specify a transparent label-free panel, clean center region, nine-patch intent and stretch margins, responsive acceptance at compact widths, a path below `res://assets/art/ui/`, and no change to UI behavior.

- [ ] **Step 4: Close only observed loopholes and rerun the affected scenario**

Use these exact remediation locations:

- Missing manifest data or review states: strengthen `SKILL.md` Workflow steps 2 or 10.
- Palette, dimensions, contrast, or batch drift: strengthen `references/style-guide.md`.
- Filtering, mipmaps, pivot, collision, or nine-patch drift: strengthen `references/godot-import.md`.
- Validator accepts an unsafe state: add the failing case to `scripts/tests/validate_art_pipeline_skill.py` before changing `validate_manifest.py`.

Repeat the affected prompt with a new agent until every listed acceptance condition passes. Do not stage the raw evidence directory.

- [ ] **Step 5: Run final verification**

Run:

```powershell
$env:PYTHONUTF8 = "1"
python scripts/tests/validate_art_pipeline_skill.py
python "C:\Users\21604\.codex\skills\.system\skill-creator\scripts\quick_validate.py" ".agents/skills/godot-neon-art-pipeline"
node --check ".agents/skills/ai-image-prompts-skill/scripts/setup.js"
powershell -ExecutionPolicy Bypass -File scripts/tests/run_tests.ps1
git diff --check
git status --short
```

Expected: skill tests PASS, both skill validators succeed, all Godot suites pass with their normal pass markers, `git diff --check` emits nothing, and only intended art-pipeline files plus pre-existing unrelated `.superpowers/sdd/` files appear in status.

- [ ] **Step 6: Commit refinements if Task 4 changed tracked files**

```powershell
git add .agents/skills/godot-neon-art-pipeline scripts/tests/validate_art_pipeline_skill.py
git commit -m "test: harden neon art pipeline workflow"
```

If Task 4 required no tracked refinements, do not create an empty commit.

- [ ] **Step 7: Inspect and push completed work**

```powershell
git show --stat --oneline --first-parent HEAD
git status --short
git diff --check HEAD^1 HEAD
git push origin master
```

Expected: only completed art-pipeline work is committed; unrelated `.superpowers/sdd/` files remain untracked and untouched; push succeeds.
