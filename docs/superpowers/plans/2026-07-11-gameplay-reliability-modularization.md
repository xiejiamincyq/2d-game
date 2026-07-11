# Gameplay Reliability and Modularization Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Deliver deterministic combat, safe physics mutations, isolated tests, Main-owned run state, transactional upgrades, modular responsive UI, and bounded runtime costs for the Godot 4.7 game.

**Architecture:** Correctness changes establish explicit value-returning contracts and pure helpers before state or UI refactors consume them. Main becomes the only run-state and pause owner, while focused UI scenes and UpgradeSystem communicate solely through signals. Separate Godot processes verify each suite, and low-risk registry, redraw, and audio changes precede any profiler-gated pooling work.

**Tech Stack:** Godot 4.7, GDScript, PowerShell 7-compatible test runner, headless `SceneTree` tests, Git.

## Global Constraints

- Keep runtime-generated visuals and audio; add no external art or audio assets.
- Keep the current wave/enemy/upgrade dictionaries; do not migrate them to Resources in this plan.
- Main is the only production script allowed to assign `SceneTree.paused`.
- Catch-up work is bounded to four player shots and eight enemy spawns per frame.
- Spawn safety distance is 430 logical pixels and dash distance is 165 logical pixels.
- Target Godot is exactly 4.7; acceptance sizes are 960x540, 1280x720, 1920x1080, and 2560x1080.
- Do not add object pooling or a spatial index unless the recorded profile proves it is needed.
- Preserve unrelated `.superpowers/sdd` working-tree artifacts without staging them.

---

### Task 1: Accepted damage transaction

**Files:**
- Create: `scripts/tests/DamageTest.gd`
- Modify: `scripts/components/HealthComponent.gd`
- Modify: `scripts/actors/Player.gd`

**Interfaces:**
- Produces: `HealthComponent.can_accept_damage() -> bool`, `HealthComponent.damage(amount: float, ignore_invulnerability := false) -> bool`, `HealthComponent.begin_invulnerability(seconds: float) -> void`, and `Player.take_damage(amount: float, source := DamageTypes.GENERIC) -> bool`.
- Consumes: Player shield and health signals.

- [ ] **Step 1: Write the focused failing test**

Create a `SceneTree` test that constructs a Player, gives it 20 shield, calls `take_damage(8.0)` at 0.1-second intervals by decrementing the component timer through `_process(0.1)`, and asserts the accepted sequence is `true, false, false, false, true`. Assert shield becomes 4, health is unchanged, and rejected hits do not increase `invulnerable_time`. Print `TEST PASS: DamageTest <count>` after freeing the fixture and waiting two frames; on failure print `TEST FAIL: DamageTest: <message>` and `quit(1)`.

- [ ] **Step 2: Verify RED**

Run:

```powershell
godot --headless --path . --script res://scripts/tests/DamageTest.gd --quit-after 120
```

Expected: non-zero because current `take_damage` has no boolean accepted-hit contract and consumes shield during rejected hits.

- [ ] **Step 3: Implement the health gate**

Use these component methods:

```gdscript
func can_accept_damage() -> bool:
	return current_health > 0.0 and invulnerable_time <= 0.0

func damage(amount: float, ignore_invulnerability: bool = false) -> bool:
	if amount <= 0.0 or current_health <= 0.0:
		return false
	if not ignore_invulnerability and not can_accept_damage():
		return false
	current_health = maxf(0.0, current_health - amount)
	health_changed.emit(current_health, max_health)
	if current_health <= 0.0:
		died.emit()
	return true

func begin_invulnerability(seconds: float) -> void:
	invulnerable_time = maxf(invulnerable_time, seconds)
```

Implement Player as one transaction:

```gdscript
func take_damage(amount: float, _source: StringName = DamageTypes.GENERIC) -> bool:
	if health == null or amount <= 0.0 or not health.can_accept_damage():
		return false
	var remaining := amount
	if shield > 0.0:
		var absorbed := minf(shield, remaining)
		shield -= absorbed
		remaining -= absorbed
		shield_changed.emit(shield, max_shield)
	if remaining > 0.0:
		health.damage(remaining, true)
	health.begin_invulnerability(0.35)
	return true
```

- [ ] **Step 4: Verify GREEN and regression**

Run DamageTest, BalanceTest, and SmokeTest. Expected: all exit zero; DamageTest prints one positive pass marker.

- [ ] **Step 5: Commit and push**

