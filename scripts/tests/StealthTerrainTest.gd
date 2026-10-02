extends SceneTree

const PlayerScript = preload("res://scripts/actors/Player.gd")
const EnemyScript = preload("res://scripts/actors/Enemy.gd")
const ArenaObstacleScript = preload("res://scripts/world/ArenaObstacle.gd")
const THIN_WALL := Rect2(80.0, -100.0, 20.0, 200.0)
const ACTIONS := [&"move_left", &"move_right", &"move_up", &"move_down", &"dash_melee", &"fire"]
var assertions := 0

func _assert_true(condition: bool, message: String) -> bool:
	assertions += 1
	if condition:
		return true
	_release_input()
	push_error("TEST FAIL: StealthTerrainTest: " + message)
	quit(1)
	return false

func _initialize() -> void:
	call_deferred("_run_suite")

func _run_suite() -> void:
	await process_frame
	if not _assert_true(root.is_node_ready(), "root must be ready before constructing physical fixtures"):
		return
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--physics-hz="):
			Engine.physics_ticks_per_second = argument.trim_prefix("--physics-hz=").to_int()
	if not _assert_true(Engine.physics_ticks_per_second in [30, 60, 120], "physics-hz must be 30, 60, or 120"):
		return
	if OS.get_cmdline_user_args().has("--normal-probe"):
		var probe := await _measure_contact_slide(false)
		if not probe.ok:
			return
		print("TEST PASS: StealthTerrainNormalProbe %d" % assertions)
		quit(0)
		return
	if OS.get_cmdline_user_args().has("--recovery-probe"):
		if not await _test_recovery_escape_groups():
			return
		print("TEST PASS: StealthTerrainRecoveryProbe %d" % assertions)
		quit(0)
		return
	for stealth in [false, true]:
		if not await _test_open_space(stealth) or not await _test_head_on_wall(stealth):
			return
		if not await _test_contact_cases(stealth) or not await _test_complex_geometry(stealth):
			return
	if not await _test_slide_reference() or not await _test_deep_embedding():
		return
	if not await _test_recovery_escape_groups():
		return
	if not await _test_stealth_crosses_enemy() or not await _test_enemy_before_wall_and_expiry():
		return
	if not await _test_pause_death_restart_contract() or not await _test_dash_to_walk():
		return
	print("TEST PASS: StealthTerrainTest %d" % assertions)
	quit(0)

func _release_input() -> void:
	for action in ACTIONS:
		Input.action_release(action)

func _fixture(start := Vector2.ZERO, rect := THIN_WALL, stealth := false) -> Dictionary:
	_release_input()
	var scene := Node2D.new()
	root.add_child(scene)
	if rect.size != Vector2.ZERO:
		var wall: StaticBody2D = ArenaObstacleScript.new()
		wall.setup(rect, &"planter")
		scene.add_child(wall)
	var player: CharacterBody2D = PlayerScript.new()
	player.position = start
	scene.add_child(player)
	var shots: Array[Node] = []
	player.fired.connect(func(shot: Node) -> void:
		scene.add_child(shot)
		shot.set_physics_process(false)
		shots.append(shot))
	player.set_physics_process(false)
	if stealth:
		player._activate_assassin_stealth()
	# Real shapes/deferred disabled flags must reach the physics server first.
	await process_frame
	await physics_frame
	await process_frame
	await physics_frame
	await process_frame
	return {"scene": scene, "player": player, "shots": shots}

func _dispose(fixture: Dictionary) -> void:
	_release_input()
	fixture.player.set_physics_process(false)
	fixture.scene.queue_free()
	await process_frame

