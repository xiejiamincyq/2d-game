# Audio and XP Balance Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Distinguish impact sounds by damage source, replace the noisy repeated laser chirp with a soft continuous energy loop, double the original upgrade XP curve exactly, and scale enemy XP by 15% per wave.

**Architecture:** A small `DamageTypes` constants module gives every damage producer a stable `StringName` source. Enemies forward that source through their hit signal; `Main` routes it to an `AudioManager` that owns source-specific one-shots, per-source cooldowns, and one reusable laser-loop player. Upgrade requirements retain an unscaled base value and expose twice that value, while enemies apply wave XP scaling once during setup.

**Tech Stack:** Godot 4.7, GDScript, runtime-generated `AudioStreamWAV`, headless `SceneTree` regression tests.

## Global Constraints

- Continue generating all audio at runtime; add no external audio assets.
- Damage sources are exactly `projectile`, `laser`, `arc`, `dash`, and `spike`, with `generic` fallback.
- Actual upgrade requirements must be exactly twice the old recurrence `10`, then `ceil(previous × 1.23 + 2)`.
- Enemy XP uses `max(1, round(base_xp × (1 + 0.15 × (wave - 1))))` and is scaled once.
- Do not add audio settings UI, spatial audio, or an audio-bus refactor.

---

### Task 1: Focused balance regression test

**Files:**
- Create: `scripts/tests/BalanceTest.gd`

**Interfaces:**
- Consumes: `DamageTypes` constants, `Enemy.take_damage(amount, source)`, `AudioManager.play_hit(source)`, `AudioManager.set_laser_active(active)`, and existing `UpgradeSystem.add_experience(amount)`.
- Produces: a headless regression test that locks the complete requested behavior.

- [ ] **Step 1: Write the failing test**

Create `scripts/tests/BalanceTest.gd` with a `SceneTree` test that:

```gdscript
extends SceneTree

const DamageTypes = preload("res://scripts/components/DamageTypes.gd")
const EnemyScript = preload("res://scripts/actors/Enemy.gd")
const AudioManagerScript = preload("res://scripts/systems/AudioManager.gd")
const UpgradeSystemScript = preload("res://scripts/systems/UpgradeSystem.gd")

func _fail(message: String) -> void:
	push_error("BalanceTest failed: " + message)
	quit(1)

func _initialize() -> void:
	var enemy: Node = EnemyScript.new()
	enemy.setup(EnemyScript.EnemyKind.SCRAPPER, 1, Node.new())
	root.add_child(enemy)
	var received_source: StringName = &""
	enemy.hit.connect(func(source: StringName) -> void: received_source = source)
	enemy.take_damage(1.0, DamageTypes.LASER)
	if received_source != DamageTypes.LASER:
		_fail("enemy hit signal did not preserve the damage source.")
		return

	var audio: Node = AudioManagerScript.new()
	root.add_child(audio)
	await process_frame
	for source in DamageTypes.ALL:
		if not audio.hit_stream_names.has(source):
			_fail("missing source-specific hit stream for %s." % source)
			return
	var child_count_before: int = audio.get_child_count()
	if not audio.play_hit(DamageTypes.PROJECTILE):
		_fail("first projectile hit was unexpectedly throttled.")
		return
	if audio.play_hit(DamageTypes.PROJECTILE):
		_fail("repeated projectile hit was not throttled.")
		return
	if not audio.play_hit(DamageTypes.ARC):
		_fail("one hit category blocked another category.")
		return
	if audio.get_child_count() != child_count_before + 2:
		_fail("hit playback created an unexpected number of players.")
		return
	var loop_player: AudioStreamPlayer = audio.laser_loop_player
	audio.set_laser_active(true)
	if not loop_player.playing:
		_fail("laser loop did not start.")
		return
	audio.set_laser_active(false)
	if loop_player.playing or audio.laser_loop_player != loop_player:
		_fail("laser loop did not stop cleanly on the reusable player.")
		return

	var fake_player := Node.new()
	root.add_child(fake_player)
	var upgrades: Node = UpgradeSystemScript.new()
	root.add_child(upgrades)
	upgrades.setup(fake_player)
	if upgrades.required_experience != 20:
		_fail("initial upgrade requirement is not exactly doubled.")
		return
	upgrades.add_experience(20)
	if upgrades.level != 2 or upgrades.required_experience != 30:
		_fail("second upgrade requirement is not exactly double the old curve.")
		return
	paused = false
	upgrades.add_experience(30)
	if upgrades.level != 3 or upgrades.required_experience != 42:
		_fail("third upgrade requirement is not exactly double the old curve.")
		return
	paused = false

	var wave_one: Node = EnemyScript.new()
	wave_one.setup(EnemyScript.EnemyKind.SPITTER, 1, Node.new())
	var wave_five: Node = EnemyScript.new()
	wave_five.setup(EnemyScript.EnemyKind.SPITTER, 5, Node.new())
	if wave_one.xp_value != 3 or wave_five.xp_value != 5:
		_fail("enemy XP did not use the 15 percent wave formula exactly once.")
		return

	enemy.queue_free()
	audio.queue_free()
	upgrades.queue_free()
	fake_player.queue_free()
	wave_one.queue_free()
	wave_five.queue_free()
	await process_frame
	quit(0)
```