```powershell
git add scripts/tests/DamageTest.gd scripts/components/HealthComponent.gd scripts/actors/Player.gd
git commit -m "fix: make player damage acceptance atomic"
git push origin master
```

### Task 2: Deferred drops and idempotent pickups

**Files:**
- Create: `scripts/tests/ProjectilePickupTest.gd`
- Modify: `scripts/systems/WaveDirector.gd`
- Modify: `scripts/pickups/ExperienceShard.gd`
- Modify: `scripts/pickups/ShieldPickup.gd`

**Interfaces:**
- Produces: `WaveDirector._deferred_spawn_drops(position, xp, shield)`, and pickup `_try_collect() -> bool`.
- Consumes: Main `spawn_experience(position, value)` and `spawn_shield(position, value)`.

- [ ] **Step 1: Write a real-overlap RED test**

Create a fresh Main scene, stop automatic waves, place a one-health enemy and Projectile at the same position, and wait three physics frames. Assert no output error, exactly one XP pickup, and exactly one shield pickup for a bruiser-style configured drop. Invoke both pickup collection paths in the same frame and assert one collected signal. Print `TEST PASS: ProjectilePickupTest <count>` after complete cleanup.

- [ ] **Step 2: Verify RED**

Run the focused test. Expected: non-zero or output containing the physics-query flush error, and the double `_collect()` call can emit twice.

- [ ] **Step 3: Defer copied drop values**

Replace the death callback with:

```gdscript
func _on_enemy_died(enemy: Node, xp_value: int) -> void:
	var death_position: Vector2 = enemy.global_position
	var shield_value: float = enemy.shield_drop_value
	enemy_killed.emit(xp_value)
	call_deferred("_deferred_spawn_drops", death_position, xp_value, shield_value)
	_emit_wave_status()

func _deferred_spawn_drops(position: Vector2, xp_value: int, shield_value: float) -> void:
	var owner := get_parent()
	if not is_instance_valid(owner):
		return
	if xp_value > 0 and owner.has_method("spawn_experience"):
		owner.spawn_experience(position, xp_value)
	if shield_value > 0.0 and owner.has_method("spawn_shield"):
		owner.spawn_shield(position, shield_value)
```

- [ ] **Step 4: Make both pickups single-shot**

Add `var collected_once := false`, enable monitoring with `set_deferred("monitoring", true)`, and route both paths through:

```gdscript
func _try_collect() -> bool:
	if collected_once:
		return false
	collected_once = true
	set_deferred("monitoring", false)
	collected.emit(value)
	queue_free()
	return true
```

- [ ] **Step 5: Verify, commit, and push**

Run ProjectilePickupTest plus all existing tests, require no `ERROR:` output, then commit the four production/test files as `fix: defer enemy drops outside physics callbacks` and push.

### Task 3: Frame-independent firing and dash sweep

**Files:**
- Create: `scripts/tests/DashTest.gd`
- Create: `scripts/tests/RateTest.gd`
- Modify: `scripts/actors/Player.gd`

**Interfaces:**
- Produces: `Player._update_fire(delta, wants_fire) -> int`, `Player._distance_to_segment(point, start, end) -> float`, and bounded catch-up behavior.

- [ ] **Step 1: Write RED simulations**

RateTest simulates ten seconds at 30, 60, and 120 Hz with `fire_rate = 19.5`, counting emitted projectiles; assert counts differ by at most one and equal 195 within startup alignment. DashTest manually advances a dash at the same rates, asserts final displacement is 165 within 0.01, and places an enemy between two coarse 30 Hz positions to prove swept damage.

- [ ] **Step 2: Verify RED**

Expected: current 60 Hz simulation produces about 150 shots and coarse dash movement overshoots or misses a path enemy.

- [ ] **Step 3: Implement the fire accumulator**

```gdscript
func _update_fire(delta: float, wants_fire: bool) -> int:
	var fired_count := 0
	var interval := 1.0 / maxf(fire_rate, 0.001)
	fire_timer -= delta
	if not wants_fire or not _can_fire_primary():
		fire_timer = maxf(fire_timer, -interval)
		return fired_count
	while fire_timer <= 0.0 and fired_count < 4:
		_fire()
		fire_timer += interval
		fired_count += 1
	return fired_count
```

Remove the timer assignment from `_fire()`.

- [ ] **Step 4: Implement bounded dash steps and segment distance**