func _walk(fixture: Dictionary, direction: Vector2, seconds := 0.8, start_dash := false, fire_once := false) -> Dictionary:
	var player: Node = fixture.player
	var hz := Engine.physics_ticks_per_second
	var requested_steps := ceili(seconds * hz)
	var first_step := Engine.get_physics_frames()
	var previous_step := first_step
	var start: Vector2 = player.global_position
	var initial_stealth: float = player.stealth_remaining
	var samples: Array[Dictionary] = []
	_release_input()
	if direction.x != 0.0:
		Input.action_press(&"move_right" if direction.x > 0.0 else &"move_left", absf(direction.x))
	if direction.y != 0.0:
		Input.action_press(&"move_down" if direction.y > 0.0 else &"move_up", absf(direction.y))
	if start_dash:
		Input.action_press(&"dash_melee")
	if fire_once:
		Input.action_press(&"fire")
	player.set_physics_process(true)
	while Engine.get_physics_frames() - first_step < requested_steps:
		await physics_frame
		# physics_frame fires BEFORE Player._physics_process; sample after it ran.
		await process_frame
		var current_step := Engine.get_physics_frames()
		if not _assert_true(current_step == previous_step + 1, "movement sample skipped/duplicated a physics step; match --fixed-fps to --physics-hz"):
			player.set_physics_process(false)
			return {"ok": false}
		samples.append({"position": player.global_position, "step": current_step - first_step,
			"recovery_trace": player.stealth_recovery_trace.duplicate(true),
			"velocity": player.velocity, "stealth_remaining": player.stealth_remaining, "dash_active": player.dash_active,
			"body_restored": player.collision_layer == player.normal_collision_layer and player.collision_mask == player.normal_collision_mask and not player.player_collision.disabled,
			"stealth_body_disabled": player.is_stealthed() and player.collision_layer == 0 and player.collision_mask == 0 and player.player_collision.disabled})
		if fixture.has("probe_enemy"):
			samples[-1]["enemy_position"] = fixture.probe_enemy.global_position
			samples[-1]["enemy_attacking"] = fixture.probe_enemy.is_attacking
			samples[-1]["player_health"] = player.health.current_health
		if fire_once:
			Input.action_release(&"fire")
		previous_step = current_step
	_release_input()
	player.set_physics_process(false)
	var actual_steps := previous_step - first_step
	var valid := _assert_true(actual_steps == requested_steps and samples.size() == actual_steps, "sample count must equal every requested physics step")
	print("STEALTH WALK SAMPLE: requested=%d actual=%d samples=%d hz=%d seconds=%.6f" % [requested_steps, actual_steps, samples.size(), hz, float(actual_steps) / hz])
	return {"ok": valid, "samples": samples, "seconds": float(actual_steps) / hz, "start": start, "initial_stealth": initial_stealth}

func _check_geometry(result: Dictionary, rects: Array, upper := Vector2(INF, INF)) -> bool:
	if not result.ok:
		return false
	for sample in result.samples:
		var point: Vector2 = sample.position
		if not _assert_true(point.x <= upper.x + 0.1 and point.y <= upper.y + 0.1, "crossed the near side of a thin wall/boundary at step %d: %s" % [sample.step, point]):
			return false
		for rect: Rect2 in rects:
			if not _assert_true(point.distance_to(point.clamp(rect.position, rect.end)) >= PlayerScript.BODY_RADIUS - 0.1, "body overlaps terrain at step %d: %s" % [sample.step, point]):
				return false
	return true

func _add_wall(fixture: Dictionary, rect: Rect2) -> void:
	var wall: StaticBody2D = ArenaObstacleScript.new()
	wall.setup(rect, &"planter")
	fixture.scene.add_child(wall)
	await physics_frame
	await process_frame

func _test_open_space(stealth: bool) -> bool:
	for direction: Vector2 in [Vector2.RIGHT, Vector2.ONE]:
		var fixture := await _fixture(Vector2.ZERO, Rect2(), stealth)
		var speed: float = fixture.player.get_effective_move_speed()
		var result := await _walk(fixture, direction)
		if not result.ok:
			return false
		for sample in result.samples:
			var expected := direction.normalized() * speed * float(sample.step) / Engine.physics_ticks_per_second
			if not _assert_true(sample.position.distance_to(expected) <= 0.02, "open movement violated exact input-speed/time budget"):
				return false
			if stealth and not _assert_true(sample.stealth_body_disabled, "open stealth movement restored body early"):
				return false
		await _dispose(fixture)
	return true

