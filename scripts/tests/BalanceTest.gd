extends SceneTree

const DamageTypes = preload("res://scripts/components/DamageTypes.gd")
const EnemyScript = preload("res://scripts/actors/Enemy.gd")
const AudioManagerScript = preload("res://scripts/systems/AudioManager.gd")
const UpgradeSystemScript = preload("res://scripts/systems/UpgradeSystem.gd")
const TestSupport = preload("res://scripts/tests/TestSupport.gd")

func _fail(message: String) -> void:
	push_error("BalanceTest failed: " + message)
	quit(1)

func _initialize() -> void:
	var enemy: Node = EnemyScript.new()
	enemy.setup(EnemyScript.EnemyKind.SCRAPPER, 1, root)
	root.add_child(enemy)
	await process_frame
	var received := {"source": &""}
	enemy.hit.connect(func(source: StringName) -> void: received["source"] = source)
	enemy.take_damage(1.0, DamageTypes.LASER)
	if received["source"] != DamageTypes.LASER:
		_fail("enemy hit signal did not preserve the damage source.")
		return

	var audio: Node = AudioManagerScript.new()
	root.add_child(audio)
	await process_frame
	if audio.streams.has("enemy_death"):
		_fail("enemy death audio stream is still configured.")
		return
	var expected_sources: Array[StringName] = [
		DamageTypes.PROJECTILE,
		DamageTypes.LASER,
		DamageTypes.ARC,
		DamageTypes.DASH,
		DamageTypes.SPIKE,
	]
	if DamageTypes.ALL != expected_sources:
		_fail("damage source collection does not contain exactly the five requested sources in order.")
		return
	for source in expected_sources:
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
	if audio.get_child_count() != child_count_before:
		_fail("hit playback grew the fixed audio voice pool.")
		return
	var unknown_source: StringName = &"unknown_test_source"
	if not audio.hit_stream_names.has(DamageTypes.GENERIC) or audio.hit_stream_names.has(unknown_source):
		_fail("generic fallback stream mapping is missing or the unknown test source was explicitly configured.")
		return
	var fallback_child_count_before: int = audio.get_child_count()
	if not audio.play_hit(unknown_source):
		_fail("unknown hit source did not play through the generic fallback.")
		return
	if audio.get_child_count() != fallback_child_count_before:
		_fail("generic fallback grew the fixed audio voice pool.")
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
	var old_curve_base: int = 10
	for upgrade_index in range(8):
		var expected_required: int = old_curve_base * 2
		if upgrades.required_experience != expected_required:
			_fail("upgrade requirement at level %d was %d instead of %d." % [upgrades.level, upgrades.required_experience, expected_required])
			return
		var expected_level: int = upgrades.level + 1
		upgrades.add_experience(expected_required)
		if upgrades.level != expected_level:
			_fail("adding the exact requirement did not advance to level %d." % expected_level)
			return
		paused = false
		old_curve_base = int(ceil(float(old_curve_base) * 1.23 + 2.0))

	var enemy_kinds: Array[int] = [
		EnemyScript.EnemyKind.SCRAPPER,
		EnemyScript.EnemyKind.DASHER,
		EnemyScript.EnemyKind.SPITTER,
		EnemyScript.EnemyKind.BRUISER,
	]
	var base_xp_values: Array[int] = [1, 2, 3, 8]
	var wave_enemies: Array[Node] = []
	for kind_index in range(enemy_kinds.size()):
		for wave_index in range(1, 9):
			var wave_enemy: Node = EnemyScript.new()
			wave_enemy.setup(enemy_kinds[kind_index], wave_index, root)
			root.add_child(wave_enemy)
			wave_enemies.append(wave_enemy)
			var expected_xp: int = maxi(1, roundi(float(base_xp_values[kind_index]) * (1.0 + 0.15 * float(wave_index - 1))))
			if wave_enemy.xp_value != expected_xp:
				_fail("enemy kind %d wave %d XP was %d instead of %d." % [enemy_kinds[kind_index], wave_index, wave_enemy.xp_value, expected_xp])
				return

	enemy.queue_free()
	TestSupport.stop_audio(audio)
	await create_timer(0.25).timeout
	audio.queue_free()
	upgrades.queue_free()
	fake_player.queue_free()
	for wave_enemy in wave_enemies:
		wave_enemy.queue_free()
	await process_frame
	await process_frame
	print("TEST PASS: BalanceTest 66")
	quit(0)