```gdscript
func _distance_to_segment(point: Vector2, start: Vector2, end: Vector2) -> float:
	var segment := end - start
	var length_squared := segment.length_squared()
	if length_squared <= 0.0001:
		return point.distance_to(start)
	var t := clampf((point - start).dot(segment) / length_squared, 0.0, 1.0)
	return point.distance_to(start + segment * t)

func _update_dash(delta: float) -> void:
	if not dash_active:
		return
	var step_time := minf(delta, dash_timer)
	var start := global_position
	velocity = dash_direction * (dash_distance / dash_duration)
	move_and_collide(velocity * step_time)
	_clamp_to_world_bounds()
	dash_timer -= step_time
	_apply_dash_melee_sweep(start, global_position)
	if dash_timer <= 0.0:
		dash_active = false
```

The sweep iterates the enemy registry when available, otherwise the group, and damages an unhit enemy when `_distance_to_segment(enemy.global_position, start, end) <= dash_melee_radius`.

- [ ] **Step 5: Verify, commit, and push**

Run RateTest, DashTest, and all regressions. Commit as `fix: make fire rate and dash frame independent`, then push.

### Task 4: Stable spawning and safe positions

**Files:**
- Create: `scripts/tests/WaveTest.gd`
- Modify: `scripts/systems/WaveDirector.gd`

**Interfaces:**
- Produces: `WaveDirector._process_spawn_timer(delta) -> int` and `WaveDirector.sample_spawn_position(player_position, margin, minimum_distance, rng) -> Vector2`.

- [ ] **Step 1: Write RED rate and property tests**

Simulate a fixed queue for ten seconds at 30/60/120 Hz and assert counts differ by at most one. With seeded `RandomNumberGenerator`, set the player at each inset world corner and sample 10,000 positions; every point must remain within `world_bounds.grow(-24)` and at least 430 pixels from the player.

- [ ] **Step 2: Verify RED**

Expected: current reset timer produces frame-dependent counts, and clamped radial candidates violate the distance invariant.

- [ ] **Step 3: Implement bounded spawning**

```gdscript
func _process_spawn_timer(delta: float) -> int:
	spawn_timer -= delta
	var spawned := 0
	var interval := float(waves[wave_index]["rate"])
	while spawn_timer <= 0.0 and not spawn_queue.is_empty() and spawned < 8:
		_spawn_enemy(spawn_queue.pop_front())
		spawn_timer += interval
		spawned += 1
	if spawned > 0:
		_emit_wave_status()
	return spawned
```

- [ ] **Step 4: Implement legal rejection sampling**

Sample x/y within the inset rectangle for 32 attempts. Return the first point meeting `distance_to(player_position) >= minimum_distance`. Otherwise evaluate four corners and four edge midpoints, sort by distance descending, and return the farthest legal point.

- [ ] **Step 5: Verify, commit, and push**

Run WaveTest and regressions. Commit as `fix: make wave spawning stable and safe`, then push.

### Task 5: Transactional upgrades and Main-owned state

**Files:**
- Create: `scripts/tests/UpgradeTest.gd`
- Create: `scripts/tests/StateTest.gd`
- Modify: `scripts/systems/UpgradeSystem.gd`
- Modify: `scripts/Main.gd`
- Modify: `scripts/ui/GameUI.gd`

**Interfaces:**
- Produces: `Main.RunState`, `Main._transition_to(next_state) -> bool`, `UpgradeSystem.apply_upgrade(choice) -> bool`, `pending_choices`, `pending_upgrade_count`, and `awaiting_choice`.

- [ ] **Step 1: Write transactional RED tests**

UpgradeTest grants enough XP for three levels, asserts three serialized choice rounds, rejects an unknown id, rejects a duplicate valid dictionary after consumption, and confirms invalid input does not change pause, stats, labels, or pending count. StateTest asserts legal transitions, rejects `START -> RESULT`, and scans production scripts to ensure only Main contains assignments to `.paused`.

- [ ] **Step 2: Verify RED**

Expected: forged choices apply, duplicate choices apply, extra levels are not queued, and UI/UpgradeSystem write pause.

- [ ] **Step 3: Implement the upgrade transaction**

Use exact state fields:

```gdscript
var pending_choices: Array[Dictionary] = []
var pending_upgrade_count := 0
var awaiting_choice := false
```