func _test_head_on_wall(stealth: bool) -> bool:
	var fixture := await _fixture(Vector2.ZERO, THIN_WALL, stealth)
	var result := await _walk(fixture, Vector2.RIGHT)
	if not result.ok:
		return false
	for sample in result.samples:
		var point: Vector2 = sample.position
		var closest := point.clamp(THIN_WALL.position, THIN_WALL.end)
		# Independent geometry catches both overlap and landing beyond the thin wall.
		if not _assert_true(point.x <= THIN_WALL.position.x - PlayerScript.BODY_RADIUS + 0.1 and point.distance_to(closest) >= PlayerScript.BODY_RADIUS - 0.1, "ordinary movement crossed/embedded in wall: stealth=%s step=%d position=%s" % [stealth, sample.step, point]):
			return false
		if stealth and not _assert_true(sample.stealth_body_disabled, "stealth movement changed disabled collision-body contract"):
			return false
	var endpoint: Vector2 = fixture.player.global_position
	await _dispose(fixture)
	return _assert_true(endpoint.x >= 60.0, "head-on test never reached the wall; input may not have reached Player")

func _test_contact_cases(stealth: bool) -> bool:
	var rect := Rect2(80.0, -300.0, 20.0, 600.0)
	for depth in [0.0, 0.01]:
		for direction: Vector2 in [Vector2.RIGHT, Vector2.LEFT, Vector2.DOWN]:
			var start := Vector2(80.0 - PlayerScript.BODY_RADIUS + depth, 0.0)
			var fixture := await _fixture(start, rect, stealth)
			var speed: float = fixture.player.get_effective_move_speed()
			var result := await _walk(fixture, direction)
			if not _check_geometry(result, [rect], Vector2(start.x, INF)):
				return false
			for sample in result.samples:
				var point: Vector2 = sample.position
				if direction == Vector2.RIGHT:
					if not _assert_true(point.x <= start.x + 0.001 and point.x >= start.x - 0.1 and absf(point.y) <= 0.001, "contact/shallow inward movement increased penetration or teleported"):
						return false
				elif not _assert_true(point.distance_to(start + direction * speed * float(sample.step) / Engine.physics_ticks_per_second) <= 0.1, "contact/shallow outward or parallel motion lost distance"):
					return false
			await _dispose(fixture)
	return true

func _test_complex_geometry(stealth: bool) -> bool:
	var vertical := Rect2(80.0, -300.0, 20.0, 600.0)
	var horizontal := Rect2(-300.0, 80.0, 600.0, 20.0)
	var near := 80.0 - PlayerScript.BODY_RADIUS
	var cases := [
		{"name": "inside_corner", "start": Vector2.ZERO, "direction": Vector2.ONE, "rects": [vertical, horizontal], "upper": Vector2(near, near)},
		{"name": "parallel_second_wall", "start": Vector2(near, 0.0), "direction": Vector2.DOWN, "rects": [vertical, horizontal], "upper": Vector2(near, near)},
		{"name": "seam", "start": Vector2(0.0, -80.0), "direction": Vector2.ONE, "rects": [Rect2(80.0, -300.0, 20.0, 300.0), Rect2(80.0, 0.0, 20.0, 300.0)], "upper": Vector2(near, INF)},
		{"name": "outer_corner", "start": Vector2.ZERO, "direction": Vector2.ONE, "rects": [Rect2(80.0, 80.0, 20.0, 20.0)], "upper": Vector2.ONE * (80.0 - PlayerScript.BODY_RADIUS / sqrt(2.0))},
	]
	for item in cases:
		var fixture := await _fixture(item.start, item.rects[0], stealth)
		for index in range(1, item.rects.size()):
			await _add_wall(fixture, item.rects[index])
		var result := await _walk(fixture, item.direction)
		if not _check_geometry(result, item.rects, item.upper):
			return false
		var endpoint: Vector2 = fixture.player.global_position
		print("STEALTH GEOMETRY: %s stealth=%s endpoint=%s" % [item.name, stealth, endpoint])
		if not _assert_true(endpoint.distance_to(item.start) >= 40.0 and (item.name != "seam" or endpoint.y > 20.0), "corner/seam case froze before reaching contact"):
			return false
		await _dispose(fixture)
	var bounded := await _fixture(Vector2.ZERO, Rect2(), stealth)
	bounded.player.world_bounds = Rect2(-100.0, -100.0, 200.0, 200.0)
	var result := await _walk(bounded, Vector2.ONE)
	var limit := Vector2.ONE * (100.0 - PlayerScript.BODY_RADIUS)
	if not _check_geometry(result, [], limit):
		return false
	var endpoint: Vector2 = bounded.player.global_position
	await _dispose(bounded)
	return _assert_true(endpoint.distance_to(limit) <= 0.1, "world boundary clipped movement before the playable contact edge")

