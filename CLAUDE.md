# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

**废土清剿协议 (Wasteland Protocol)** — a Windows-desktop 2D cyber-wasteland roguelite built with **Godot 4.7 stable**. All visuals are drawn procedurally in `_draw()` and all audio is synthesized at runtime; there are no imported art or audio assets. The main scene is `scenes/Main.tscn`.

Game design, plans, and most docs are written in **Chinese**. Code identifiers, signal names, and comments are in English.

## Common Commands

Run the game: import `project.godot` in Godot 4.7, then `F5` (main scene) or `F6` (current scene). No build step.

Full strict test suite (from repo root):

```powershell
powershell -ExecutionPolicy Bypass -File scripts/tests/run_tests.ps1
```

Single test suite (headless):

```powershell
godot --headless --path . --script res://scripts/tests/DamageTest.gd --quit-after 120
```

If `godot` is not on `PATH`, set `GODOT_BIN` to the absolute path of the Godot 4.7 console executable; the strict runner also auto-discovers WinGet installs.

Pre-push checks (from `docs/testing.md`) — one script runs whitespace, paused-ownership, secret-scan, and the strict suite:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/tests/prepush.ps1
```

## Strict Test Contract

Each suite in `scripts/tests/` runs as an isolated Godot process. A suite passes only if ALL of:

- exits within 120 s with exit code 0,
- emits exactly one `TEST PASS: <SuiteName> <positive-count>` marker,
- contains no `SCRIPT ERROR`, `ERROR:`, or `TEST FAIL:`,
- contains no ObjectDB / RID / "resources still in use" leak warnings.

When adding a test suite, register it in `$tests` in `scripts/tests/run_tests.ps1` and honor the marker contract. Use `TestSupport.stop_audio()` for fixtures that touch `AudioManager` to avoid leaking players.

## High-Level Architecture

Everything is driven from `scripts/Main.gd` (a `Node2D` that builds the world at runtime — there is almost nothing in `Main.tscn`). Main owns:

- A state machine `RunState { START, PLAYING, UPGRADE, PAUSED, RESULT }` with a whitelist of legal transitions (`_transition_to`). **`get_tree().paused = ...` may only appear in `Main.gd`** — the pre-push `rg` check enforces this. `UPGRADE`, `PAUSED`, and `RESULT` all pause the tree; gameplay nodes run as `PROCESS_MODE_PAUSABLE`, while `Main`, `GameUI`, `UpgradeSystem`, and `AudioManager` run as `PROCESS_MODE_ALWAYS`.
- Three paused containers under `World`: `Enemies`, `Projectiles`, `Pickups`. Everything spawned into the run goes into one of these so pause is uniform.
- Signals flowing one direction: gameplay objects emit signals (`Enemy.died`, `Player.fired`, `UpgradeSystem.choices_ready`, …); `Main` and `GameUI` subscribe and react. Gameplay nodes do not call into UI.

Key systems and their responsibilities:

- `scripts/systems/WaveDirector.gd` — owns the 8-wave table, the spawn queue, the `active_enemies` registry, and victory detection. It emits a single `enemy_killed(xp)` fact per death and defers XP/shield drop spawning to `Main`. Other systems should consume `get_active_enemies()` instead of scanning the `"enemies"` group (Player keeps one group-scan fallback only for isolated test fixtures).
- `scripts/systems/UpgradeSystem.gd` — XP curve, level-ups, three-choice upgrade pool, and a transactional `_transaction` token + `choice_generation` guard so forged, duplicate, or out-of-order choices are rejected. When multiple level-ups queue, it presents them one at a time and emits `upgrade_queue_completed` when drained.
- `scripts/systems/AudioManager.gd` — synthesizes every sound via `AudioStreamGenerator`/`_make_tone`/`_make_impact`. Maintains a fixed pool of 16 one-shot voices plus one laser-loop player; hit sounds are rate-limited per `DamageTypes` source so 100 hits never grow the audio subtree. Map new damage sources through `hit_stream_names`.
- `scripts/components/DamageTypes.gd` — the canonical `StringName` constants for damage sources (`GENERIC`, `PROJECTILE`, `LASER`, `ARC`, `DASH`, `SPIKE`). Anything that deals damage should pass one of these; anything that reacts to damage should key off them.
- `scripts/components/HealthComponent.gd` — atomic health/shield bookkeeping, `can_accept_damage()`, and the 0.35 s post-hit invulnerability window used by `Player.take_damage`. Refused hits must not refresh invulnerability.
- `scripts/actors/Player.gd` — movement, primary fire (multi-line), dash (165 px / 0.16 s sweep damage), drones + laser beams, arc pulse, spike traps. Dash melee sweeps are geometric (`_distance_to_segment`), not physics collision, so they cannot miss at high frame rates.
- `scripts/actors/Enemy.gd` — four kinds (`SCRAPPER`, `DASHER`, `SPITTER`, `BRUISER`) with kind-specific movement, melee windup/recovery, and the spitter's ranged attack. Wave scaling is applied in `setup()` from the wave index.
- `scripts/ui/GameUI.gd` — instantiates `HUD`, `UpgradeScreen`, `PauseScreen`, `ResultScreen` from `scenes/ui/*.tscn` and re-exposes a compatibility surface of node references used by `Main` and tests. UI is a `CanvasLayer` at layer 20 and always-process so it stays interactive while the tree is paused.

## Active Plan

The repo is mid-migration to a "five-minute overdrive" design. **`tasks/plan.md` is the single source of truth** for the unified implementation plan (21 tasks, 5 checkpoints, dependency graph, acceptance criteria). `tasks/todo.md` is the checkbox view. Older plans survive only in git history (`6dbd19a`, `8059c4b`); do not resurrect them.

High-conflict files when running parallel worktrees: `Player.gd`, `Enemy.gd`, `Main.gd`, `WaveDirector.gd`, `UpgradeSystem.gd`, `run_tests.ps1`.

## Working Agreements (from `AGENTS.md`)

- After a change is complete and verified, commit it as a focused commit and push the current branch to `origin`.
- Before each push: run the most relevant verification, report failures honestly, and never push secrets, generated `.godot/` state, `.worktrees/`, or unrelated `.superpowers/sdd` evidence files.
- Do not change repository visibility, remotes, branch protection, or rewrite history without explicit user approval.

## Performance Baseline

`docs/performance/wave-8-baseline.md` records the accepted ceiling: 250 wave-8 enemies, ≤399 nodes total, ≤17 audio players after 100 hits, ~0.1 ms for 1,000 registry lookups. Do not add object pooling or a spatial index without a fresh profiler capture showing a real spike.