Process all crossed thresholds into `pending_upgrade_count`. `_present_next_choices()` filters capped ids, stores duplicated choice dictionaries, sets `awaiting_choice`, and emits. `apply_upgrade` finds a matching current id, clears `awaiting_choice` and `pending_choices` before mutation, applies once, decrements the queue, emits `upgrade_applied`, and either presents the next transaction or emits `upgrade_queue_completed`. It returns false before any mutation for invalid input.

- [ ] **Step 4: Centralize state in Main**

Add `enum RunState { START, PLAYING, UPGRADE, PAUSED, RESULT }`, `var run_state := RunState.START`, and one `_transition_to` function with an explicit allowed-transition dictionary. That function is the sole writer of `get_tree().paused` and calls UI presentation methods. Remove pause assignments from GameUI and UpgradeSystem; connect their intent signals to Main transition handlers.

- [ ] **Step 5: Add upgrade caps**

Track application counts by id and filter at: fire rate 12, weapon lines 5, pierce 6, drones 4, arc 8, and mine 8. Non-capped health, damage, and pickup upgrades remain available.

- [ ] **Step 6: Verify, commit, and push**

Run UpgradeTest, StateTest, and all regressions. Commit as `refactor: centralize run and upgrade state`, then push.

### Task 6: Isolated suite runner

**Files:**
- Create: `scripts/tests/TestSupport.gd`
- Create: `scripts/tests/run_tests.ps1`
- Replace: `scripts/tests/SmokeTest.gd`
- Modify: focused test scripts from Tasks 1–5.

**Interfaces:**
- Produces: machine-readable `TEST PASS: <suite> <count>` output and one canonical runner exit code.

- [ ] **Step 1: Write a runner that initially fails**

The PowerShell script enumerates BalanceTest plus the focused suites, resolves `godot` or the WinGet console executable, runs every script in a new process, captures merged stdout/stderr, and fails when exit code is non-zero, pass marker count is not one, assertion count is zero, output matches `SCRIPT ERROR|ERROR:|TEST FAIL:|ObjectDB instances were leaked`, or runtime exceeds 120 seconds.

- [ ] **Step 2: Verify RED**

Run `powershell -ExecutionPolicy Bypass -File scripts/tests/run_tests.ps1`. Expected: existing tests lack pass markers and leak warnings are detected.

- [ ] **Step 3: Add shared cleanup and pass accounting**

`TestSupport.gd` provides assertion counting, `fail(message)`, `cleanup_nodes(nodes)`, and `finish()` that resets pause, frees nodes, waits two frames, prints the pass marker, and quits zero. Convert every suite to use it. Replace the monolithic SmokeTest with a lightweight boot/lifecycle suite that does not repeat focused behavior.

- [ ] **Step 4: Verify, commit, and push**

Run the canonical runner twice to detect lifecycle flakes. Both runs must report every suite and no forbidden output. Commit as `test: isolate gameplay regression suites`, then push.

### Task 7: Modular responsive UI

**Files:**
- Create: `scenes/ui/HUD.tscn`
- Create: `scenes/ui/UpgradeScreen.tscn`
- Create: `scenes/ui/PauseScreen.tscn`
- Create: `scenes/ui/ResultScreen.tscn`
- Create: `scripts/ui/HUD.gd`
- Create: `scripts/ui/UpgradeScreen.gd`
- Create: `scripts/ui/PauseScreen.gd`
- Create: `scripts/ui/ResultScreen.gd`
- Create: `themes/CyberTheme.tres`
- Modify: `scripts/ui/GameUI.gd`
- Create: `scripts/tests/UITest.gd`

**Interfaces:**
- Produces: focused screen signals and GameUI-compatible setter/presentation methods.

- [ ] **Step 1: Write responsive/modal RED tests**

Instantiate GameUI at each target viewport size. Assert HUD critical controls fit inside the viewport, upgrade buttons are visible, overlays use `MOUSE_FILTER_STOP`, opening each modal owns focus, and closing returns focus to HUD pause. Trigger two toasts rapidly and assert only the newest tween remains active and the hidden toast has no layout footprint.

- [ ] **Step 2: Verify RED**

Expected: fixed minimum widths overflow at 960x540, toast remains in layout, and overlay/focus ownership is incomplete.

- [ ] **Step 3: Build the shared theme and focused scenes**

Move current colors, panel styles, buttons, fonts, and bars into `CyberTheme.tres`. Use anchors and Containers in each scene. UpgradeScreen switches to a compact vertical choice layout below 1,100 logical pixels; HUD wraps secondary statistics while retaining health, shield, XP, wave, and pause.