func _test_deep_embedding() -> bool:
	var start := Vector2(90.0, 0.0)
	var fixture := await _fixture(start, THIN_WALL, true)
	var result := await _walk(fixture, Vector2.RIGHT)
	if not result.ok:
		return false
	for sample in result.samples:
		if not _assert_true(sample.position.distance_to(start) <= 0.001, "deeply embedded stealth start accepted unverified movement"):
			return false
	await _dispose(fixture)
	# Refused motion is the safety contract, not a claim that embedding is recovered.
	return true

func _test_stealth_crosses_enemy() -> bool:
	var fixture := await _fixture(Vector2.ZERO, Rect2(), true)
	var enemy: Node = EnemyScript.new()
	enemy.setup(EnemyScript.EnemyKind.BRUISER, 1, fixture.scene)
	enemy.position = Vector2(82.0, 0.0)
	fixture.scene.add_child(enemy)
	enemy.set_physics_process(false)
	await physics_frame
	await process_frame
	var speed: float = fixture.player.get_effective_move_speed()
	var result := await _walk(fixture, Vector2.RIGHT)
	if not result.ok:
		return false
	for sample in result.samples:
		if not _assert_true(sample.stealth_body_disabled, "passing an enemy restored the stealth collision body"):
			return false
	var endpoint: Vector2 = fixture.player.global_position
	await _dispose(fixture)
	return _assert_true(endpoint.x > 82.0 + 24.0 + PlayerScript.BODY_RADIUS and endpoint.distance_to(Vector2.RIGHT * speed * result.seconds) <= 0.1, "stealth ordinary movement stopped on a real enemy body")

func _measure_contact_slide(stealth: bool, offset := Vector2.ZERO) -> Dictionary:
	var rect := Rect2(Vector2(80.0, -300.0) + offset, Vector2(20.0, 600.0))
	var fixture := await _fixture(Vector2(80.0 - PlayerScript.BODY_RADIUS, 0.0) + offset, rect, stealth)
	var speed: float = fixture.player.get_effective_move_speed()
	var mode: int = fixture.player.motion_mode
	var result := await _walk(fixture, Vector2.ONE)
	if not _check_geometry(result, [rect], Vector2(80.0 - PlayerScript.BODY_RADIUS + offset.x, INF)):
		return {"ok": false}
	var endpoint: Vector2 = fixture.player.global_position
	var ratio: float = (endpoint.y - offset.y) / (speed * result.seconds)
	print("STEALTH SLIDE BASELINE: stealth=%s offset=%s motion_mode=%d speed=%.3f y=%.6f normalized=%.9f first_velocity=%s last_velocity=%s" % [stealth, offset, mode, speed, endpoint.y - offset.y, ratio, result.samples[0].velocity, result.samples[-1].velocity])
	var velocity_tolerance := 0.001
	for sample in result.samples:
		if stealth and not _assert_true(absf(sample.velocity.x) <= velocity_tolerance and sample.velocity.y > 0.0, "slide left a wall-facing velocity used by animation/projectile inheritance: step=%d velocity=%s" % [sample.step, sample.velocity]):
			return {"ok": false}
	fixture.player._spawn_bullet(Vector2.UP)
	if not _assert_true(fixture.shots.size() == 1 and (not stealth or absf(fixture.shots[0].velocity.x) <= velocity_tolerance), "projectile inherited a stale wall-facing movement component"):
		return {"ok": false}
	await _dispose(fixture)
	return {"ok": _assert_true(ratio > 0.65 and ratio <= 1.001, "wall slide lost its tangent or exceeded the step budget"), "ratio": ratio, "samples": result.samples, "speed": speed}

