# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

**废土清剿协议 (Wasteland Protocol)** — a Windows-desktop 2D action roguelite built with **Godot 4.7 stable**. A run is six normal waves plus a final Boss battle (~5 minutes): portals burst enemies into the arena, kill streaks charge a 2.8 s overdrive burst, and wave rewards plus coins drive a settlement card shop. The art direction is the locked "clean chibi bio-farm" style; runtime visuals come from curated chibi PNG atlases in `assets/art` plus procedural effects, with imported audio tracks and synthesized SFX. The main scene is `scenes/Main.tscn`.

Game design, plans, and most docs are written in **Chinese**. Code identifiers, signal names, and comments are in English.

## Common Commands

Run the game: import `project.godot` in Godot 4.7, then `F5` (main scene) or `F6` (current scene). No build step.

Full strict test suite (from repo root):

```powershell
powershell -ExecutionPolicy Bypass -File scripts/tests/run_tests.ps1
```

Fast gameplay-only loop: `powershell -ExecutionPolicy Bypass -File scripts/tests/run_tests.ps1 -Group gameplay` (also `-Group art`, `-Group python`).

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

Each Godot suite in `scripts/tests/` runs as an isolated Godot process. A suite passes only if ALL of:

- exits within 120 s with exit code 0,
- emits exactly one `TEST PASS: <SuiteName> <positive-count>` marker,
- contains no `SCRIPT ERROR`, `ERROR:`, or `TEST FAIL:`,
- contains no ObjectDB / RID / "resources still in use" leak warnings.

Python art-pipeline suites (`scripts/tests/test_*.py` plus `validate_art_pipeline_skill.py`) run as isolated interpreter processes and must exit 0 with exactly one `Ran N tests` summary (`N >= 1`) and no `FAILED` line or `Traceback`. They need Python 3.10+ and Pillow; `PYTHON_BIN` overrides the interpreter.

When adding a Godot suite, register it in `$gameplayTests` or `$artTests` in `scripts/tests/run_tests.ps1` and honor the marker contract; new `test_*.py` files are discovered automatically. Use `TestSupport.stop_audio()` for fixtures that touch `AudioManager` to avoid leaking players.

## High-Level Architecture

Everything is driven from `scripts/Main.gd` (a `Node2D` that builds the world at runtime — there is almost nothing in `Main.tscn`). Main owns:

- A state machine `RunState { START, WAVE_INTRO, PLAYING, BOSS_INTRO, WAVE_CLEAR, SETTLEMENT, PAUSED, RESULT }` with a whitelist of legal transitions (`_transition_to`). **`get_tree().paused = ...` may only appear in `Main.gd`** — the pre-push `prepush.ps1` check enforces this. Every state except `START` and `PLAYING` pauses the tree; gameplay nodes run as `PROCESS_MODE_PAUSABLE`, while `Main`, `GameUI`, `UpgradeSystem`, and `AudioManager` run as `PROCESS_MODE_ALWAYS`.
- Four paused containers under `World`: `Enemies`, `Projectiles`, `Portals`, `Pickups`. Everything spawned into the run goes into one of these so pause is uniform.
- Signals flowing one direction: gameplay objects emit signals (`Enemy.died`, `Player.fired`, `UpgradeSystem.choices_ready`, …); `Main` and `GameUI` subscribe and react. Gameplay nodes do not call into UI.

Key systems and their responsibilities:

- `scripts/systems/WaveDirector.gd` — owns the six-wave table plus the final Boss phase, the `SpawnPortal` burst queue, the `active_enemies` registry, and victory detection. It emits a single kill fact per death and defers drop spawning to `Main`. Other systems should consume `get_active_enemies()` instead of scanning the `"enemies"` group.
- `scripts/systems/UpgradeSystem.gd` — the progression and economy hub: wave rewards, coins (`add_coins`/`spend_coins`), the settlement card shop (`prepare_settlement`, `claim_free_offer`, `purchase_settlement_offer`), upgrade application, and snapshot state round-tripping. Settlement offers and upgrade choices are transactional; forged or duplicate requests are rejected.
- `scripts/systems/RunSnapshotStore.gd` — versioned atomic run snapshots for the continue flow; corrupt or unknown-version saves fall back safely to a new game.
- `scripts/systems/CombatFeedback.gd` (with `scripts/effects/CombatVfx.gd` and `CameraEffects.gd`) — bounded combat feedback: VFX, camera impact, and merged hit-stop requests capped at 35 ms per rolling 100 ms window.
- `scripts/systems/AudioManager.gd` — synthesizes one-shots via `AudioStreamGenerator` on a fixed pool of 16 voices plus one laser-loop player; imported tracks (e.g. the industrial BGM) are separate stream players. Tests must run with `--audio-driver Dummy` so Windows audio handles cannot outlive a headless suite.
- `scripts/components/DamageTypes.gd` — the canonical `StringName` constants for damage sources. Anything that deals damage should pass one of these; anything that reacts to damage should key off them.
- `scripts/components/HealthComponent.gd` — atomic health/shield bookkeeping, `can_accept_damage()`, and the post-hit invulnerability window used by `Player.take_damage`. Refused hits must not refresh invulnerability.
- `scripts/actors/Player.gd` — movement, primary fire (multi-line, inertial projectiles, grenades), dash sweep damage, drones with turning laser rays, arc pulse, spike traps, burn stacking, stealth, and the overdrive window. Dash melee sweeps are geometric (`_distance_to_segment`), not physics collision.
- `scripts/actors/OverseerBoss.gd` + `scripts/components/BossAttackDirector.gd`/`TentacleAttack.gd`/`BossProjectilePattern.gd` — the final Boss: staged entrance, health bar contract, tentacle strikes, and aimed-fan projectile patterns.
- `scripts/actors/Enemy.gd` — enemy kinds with kind-specific movement and attack windups, speed tiers, stealth interactions, and wave scaling applied in `setup()`.
- `scripts/world/ArenaLayout.gd`/`ArenaObstacle.gd` — the seeded obstacle arena with a shared navigation flow field and versioned layout compatibility.
- `scripts/ui/GameUI.gd` — instantiates HUD, settlement/shop, pause, and result screens from `scenes/ui/*.tscn` and re-exposes a compatibility surface used by `Main` and tests. UI is a `CanvasLayer` at layer 20 and always-process so it stays interactive while the tree is paused.

## Plan Status

The "five-minute overdrive" plan (`tasks/plan.md`, `tasks/todo.md`) is implemented and merged to `master`; the run structure is six normal waves plus the final Boss. Four manual playtest sign-offs remain open in `tasks/todo.md` (Checkpoints G and H). `docs/release/2026-08-30-release-readiness.md` is the release source of truth: asset license review, Phase 19/20 and Boss playtest sign-off, and minimum-hardware validation still block release.

High-conflict files when running parallel worktrees: `Player.gd`, `Enemy.gd`, `Main.gd`, `WaveDirector.gd`, `UpgradeSystem.gd`, `run_tests.ps1`.

## Working Agreements (from `AGENTS.md`)

- After a change is complete and verified, commit it as a focused commit and push the current branch to `origin`.
- Before each push: run the most relevant verification, report failures honestly, and never push secrets, generated `.godot/` state, `.worktrees/`, or unrelated `.superpowers/sdd` evidence files.
- Do not change repository visibility, remotes, branch protection, or rewrite history without explicit user approval.

## Performance Baseline

`docs/performance/wave-8-baseline.md` records the historical accepted ceiling; the current gates live in `PerformanceTest` (250 endgame-strength enemies, five portal bursts at 30/60/120 Hz, Boss projectile/VFX recycling, fixed audio voices) as documented in `docs/testing.md`. Do not add object pooling or a spatial index without a fresh profiler capture showing a real spike.
