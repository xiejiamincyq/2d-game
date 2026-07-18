extends SceneTree

const WaveDirectorScript = preload("res://scripts/systems/WaveDirector.gd")
const EnemyScript = preload("res://scripts/actors/Enemy.gd")

var assertions := 0

func _assert_true(condition: bool, message: String) -> bool:
	assertions += 1
	if condition:
		return true
	push_error("TEST FAIL: WaveTest: " + message)
	quit(1)
	return false

func _initialize() -> void:
	var spawn_counts: Array[int] = []
	for hz in [30, 60, 120]:
		var fixture := Node.new()
		root.add_child(fixture)
		var director: Node = WaveDirectorScript.new()
		var player := Node2D.new()
		var enemies := Node2D.new()
		var projectiles := Node2D.new()
		fixture.add_child(player)
		fixture.add_child(enemies)
		fixture.add_child(projectiles)
		fixture.add_child(director)
		director.set_process(false)
		await process_frame
		director.player = player
		director.enemy_parent = enemies
		director.projectile_parent = projectiles
		director.world_bounds = Rect2(-1400, -900, 2800, 1800)
		director.wave_index = 0
		director.intermission = 0.0
		director.spawn_timer = 0.0
		director.spawn_queue.assign(Array(range(1000)).map(func(_value: int) -> int: return EnemyScript.EnemyKind.SCRAPPER))
		var delta := 1.0 / float(hz)
		for frame in range(hz * 10):
			director._process(delta)
		spawn_counts.append(1000 - director.spawn_queue.size())
		fixture.queue_free()
		await process_frame
	var minimum: int = spawn_counts.min()
	var maximum: int = spawn_counts.max()
	if not _assert_true(maximum - minimum <= 1, "30/60/120 Hz spawn counts diverged: %s" % [spawn_counts]):
		return
	for count in spawn_counts:
		if not _assert_true(count >= 62 and count <= 64, "spawn count %d was not near 62.5" % count):
			return

	var sampler: Node = WaveDirectorScript.new()
	root.add_child(sampler)
	sampler.set_process(false)
	sampler.world_bounds = Rect2(-1400, -900, 2800, 1800)
	var playable: Rect2 = sampler.world_bounds.grow(-24.0)
	var corners: Array[Vector2] = [playable.position, Vector2(playable.end.x, playable.position.y), playable.end, Vector2(playable.position.x, playable.end.y)]
	var rng := RandomNumberGenerator.new()
	rng.seed = 0x5A17
	for corner in corners:
		for sample_index in range(10000):
			var point: Vector2 = sampler.sample_spawn_position(corner, 24.0, 430.0, rng)
			if not playable.has_point(point) or point.distance_to(corner) < 430.0:
				_assert_true(false, "invalid spawn at corner %s sample %d: %s distance %.2f" % [corner, sample_index, point, point.distance_to(corner)])
				return
			assertions += 2

	var tracked_enemy := Node.new()
	sampler.active_enemies.append(tracked_enemy)
	sampler._on_enemy_tree_exiting(tracked_enemy)
	sampler._on_enemy_tree_exiting(tracked_enemy)
	if not _assert_true(sampler.active_enemies.is_empty(), "enemy registry retained a removed enemy"):
		return
	tracked_enemy.free()

	var cleared_waves: Array[int] = []
	var remaining_statuses: Array[int] = []
	var gated_director: Node = WaveDirectorScript.new()
	var gated_fixture := Node.new()
	var gated_player := Node2D.new()
	var gated_enemies := Node2D.new()
	var gated_projectiles := Node2D.new()
	root.add_child(gated_fixture)
	gated_fixture.add_child(gated_player)
	gated_fixture.add_child(gated_enemies)
	gated_fixture.add_child(gated_projectiles)
	gated_fixture.add_child(gated_director)
	gated_director.set_process(false)
	gated_director.player = gated_player
	gated_director.enemy_parent = gated_enemies
	gated_director.projectile_parent = gated_projectiles
	gated_director.wave_index = 0
	gated_director.intermission = 0.0
	gated_director.wave_cleared.connect(func(completed_wave: int) -> void: cleared_waves.append(completed_wave))
	gated_director.wave_changed.connect(func(_index: int, _total: int, remaining: int) -> void: remaining_statuses.append(remaining))
	gated_director._process(0.016)
	gated_director._process(0.016)
	if not _assert_true(cleared_waves == [1], "one cleared wave emitted rewards %s" % [cleared_waves]):
		return
	if not _assert_true(gated_director.waiting_for_advance and gated_director.wave_index == 0 and gated_director.spawn_queue.is_empty(), "director started the next wave behind the upgrade gate"):
		return
	if not _assert_true(not remaining_statuses.is_empty() and remaining_statuses[-1] == 0, "cleared wave did not publish zero remaining enemies"):
		return
	if not _assert_true(gated_director.advance_after_upgrade(), "completed upgrade did not advance the wave"):
		return
	if not _assert_true(not gated_director.waiting_for_advance and gated_director.wave_index == 1 and not gated_director.spawn_queue.is_empty(), "next wave was not prepared after the upgrade"):
		return
	if not _assert_true(not gated_director.advance_after_upgrade(), "duplicate upgrade completion advanced another wave"):
		return

	var victory_count := [0]
	gated_director.active = true
	gated_director.wave_index = gated_director.waves.size() - 1
	gated_director.spawn_queue.clear()
	gated_director.active_enemies.clear()
	gated_director.intermission = 0.0
	gated_director.victory.connect(func() -> void: victory_count[0] += 1)
	gated_director._process(0.016)
	gated_director._process(0.016)
	if not _assert_true(victory_count[0] == 1 and not gated_director.active, "final wave did not resolve victory exactly once"):
		return
	if not _assert_true(cleared_waves == [1], "final victory queued a useless upgrade"):
		return
	gated_fixture.queue_free()

	sampler.queue_free()
	await process_frame
	print("TEST PASS: WaveTest %d" % assertions)
	quit(0)