- [ ] **Step 4: Make GameUI an orchestrator**

GameUI instantiates the four scenes, forwards screen intent signals, and delegates setters. It owns no panel construction. HUD stores one `toast_tween`, kills it before replacement, and makes the toast overlay invisible after fade. Modal screens set overlay mouse filter to STOP and grab their primary control.

- [ ] **Step 5: Verify, commit, and push**

Run UITest and the full runner at 960x540, 1280x720, 1920x1080, and 2560x1080 using project command-line window overrides. Commit as `refactor: split responsive game UI`, then push.

### Task 8: Bounded runtime performance

**Files:**
- Modify: `scripts/systems/WaveDirector.gd`
- Modify: `scripts/actors/Player.gd`
- Modify: `scripts/actors/Enemy.gd`
- Modify: `scripts/components/Projectile.gd`
- Modify: `scripts/pickups/ExperienceShard.gd`
- Modify: `scripts/pickups/ShieldPickup.gd`
- Modify: `scripts/systems/AudioManager.gd`
- Create: `scripts/tests/PerformanceTest.gd`

**Interfaces:**
- Produces: `WaveDirector.active_enemies`, bounded audio voices, and a reproducible wave-eight performance report.

- [ ] **Step 1: Write bounded-resource RED tests**

Spawn 250 enemies, run targeting and hit audio for a fixed simulation, and assert enemy queries use the registry, AudioStreamPlayer child count remains constant, static Projectile/Pickup nodes do not request redraw every frame, and all registry entries disappear on enemy exit.

- [ ] **Step 2: Verify RED**

Expected: group scans remain in Player, every hit adds an audio player, and static nodes call `queue_redraw()` continuously.

- [ ] **Step 3: Add the enemy registry**

WaveDirector appends on spawn, connects `tree_exiting` to erase, exposes `get_active_enemies() -> Array[Node]`, and uses registry size for status. Player receives an enemy provider during setup and uses it for dash, laser, arc, and nearest-target queries.

- [ ] **Step 4: Remove static redraw churn**

Remove per-frame `queue_redraw()` from Projectile and both pickups. Enemy redraws only when entering/leaving attack or flash visual state. Dynamic LaserBeam and time-based ArcPulseVisual retain redraws.

- [ ] **Step 5: Bound audio voices**

Create a fixed pool of 16 one-shot AudioStreamPlayers in AudioManager `_ready()`. `play()` selects a stopped voice or steals the oldest active voice; it never adds a node after initialization. Keep the reusable BGM and laser-loop players.

- [ ] **Step 6: Profile and decide**

PerformanceTest prints average process milliseconds, physics milliseconds where available, node count, and audio voice count for a seeded wave-eight fixture. Record results in `docs/performance/wave-8-baseline.md`. Add no pool or spatial index unless the profile identifies a remaining material bottleneck.

- [ ] **Step 7: Verify, commit, and push**

Run PerformanceTest and the full runner. Commit as `perf: bound combat scans redraws and audio voices`, then push.

### Task 9: Documentation and final acceptance

**Files:**
- Modify: `README.md`
- Modify: `project.godot` only if Space pause is not already mapped.
- Create: `docs/testing.md`

**Interfaces:**
- Produces: reproducible player, test, export, and acceptance instructions for Godot 4.7.

- [ ] **Step 1: Update user documentation**

README must state Godot 4.7, WASD, left-click fire, right-click dash, Space pause, upgrade controls, the canonical PowerShell test command, and Windows export steps through Editor > Project > Export. `docs/testing.md` lists every suite, its responsibility, single-suite commands, forbidden output patterns, and the four UI resolutions.

- [ ] **Step 2: Run final verification**

Run the canonical runner twice, `git diff --check`, `rg -n 'get_tree\(\)\.paused\s*=' scripts` expecting assignments only in Main, and the four-resolution UITest commands. Inspect `git status --short` to exclude `.superpowers/sdd` artifacts.

- [ ] **Step 3: Commit and push**

```powershell
git add README.md project.godot docs/testing.md
git commit -m "docs: document controls testing and export"
git push origin master
```

- [ ] **Step 4: Record completion evidence**

Update this plan's checkboxes, append the final commit hashes and exact test totals to `docs/testing.md`, commit only those documentation changes as `docs: record final verification`, and push.