func _test_slide_reference() -> bool:
	var origin_runs: Array[Dictionary] = []
	for offset: Vector2 in [Vector2.ZERO, Vector2(1000.0, 500.0)]:
		var normal := await _measure_contact_slide(false, offset)
		var stealth := await _measure_contact_slide(true, offset)
		if not normal.ok or not stealth.ok:
			return false
		for index in range(normal.samples.size()):
			var normal_y: float = (normal.samples[index].position.y - offset.y) / normal.speed
			var stealth_y: float = (stealth.samples[index].position.y - offset.y) / stealth.speed
			if not _assert_true(absf(normal_y - stealth_y) <= 0.0005, "stealth tangent motion differs from actual non-stealth motion_mode baseline"):
				return false
			if offset != Vector2.ZERO:
				for mode in range(2):
					var translated: Vector2 = [normal, stealth][mode].samples[index].position - offset
					if not _assert_true(translated.distance_to(origin_runs[mode].samples[index].position) <= 0.02, "pure world translation changed wall-slide displacement"):
						return false
		if not _assert_true(absf(normal.ratio - stealth.ratio) <= 0.0005, "sliding speed differs from native normal-mode control"):
			return false
		if offset == Vector2.ZERO:
			origin_runs.assign([normal, stealth])
	return true

