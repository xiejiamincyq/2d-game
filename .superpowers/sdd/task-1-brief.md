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