- [ ] **Step 2: Run the focused test and verify RED**

Run: `godot --headless --path . --script res://scripts/tests/BalanceTest.gd`

Expected: non-zero exit because `scripts/components/DamageTypes.gd` and the new audio/damage-source interfaces do not exist.

- [ ] **Step 3: Keep the test unchanged for Tasks 2 and 3**

The production implementation must satisfy this test without weakening its assertions.

---

### Task 2: Damage-source routing and controlled laser audio

**Files:**
- Create: `scripts/components/DamageTypes.gd`
- Modify: `scripts/actors/Enemy.gd`
- Modify: `scripts/components/Projectile.gd`
- Modify: `scripts/components/SpikeTrap.gd`
- Modify: `scripts/actors/Player.gd`
- Modify: `scripts/systems/WaveDirector.gd`
- Modify: `scripts/systems/AudioManager.gd`
- Modify: `scripts/Main.gd`
- Test: `scripts/tests/BalanceTest.gd`

**Interfaces:**
- Produces: `DamageTypes.GENERIC/PROJECTILE/LASER/ARC/DASH/SPIKE`, `Enemy.take_damage(amount: float, source: StringName = DamageTypes.GENERIC)`, `signal hit(source: StringName)`, `signal laser_active_changed(active: bool)`, `AudioManager.play_hit(source: StringName) -> bool`, and `AudioManager.set_laser_active(active: bool) -> void`.
- Consumes: Godot `AudioStreamWAV`, existing damage calls, and the focused test from Task 1.

- [ ] **Step 1: Add stable damage-source constants**

Create `scripts/components/DamageTypes.gd`:

```gdscript
extends RefCounted
class_name DamageTypes

const GENERIC: StringName = &"generic"
const PROJECTILE: StringName = &"projectile"
const LASER: StringName = &"laser"
const ARC: StringName = &"arc"
const DASH: StringName = &"dash"
const SPIKE: StringName = &"spike"
const ALL: Array[StringName] = [PROJECTILE, LASER, ARC, DASH, SPIKE]
```

- [ ] **Step 2: Preserve the source through damage producers and enemy signals**

Use `preload("res://scripts/components/DamageTypes.gd")` in affected scripts. Change `Enemy.hit` to accept a `StringName`; change `take_damage` to an optional source and emit it. Give `Projectile` a `damage_source` defaulting to `DamageTypes.PROJECTILE`, pass it from `_try_hit`, and let `Player.take_damage` accept and ignore an optional source so enemy projectiles stay compatible. Pass `LASER`, `ARC`, `DASH`, and `SPIKE` from their corresponding calls.

The core signatures must be:

```gdscript
signal hit(source: StringName)

func take_damage(amount: float, source: StringName = DamageTypes.GENERIC) -> void:
	if health == null:
		return
	flash_timer = 0.08
	health.damage(amount)
	hit.emit(source)
```

```gdscript
var damage_source: StringName = DamageTypes.PROJECTILE

func _try_hit(node: Node) -> void:
	if not node.is_in_group(target_group) or hit_bodies.has(node):
		return
	hit_bodies.append(node)
	if node.has_method("take_damage"):
		node.take_damage(damage, damage_source)
	if pierce <= 0:
		queue_free()
	else:
		pierce -= 1
```

- [ ] **Step 3: Replace repeated laser chirps with state transitions**

In `Player.gd`, replace `signal laser_fired`, `laser_audio_timer`, and periodic emission with:

```gdscript
signal laser_active_changed(active: bool)
var laser_audio_active: bool = false

func _set_laser_audio_active(active: bool) -> void:
	if laser_audio_active == active:
		return
	laser_audio_active = active
	laser_active_changed.emit(active)
```

Call `_set_laser_audio_active(any_laser_active)` once after updating all drones, and call `_set_laser_audio_active(false)` when lasers are cleared.

- [ ] **Step 4: Add source-specific synthesis, throttling, and one loop player**

In `AudioManager.gd`, add:

```gdscript
const DamageTypes = preload("res://scripts/components/DamageTypes.gd")
const HIT_COOLDOWN := 0.055

var hit_stream_names: Dictionary = {
	DamageTypes.PROJECTILE: "hit_projectile",
	DamageTypes.LASER: "hit_laser",
	DamageTypes.ARC: "hit_arc",
	DamageTypes.DASH: "hit_dash",
	DamageTypes.SPIKE: "hit_spike",
}
var hit_cooldowns: Dictionary = {}
var laser_loop_player: AudioStreamPlayer
```

Build five distinct hit streams plus `laser_loop` in `_ready()`. Keep projectile impact short/noisy; use a new harmonic generator with soft attack and decay for laser impact; vary pitch/noise balance for arc, dash, and spike. Generate `laser_loop` as a seamless loop with low-volume harmonics and slow amplitude modulation. Create one `laser_loop_player`, assign the loop stream, set `volume_db` near `-18.0`, and add it once.

Implement cooldown and loop control:

```gdscript
func _process(delta: float) -> void:
	for source in hit_cooldowns.keys():
		hit_cooldowns[source] = maxf(0.0, float(hit_cooldowns[source]) - delta)

func play_hit(source: StringName) -> bool:
	var resolved := source if hit_stream_names.has(source) else DamageTypes.GENERIC
	if float(hit_cooldowns.get(resolved, 0.0)) > 0.0:
		return false
	hit_cooldowns[resolved] = HIT_COOLDOWN
	play(String(hit_stream_names.get(resolved, "enemy_hit")))
	return true

func set_laser_active(active: bool) -> void:
	if active and not laser_loop_player.playing:
		laser_loop_player.play()
	elif not active and laser_loop_player.playing:
		laser_loop_player.stop()
```

- [ ] **Step 5: Route signals in `Main` and `WaveDirector`**

Connect the player state once:

```gdscript
player.laser_active_changed.connect(audio.set_laser_active)
```

Forward enemy hit sources in `WaveDirector` and accept them in `Main`:

```gdscript
enemy.hit.connect(func(source: StringName) -> void:
	if get_parent().has_method("_on_enemy_hit"):
		get_parent()._on_enemy_hit(source)
)
```

```gdscript
func _on_enemy_hit(source: StringName) -> void:
	audio.play_hit(source)
```

- [ ] **Step 6: Run the focused test**

Run: `godot --headless --path . --script res://scripts/tests/BalanceTest.gd`

Expected: audio and damage-source assertions pass; the test may still fail at XP assertions until Task 3.

- [ ] **Step 7: Commit the audio unit when Git identity is available**