func _test_recovery_escape_groups() -> bool:
	# Forced-overlap component probes, not natural full-game encounter acceptance.
	var cases := [
		{"name": "frozen_up", "enemy": Vector2(30.0, 0.0), "input": Vector2.UP, "ai": false, "enemy_first": false},
		{"name": "frozen_outward_diagonal", "enemy": Vector2(55.0, 25.0), "input": Vector2(-1.0, -1.0), "ai": false, "enemy_first": false},
		{"name": "ai_player_first", "enemy": Vector2(30.0, 0.0), "input": Vector2.UP, "ai": true, "enemy_first": false},
		{"name": "ai_enemy_first", "enemy": Vector2(30.0, 0.0), "input": Vector2.UP, "ai": true, "enemy_first": true},
	]
	var rect := Rect2(80.0, -300.0, 20.0, 600.0)
	var start := Vector2(80.0 - PlayerScript.BODY_RADIUS, 0.0)
	for item in cases:
		seed(20261002)
		var fixture := await _fixture(start, rect, true)
		var enemy := _enemy(fixture, item.enemy)
		enemy.target_player = fixture.player
		enemy.formation_slot_index = 0
		fixture["probe_enemy"] = enemy
		if item.enemy_first:
			fixture.scene.move_child(enemy, 0)
		await physics_frame
		await process_frame
		var radius_sum: float = PlayerScript.BODY_RADIUS + enemy.body_radius
		var relative: Vector2 = start - enemy.global_position
		if not _assert_true(relative.length() < radius_sum and enemy.global_position.x + enemy.body_radius <= rect.position.x, "escape fixture must overlap player/enemy without embedding enemy in wall"):
			return false
		enemy.set_physics_process(item.ai)
		fixture.player.clear_runtime_modifiers()
		var result := await _walk(fixture, item.input)
		enemy.set_physics_process(false)
		if not result.ok:
			return false
		var first_separated := -1
		var stalled_steps := 0
		var maximum_stalled := 0
		var previous := start
		for sample in result.samples:
			var point: Vector2 = sample.position
			stalled_steps = stalled_steps + 1 if point.distance_to(previous) <= 0.001 else 0
			maximum_stalled = maxi(maximum_stalled, stalled_steps)
			if first_separated < 0 and sample.body_restored and point.distance_to(sample.enemy_position) > radius_sum + 0.1:
				first_separated = sample.step
			if not _assert_true(is_zero_approx(sample.stealth_remaining) and (sample.step <= 1 or sample.body_restored), "recovery movement extended stealth or deferred body restoration"):
				return false
			previous = point
		var last: Dictionary = result.samples[-1]
		var final_gap: float = last.position.distance_to(last.enemy_position)
		var direction: Vector2 = item.input.normalized()
		var projection := relative.dot(direction)
		var needed := -projection + sqrt(projection * projection + radius_sum * radius_sum - relative.length_squared())
		var progress: float = (last.position - start).dot(direction)
		print("STEALTH RECOVERY: case=%s first_separated=%d max_stall=%d progress=%.6f needed=%.6f final_gap=%.6f health=%.3f" % [item.name, first_separated, maximum_stalled, progress, needed, final_gap, last.player_health])
		if first_separated < 0:
			print("STEALTH RECOVERY FIRST STEPS: ", result.samples.slice(0, 3))
		if not _check_geometry(result, [rect], Vector2(start.x, INF)):
			return false
		if not _assert_true(first_separated > 0 and first_separated <= result.samples.size() - 3 and final_gap > radius_sum + 0.1 and progress > needed + 0.1, "%s did not genuinely escape the restored-body overlap; safe freezing is not success" % item.name):
			return false
		await _dispose(fixture)
	return true

func _enemy(fixture: Dictionary, position: Vector2) -> Node:
	var enemy: Node = EnemyScript.new()
	enemy.setup(EnemyScript.EnemyKind.BRUISER, 1, fixture.scene)
	enemy.position = position
	fixture.scene.add_child(enemy)
	enemy.set_physics_process(false)
	return enemy

func _test_enemy_before_wall_and_expiry() -> bool:
	var rect := Rect2(160.0, -300.0, 20.0, 600.0)
	var fixture := await _fixture(Vector2.ZERO, rect, true)
	_enemy(fixture, Vector2(70.0, 0.0))
	await physics_frame
	await process_frame
	var result := await _walk(fixture, Vector2.RIGHT)
	if not _check_geometry(result, [rect], Vector2(160.0 - PlayerScript.BODY_RADIUS, INF)):
		return false
	if not _assert_true(fixture.player.global_position.x > 70.0 + 24.0 + PlayerScript.BODY_RADIUS, "stealth failed to pass enemy before reaching terrain"):
		return false
	await _dispose(fixture)
	for exit_kind in ["timeout", "fire", "clear", "pause_notification"]:
		fixture = await _fixture(Vector2.ZERO, THIN_WALL, true)
		var enemy := _enemy(fixture, Vector2(30.0, 0.0))
		await physics_frame
		await process_frame
		result = await _walk(fixture, Vector2.RIGHT)
		if not _check_geometry(result, [THIN_WALL], Vector2(80.0 - PlayerScript.BODY_RADIUS, INF)):
			return false
		if not _assert_true(fixture.player.is_stealthed() and fixture.player.global_position.distance_to(enemy.global_position) < PlayerScript.BODY_RADIUS + enemy.body_radius, "exit fixture must actually overlap the enemy at the wall"):
			return false
		if exit_kind == "clear":
			fixture.player.clear_runtime_modifiers()
		elif exit_kind == "pause_notification":
			# Component lifecycle contract; do not mutate Main-owned tree pause state.
			fixture.player.notification(Node.NOTIFICATION_PAUSED)
		result = await _walk(fixture, Vector2.RIGHT, 0.8, false, exit_kind == "fire")
		if not _check_geometry(result, [THIN_WALL], Vector2(80.0 - PlayerScript.BODY_RADIUS, INF)):
			return false
		var restored_samples := 0
		for sample in result.samples:
			var expected := maxf(0.0, float(result.initial_stealth) - float(sample.step) / Engine.physics_ticks_per_second) if exit_kind == "timeout" else 0.0
			if not _assert_true(is_equal_approx(sample.stealth_remaining, expected), "%s exit delayed or extended stealth at step %d" % [exit_kind, sample.step]):
				return false
			if sample.body_restored:
				restored_samples += 1
		if not _assert_true(restored_samples >= 3, "%s exit never sampled three real enabled-body physics steps" % exit_kind):
			return false
		if exit_kind == "fire" and not _assert_true(not fixture.shots.is_empty(), "fire exit did not create a real projectile"):
			return false
		await _dispose(fixture)
	return true

