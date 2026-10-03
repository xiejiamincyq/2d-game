extends SceneTree

const DirectorScript = preload("res://scripts/systems/WaveDirector.gd")
var assertions := 0
var failures: Array[String] = []

func _check(condition: bool, message: String) -> void:
	assertions += 1
	if not condition and not failures.has(message):
		failures.append(message)

func _fixture() -> Dictionary:
	var holder := Node2D.new()
	root.add_child(holder)
	var player := Node2D.new()
	var enemies := Node2D.new()
	var projectiles := Node2D.new()
	var portals := Node2D.new()
	var director: Node = DirectorScript.new()
	for node in [player, enemies, projectiles, portals, director]:
		holder.add_child(node)
	var fixture := {"holder": holder, "director": director, "emitted": 0}
	enemies.child_entered_tree.connect(func(enemy: Node) -> void:
		enemy.process_mode = Node.PROCESS_MODE_DISABLED # Only enemies are frozen.
		fixture.emitted += 1
	)
	director.world_bounds = Rect2(-1400, -900, 2800, 1800)
	director.spawn_rng.seed = 20260908
	director.setup(player, enemies, projectiles, portals, false)
	_check(director.is_node_ready() and director.is_processing(), "director must be ready and automatically processing")
	return fixture

func _pending(director: Node) -> int:
	var total: int = director.spawn_queue.size()
	for queue in director.portal_spawn_queues.values():
		total += queue.size()
	return total

func _check_clocks(director: Node, label: String) -> void:
	for portal in director.active_portals:
		_check(portal.is_node_ready(), label + " portal was not ready")
		_check(not portal.is_processing(), label + " portal has a second automatic clock")

func _initialize() -> void:
	Engine.max_fps = 60
	await process_frame # Construct fixtures only after the root is genuinely ready.
	var orphan_before := int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	var fixture := _fixture()
	var director: Node = fixture.director
	_check(director.prepare_next_wave() and director.begin_prepared_wave(), "natural first wave did not start")
	_check(director.active_portals.size() == 3 and _pending(director) == 41, "first wave must contain 41 enemies in three portals")
	_check_clocks(director, "normal")
	var reinforcement := _fixture()
	var reinforcement_director: Node = reinforcement.director
	reinforcement_director._on_boss_reinforcements_requested(null, 8)
	_check(reinforcement_director.active_portals.size() == 2 and _pending(reinforcement_director) == 8, "reinforcement portal setup failed")
	_check_clocks(reinforcement_director, "reinforcement")
	reinforcement.holder.free() # Ownership-only probe: no fabricated boss combat.
	var boss := _fixture()
	var boss_director: Node = boss.director
	boss_director.wave_index = boss_director.waves.size() - 1
	boss_director.wave_running = true
	_check(boss_director._begin_boss_entrance(), "boss entrance setup failed")
	if is_instance_valid(boss_director.boss_portal):
		_check(boss_director.boss_portal.is_node_ready() and not boss_director.boss_portal.is_processing(), "boss portal has a second automatic clock")
	boss.holder.free()
	if "--ownership-only" not in OS.get_cmdline_user_args():
		var started := Time.get_ticks_usec()
		var first_loss := ""
		while not director.active_portals.is_empty() and Time.get_ticks_usec() - started < 5000000:
			await process_frame # Real engine _process; never invoke advance/_process manually.
			var total: int = int(fixture.emitted) + _pending(director)
			if total != 41 and first_loss.is_empty():
				first_loss = "first wave lost queued enemies: emitted=%d pending=%d portals=%d" % [fixture.emitted, _pending(director), director.active_portals.size()]
			_check(total == 41, first_loss)
			_check(not paused and director.can_process(), "real-time fixture was paused or director stopped")
		_check(director.active_portals.is_empty(), "portals did not close within five wall-clock seconds")
		_check(int(fixture.emitted) == 41 and _pending(director) == 0, "natural portal lifecycle did not emit all 41 enemies")
		print("PortalRuntimeClockTest observed emitted=%d pending=%d" % [fixture.emitted, _pending(director)])
	fixture.holder.queue_free()
	await process_frame
	await process_frame
	_check(not is_instance_valid(fixture.holder), "owned fixture was not freed")
	_check(int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)) <= orphan_before, "fixture increased orphan nodes")
	for failure in failures:
		push_error("TEST FAIL: PortalRuntimeClockTest: " + failure)
	if failures.is_empty():
		print("TEST PASS: PortalRuntimeClockTest %d" % assertions)
	quit(0 if failures.is_empty() else 1)