```powershell
git add scripts/components/DamageTypes.gd scripts/actors/Enemy.gd scripts/components/Projectile.gd scripts/components/SpikeTrap.gd scripts/actors/Player.gd scripts/systems/WaveDirector.gd scripts/systems/AudioManager.gd scripts/Main.gd scripts/tests/BalanceTest.gd
git commit -m "fix: distinguish weapon impact audio"
```

---

### Task 3: Exact doubled requirements and wave-scaled enemy XP

**Files:**
- Modify: `scripts/systems/UpgradeSystem.gd`
- Modify: `scripts/actors/Enemy.gd`
- Test: `scripts/tests/BalanceTest.gd`

**Interfaces:**
- Produces: `base_required_experience: int`, actual `required_experience` values `20, 30, 42, ...`, and enemy `xp_value` scaled exactly once during `setup`.
- Consumes: the existing upgrade loop and each enemy kind's base XP assignment.

- [ ] **Step 1: Verify the focused test is RED for XP behavior**

Run: `godot --headless --path . --script res://scripts/tests/BalanceTest.gd`

Expected: non-zero exit with the initial requirement still `10` or later requirement not `30`, and wave-five spitter XP still `3`.

- [ ] **Step 2: Track the unscaled upgrade requirement**

In `UpgradeSystem.gd`, replace the initial requirement state with:

```gdscript
const EXPERIENCE_MULTIPLIER := 2
var base_required_experience: int = 10
var required_experience: int = base_required_experience * EXPERIENCE_MULTIPLIER
```

After leveling, advance the base recurrence and then derive the actual requirement:

```gdscript
base_required_experience = int(ceil(float(base_required_experience) * 1.23 + 2.0))
required_experience = base_required_experience * EXPERIENCE_MULTIPLIER
```

- [ ] **Step 3: Apply wave scaling once after selecting base enemy XP**

In `Enemy.setup`, keep each kind's existing base assignment and add after the `match`:

```gdscript
var wave_multiplier := 1.0 + 0.15 * float(maxi(1, wave_index) - 1)
xp_value = maxi(1, int(round(float(xp_value) * wave_multiplier)))
```

Do not modify `WaveDirector._on_enemy_died`; it must continue forwarding the already-scaled integer unchanged.

- [ ] **Step 4: Run the focused test and verify GREEN**

Run: `godot --headless --path . --script res://scripts/tests/BalanceTest.gd`

Expected: exit code `0` and no `BalanceTest failed` errors.

- [ ] **Step 5: Commit the XP unit when Git identity is available**

```powershell
git add scripts/systems/UpgradeSystem.gd scripts/actors/Enemy.gd scripts/tests/BalanceTest.gd
git commit -m "feat: rebalance upgrade and wave experience"
```

---

### Task 4: Full regression verification

**Files:**
- Modify: `scripts/tests/SmokeTest.gd` only if an existing assertion needs a source argument or new stream key.

**Interfaces:**
- Consumes: all interfaces from Tasks 2 and 3.
- Produces: evidence that focused and existing smoke coverage both pass.

- [ ] **Step 1: Update legacy smoke assertions only where interfaces changed**

Replace checks for only `enemy_hit` with checks for `hit_projectile`, `hit_laser`, `hit_arc`, `hit_dash`, `hit_spike`, and `laser_loop`. Do not duplicate the focused numeric assertions.

- [ ] **Step 2: Run the focused balance test**

Run: `godot --headless --path . --script res://scripts/tests/BalanceTest.gd`

Expected: exit code `0`.

- [ ] **Step 3: Run the complete smoke test**

Run: `godot --headless --path . --script res://scripts/tests/SmokeTest.gd`

Expected: exit code `0`, no parser errors, and no `SmokeTest failed` errors.

- [ ] **Step 4: Inspect the final diff**

Run: `git diff --check` and `git diff -- scripts scripts/tests docs/superpowers`

Expected: no whitespace errors; changes remain within the approved audio, damage-source, test, and XP scope.

- [ ] **Step 5: Record the Git identity blocker if commits remain unavailable**

Do not invent an author identity or change global Git configuration. Report that commits were skipped until the user supplies a name and email; keep all source changes in the working tree.