func _test_pause_death_restart_contract() -> bool:
	# This verifies Player lifecycle integration contracts, not Main/save/UI flows.
	var fixture := await _fixture(Vector2.ZERO, Rect2(), true)
	var died := [false]
	fixture.player.died.connect(func() -> void:
		died[0] = true
		fixture.player.set_physics_process(false)
		fixture.player.notification(Node.NOTIFICATION_PAUSED))
	fixture.player.take_damage(10000.0)
	await process_frame
	if not _assert_true(died[0] and fixture.player.health.current_health == 0.0 and not fixture.player.is_physics_processing() and not fixture.player.is_stealthed(), "death owner contract failed to stop/clean the player"):
		return false
	var stopped_at: Vector2 = fixture.player.global_position
	Input.action_press(&"move_right")
	for step in range(3):
		await physics_frame
		await process_frame
		if not _assert_true(fixture.player.global_position == stopped_at, "dead player moved despite owner disabling physics"):
			return false
	await _dispose(fixture)
	fixture = await _fixture(Vector2.ZERO, Rect2())
	if not _assert_true(not fixture.player.is_stealthed() and not fixture.player.dash_active and fixture.player.health.current_health == fixture.player.health.max_health, "replacement player inherited stale life/skill state"):
		return false
	var result := await _walk(fixture, Vector2.RIGHT)
	var endpoint: Vector2 = fixture.player.global_position
	await _dispose(fixture)
	return result.ok and _assert_true(endpoint.distance_to(Vector2.RIGHT * PlayerScript.BASE_MOVE_SPEED * result.seconds) <= 0.02, "replacement player did not resume ordinary movement")

func _test_dash_to_walk() -> bool:
	var fixture := await _fixture()
	fixture.player.activate_build_evolution("rift_overdrive")
	var result := await _walk(fixture, Vector2.RIGHT, 0.8, true)
	if not _check_geometry(result, [THIN_WALL], Vector2(80.0 - PlayerScript.BODY_RADIUS, INF)):
		return false
	if not _assert_true(not fixture.player.dash_active and fixture.player.is_stealthed(), "dash input did not finish into the expected stealth-walk state"):
		return false
	result = await _walk(fixture, Vector2.LEFT)
	if not result.ok:
		return false
	var expected: Vector2 = result.start
	for sample in result.samples:
		var speed := PlayerScript.BASE_MOVE_SPEED * (PlayerScript.ASSASSIN_SPEED_MULTIPLIER if sample.stealth_remaining > 0.0 else 1.0)
		expected.x -= speed / Engine.physics_ticks_per_second
		if not _assert_true(sample.position.distance_to(expected) <= 0.05 and not sample.dash_active, "post-dash walk retained dash wall lock or wrong speed/time budget"):
			return false
	await _dispose(fixture)
	return true
