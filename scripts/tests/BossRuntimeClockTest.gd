extends SceneTree

const BossScript = preload("res://scripts/actors/OverseerBoss.gd")
var assertions := 0
var failures: Array[String] = []

func _check(condition: bool, message: String) -> void:
	assertions += 1
	if not condition:
		failures.append(message)

func _initialize() -> void:
	Engine.max_fps = 60
	await process_frame
	var orphan_before := int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	var fixture := Node2D.new()
	root.add_child(fixture)
	var target := Node2D.new()
	var projectiles := Node2D.new()
	fixture.add_child(target)
	fixture.add_child(projectiles)
	target.position = Vector2(400, 0)
	var boss: Node2D = BossScript.new()
	boss.world_bounds = Rect2(-1600, -1000, 3200, 2000)
	boss.setup(6, projectiles, target) # Production builds components before entering tree.
	fixture.add_child(boss)
	var director: Node = boss.get_attack_director()
	var pattern: Node = director.pattern
	_check(boss.is_node_ready() and pattern.is_node_ready(), "production Boss fixture was not ready")
	_check(not pattern.is_processing(), "director-owned Boss pattern has a second automatic clock")
	var observed := {"warning_usec": 0, "first_shot_usec": 0, "duration": 0.0, "pattern": ""}
	pattern.warning_started.connect(func(id: StringName, duration: float, _directions: Array[Vector2]) -> void:
		if observed.warning_usec == 0:
			observed.warning_usec = Time.get_ticks_usec()
			observed.duration = duration
			observed.pattern = String(id)
	)
	projectiles.child_entered_tree.connect(func(_projectile: Node) -> void:
		if observed.warning_usec > 0 and observed.first_shot_usec == 0:
			observed.first_shot_usec = Time.get_ticks_usec()
	)
	var started := Time.get_ticks_usec()
	while observed.first_shot_usec == 0 and Time.get_ticks_usec() - started < 5000000:
		await process_frame # Real Boss physics + engine process, never manually advance.
	_check(observed.pattern == "aimed_fan", "natural phase-one ranged warning was not observed")
	_check(observed.first_shot_usec > observed.warning_usec and observed.warning_usec > 0, "first shot was not observed after warning")
	if observed.first_shot_usec > 0 and observed.warning_usec > 0:
		var delay := float(observed.first_shot_usec - observed.warning_usec) / 1000000.0
		print("BossRuntimeClockTest warning=%.6f first_shot_delay=%.6f" % [observed.duration, delay])
		# Allow two 60 Hz boundary ticks, but never the half-duration double clock.
		_check(delay >= float(observed.duration) - 0.035, "Boss fired before its full warning: %.6fs < %.6fs" % [delay, observed.duration])
		_check(delay <= float(observed.duration) + 0.25, "Boss warning/shot exceeded the bounded real-time observation")
	_check(is_equal_approx(float(boss.health.max_health), 10800.0) and is_equal_approx(float(boss.body_radius), 56.0), "fixture changed Boss health or collision")
	boss.cancel_boss_attacks()
	fixture.queue_free()
	await process_frame
	await process_frame
	_check(not is_instance_valid(fixture), "owned Boss fixture did not free")
	_check(int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)) <= orphan_before, "Boss fixture increased orphan nodes")
	for failure in failures:
		push_error("TEST FAIL: BossRuntimeClockTest: " + failure)
	if failures.is_empty():
		print("TEST PASS: BossRuntimeClockTest %d" % assertions)
	quit(0 if failures.is_empty() else 1)
