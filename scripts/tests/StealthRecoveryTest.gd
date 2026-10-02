extends "res://scripts/tests/StealthTerrainTest.gd"

const RECOVERY_WALL := Rect2(80.0, -1000.0, 20.0, 2000.0)
const RECOVERY_START := Vector2(63.1, 0.0)

func _assert_true(condition: bool, message: String) -> bool:
	assertions += 1
	if condition:
		return true
	_release_input()
	self.paused = false
	push_error("TEST FAIL: StealthRecoveryTest: " + message)
	quit(1)
	return false

func _initialize() -> void:
	call_deferred("_run_suite")

func _run_suite() -> void:
	# Initial SceneTree setup must finish before fixture code changes body state.
	await process_frame
	if not _assert_true(root.is_node_ready(), "root was not ready before creating recovery fixtures"):
		return
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--physics-hz="):
			Engine.physics_ticks_per_second = argument.trim_prefix("--physics-hz=").to_int()
	if not _assert_true(Engine.physics_ticks_per_second in [30, 60, 120], "physics-hz must be 30, 60, or 120"):
		return
	if not await _test_long_hold_and_escape() or not await _test_release_events():
		return
	if not await _test_wall_pressure_release():
		return
	if not await _test_closed_exit() or not await _test_second_entity():
		return
	if not await _test_actual_pause() or not await _test_never_stealthed_control():
		return
	print("TEST PASS: StealthRecoveryTest %d" % assertions)
	quit(0)

func _recovery_fixture(restore := true) -> Dictionary:
	var fixture := await _fixture(RECOVERY_START, RECOVERY_WALL, true)
	fixture["enemy"] = _enemy(fixture, Vector2(30.0, 0.0))
	await physics_frame
	await process_frame
	var before := _fixture_state(fixture)
	print("RECOVERY FIXTURE before_restore: " + JSON.stringify(before))
	fixture["setup_ok"] = _assert_true(before.normal_layer == 1 and before.normal_mask == 1 and before.stealth > 0.0 and before.disabled and before.enemy_query_hit and before.gap < PlayerScript.BODY_RADIUS + fixture.enemy.body_radius, "fixture was not a correctly initialized disabled stealth body overlapping a registered enemy")
	if not fixture.setup_ok:
		return fixture
	if restore:
		fixture.player.clear_runtime_modifiers()
		await process_frame
		var after := _fixture_state(fixture)
		print("RECOVERY FIXTURE after_restore: " + JSON.stringify(after))
		fixture.setup_ok = _assert_true(after.pending and not after.disabled and is_zero_approx(after.stealth) and after.enemy_query_hit, "restoration did not arm guard with an enabled body and existing enemy overlap")
	return fixture

func _fixture_state(fixture: Dictionary) -> Dictionary:
	var player: Node = fixture.player
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = player.player_collision.shape
	query.transform = player.player_collision.global_transform
	query.collision_mask = player.normal_collision_mask
	query.collide_with_areas = false
	query.exclude = [player.get_rid()]
	var enemy_hit := false
	var has_enemy := is_instance_valid(fixture.get("enemy"))
	for hit in player.get_world_2d().direct_space_state.intersect_shape(query, 32):
		enemy_hit = enemy_hit or (has_enemy and hit.collider == fixture.enemy)
	return {"step": Engine.get_physics_frames(), "position": player.global_position,
		"enemy_position": fixture.enemy.global_position if has_enemy else null,
		"gap": player.global_position.distance_to(fixture.enemy.global_position) if has_enemy else INF,
		"enemy_query_hit": enemy_hit, "stealth": player.stealth_remaining, "disabled": player.player_collision.disabled,
		"pending": player.stealth_recovery_pending, "layer": player.collision_layer, "mask": player.collision_mask,
		"normal_layer": player.normal_collision_layer, "normal_mask": player.normal_collision_mask, "ready": player.is_node_ready(),
		"physics_enabled": player.is_physics_processing(), "can_process": player.can_process(), "tree_paused": self.paused,
		"entrance": player.entrance_active, "dash": player.dash_active, "visual_elapsed": player.visual_elapsed,
		"trace": player.stealth_recovery_trace.duplicate(true)}

func _run_recovery(fixture: Dictionary, direction: Vector2, seconds: float, label: String) -> Dictionary:
	if not fixture.get("setup_ok", true):
		return {"ok": false}
	var player: Node = fixture.player
	var hz := Engine.physics_ticks_per_second
	var steps := roundi(seconds * hz)
	var first := Engine.get_physics_frames()
	var first_visual: float = player.visual_elapsed
	var previous: Vector2 = player.global_position
	var samples: Array[Dictionary] = []
	var largest_step := 0.0
	var largest_walk_step := 0.0
	var largest_walk_trace: Dictionary = {}
	var dash_steps := 0
	_release_input()
	if direction.x != 0.0:
		Input.action_press(&"move_right" if direction.x > 0.0 else &"move_left", absf(direction.x))
	if direction.y != 0.0:
		Input.action_press(&"move_down" if direction.y > 0.0 else &"move_up", absf(direction.y))
	player.set_physics_process(true)
	print("RECOVERY RUN initial %s: %s" % [label, JSON.stringify(_fixture_state(fixture))])
	for index in range(steps):
		var entered_as_dash: bool = player.dash_active
		await physics_frame
		await process_frame
		if not _assert_true(Engine.get_physics_frames() == first + index + 1, "%s skipped/duplicated actual physics step; match --fixed-fps and --physics-hz" % label):
			return {"ok": false}
		if index < 3:
			print("RECOVERY RUN sample %s/%d: %s" % [label, index + 1, JSON.stringify(_fixture_state(fixture))])
		if not _assert_true(absf(player.visual_elapsed - first_visual - float(index + 1) / hz) <= 0.00001, "%s SceneTree advanced without the expected Player physics callback; visual delta %.9f" % [label, player.visual_elapsed - first_visual]):
			return {"ok": false}
		var shape: CollisionShape2D = player.player_collision
		if not _assert_true(shape.shape is CircleShape2D and is_equal_approx(shape.shape.radius, PlayerScript.BODY_RADIUS) and shape.global_scale.is_equal_approx(Vector2.ONE), "%s fixture shape changed" % label):
			return {"ok": false}
		var point: Vector2 = shape.global_position
		var enemy_position: Vector2 = fixture.enemy.global_position if is_instance_valid(fixture.get("enemy")) else Vector2(INF, INF)
		samples.append({"position": point, "step": index + 1, "radius": shape.shape.radius,
			"enemy_position": enemy_position, "pending": player.stealth_recovery_pending,
			"trace": player.stealth_recovery_trace.duplicate(true), "health": player.health.current_health,
			"slide_collision_count": player.get_slide_collision_count(),
			"restored": not shape.disabled and player.collision_layer == player.normal_collision_layer and player.collision_mask == player.normal_collision_mask})
		if not _assert_true(is_zero_approx(player.stealth_remaining) and samples[-1].restored and not player.is_damage_immune(), "%s prolonged stealth/body disable/immunity after restoration" % label):
			return {"ok": false}
		var travel := point.distance_to(previous)
		largest_step = maxf(largest_step, travel)
		if entered_as_dash:
			dash_steps += 1
		elif travel > largest_walk_step:
			largest_walk_step = travel
			largest_walk_trace = samples[-1].trace
		previous = point
	_release_input()
	player.set_physics_process(false)
	print("RECOVERY RUN: label=%s hz=%d requested=%d actual=%d samples=%d seconds=%.6f largest_step=%.6f dash_steps=%d largest_walk_step=%.6f walk_input_budget=%.6f largest_walk_trace=%s last_trace=%s" % [label, hz, steps, Engine.get_physics_frames() - first, samples.size(), seconds, largest_step, dash_steps, largest_walk_step, PlayerScript.BASE_MOVE_SPEED * direction.limit_length(1.0).length() / hz, JSON.stringify(largest_walk_trace), JSON.stringify(samples[-1].trace)])
	return {"ok": true, "samples": samples}

func _safe_recovery(result: Dictionary, extra_rects: Array = [], minimum_y := -INF) -> bool:
	if not result.ok:
		return false
	var rects := [RECOVERY_WALL]
	rects.append_array(extra_rects)
	for sample in result.samples:
		var point: Vector2 = sample.position
		if not _assert_true(point.x <= RECOVERY_WALL.position.x - sample.radius + 0.1 and point.y >= minimum_y - 0.1, "recovery crossed a wall's near side: step=%d position=%s trace=%s" % [sample.step, point, JSON.stringify(sample.trace)]):
			return false
		for rect: Rect2 in rects:
			if not _assert_true(point.distance_to(point.clamp(rect.position, rect.end)) >= sample.radius - 0.1, "recovery body overlaps terrain at step %d" % sample.step):
				return false
	return true

func _test_long_hold_and_escape() -> bool:
	for direction: Vector2 in [Vector2.ZERO, Vector2.RIGHT]:
		var fixture := await _recovery_fixture()
		var result := await _run_recovery(fixture, direction, 5.0, "five_second_hold_%s" % direction)
		if not _safe_recovery(result):
			return false
		if not _assert_true(fixture.player.global_position.distance_to(RECOVERY_START) <= 0.1 and fixture.player.stealth_recovery_pending, "closed wall pressure drifted or cleared a still-overlapping recovery window"):
			return false
		await _dispose(fixture)
	for direction: Vector2 in [Vector2.UP, Vector2.DOWN]:
		var fixture := await _recovery_fixture()
		var result := await _run_recovery(fixture, direction, 2.0, "two_second_escape_%s" % direction)
		if not _safe_recovery(result):
			return false
		var last: Dictionary = result.samples[-1]
		if not _assert_true(last.position.distance_to(last.enemy_position) > PlayerScript.BODY_RADIUS + fixture.enemy.body_radius + 0.1 and not last.pending and (last.position - RECOVERY_START).dot(direction) > 40.0, "two-second escape did not separate real bodies and leave the guard"):
			return false
		await _dispose(fixture)
	return true

func _test_release_events() -> bool:
	for event in ["move_away", "death", "remove_shape"]:
		var fixture := await _recovery_fixture()
		if not _safe_recovery(await _run_recovery(fixture, Vector2.RIGHT, 0.2, "before_%s" % event)):
			return false
		var start: Vector2 = fixture.player.global_position
		match event:
			"move_away": fixture.enemy.global_position = Vector2(-500.0, 0.0)
			"death": fixture.enemy.take_damage(10000.0)
			"remove_shape":
				for child in fixture.enemy.get_children():
					if child is CollisionShape2D:
						child.queue_free()
		# Flush the event while Player is disabled; the next sampled step is its
		# first eligible movement step, not an unrecorded settling interval.
		await process_frame
		var result := await _run_recovery(fixture, Vector2.LEFT, 1.0 / Engine.physics_ticks_per_second, "first_step_after_%s" % event)
		if not _safe_recovery(result):
			return false
		var expected := start + Vector2.LEFT * PlayerScript.BASE_MOVE_SPEED / Engine.physics_ticks_per_second
		if not _assert_true(result.samples[0].position.distance_to(expected) <= 0.1 and not result.samples[0].pending, "%s left a stale blocker on the next eligible movement step" % event):
			return false
		await _dispose(fixture)
	return true

func _test_closed_exit() -> bool:
	var fixture := await _recovery_fixture()
	var cap_rect := Rect2(-200.0, -60.0, 280.0, 20.0)
	await _add_wall(fixture, cap_rect)
	var cap: Node = fixture.scene.get_child(fixture.scene.get_child_count() - 1)
	var result := await _run_recovery(fixture, Vector2.UP, 0.8, "closed_exit")
	var near_y := cap_rect.end.y + PlayerScript.BODY_RADIUS
	if not _safe_recovery(result, [cap_rect], near_y):
		return false
	if not _assert_true(fixture.player.stealth_recovery_pending, "closed exit did not exercise a still-overlapping body"):
		return false
	var before: Vector2 = fixture.player.global_position
	cap.queue_free()
	await process_frame
	result = await _run_recovery(fixture, Vector2.UP, 1.0 / Engine.physics_ticks_per_second, "opened_exit_first_step")
	if not _safe_recovery(result) or not _assert_true(fixture.player.global_position.y < before.y - 0.1, "opening the escape route did not restore movement next step"):
		return false
	result = await _run_recovery(fixture, Vector2.UP, 2.0, "opened_exit_escape")
	if not _safe_recovery(result) or not _assert_true(not fixture.player.stealth_recovery_pending and fixture.player.global_position.distance_to(fixture.enemy.global_position) > PlayerScript.BODY_RADIUS + fixture.enemy.body_radius + 0.1, "opened exit left the player stuck/in the recovery window"):
		return false
	await _dispose(fixture)
	return true

func _test_wall_pressure_release() -> bool:
	var fixture := await _recovery_fixture()
	if not _safe_recovery(await _run_recovery(fixture, Vector2.RIGHT, 0.2, "wall_pressure_before_enemy_removal")):
		return false
	if not _assert_true(fixture.player.stealth_recovery_pending, "wall-pressure fixture did not retain its overlapping-enemy guard"):
		return false
	var start: Vector2 = fixture.player.global_position
	fixture.enemy.queue_free()
	await process_frame
	# One continuous input run: the first eligible step exits recovery, then
	# ten further steps must use the normal solver while still pressing the wall.
	var result := await _run_recovery(fixture, Vector2.RIGHT, 11.0 / Engine.physics_ticks_per_second, "enemy_removed_continuous_wall_pressure")
	if not _safe_recovery(result):
		return false
	var first: Dictionary = result.samples[0]
	var terrain_constrained := false
	for input_step: Dictionary in first.trace.get("input_steps", []):
		terrain_constrained = terrain_constrained or (input_step.terrain.blocked and input_step.bounded.distance_to(input_step.accepted) > 0.001)
	if not _assert_true(not first.pending and not first.trace.is_empty() and not first.trace.get("recovery_changed", true) and terrain_constrained and first.trace.get("changed_any", false), "enemy removal must exit recovery on the next enabled step despite a real input/wall constraint"):
		return false
	if not _assert_true(first.position.distance_to(start) <= 0.1, "first wall-pressure step moved through terrain after enemy removal"):
		return false
	for sample: Dictionary in result.samples.slice(1):
		if not _assert_true(not sample.pending and sample.trace.is_empty() and sample.slide_collision_count > 0, "continued wall input did not return to normal movement with actual slide collisions"):
			return false
	await _dispose(fixture)
	return true

func _test_second_entity() -> bool:
	var fixture := await _recovery_fixture()
	var second := _enemy(fixture, Vector2(55.0, -60.0))
	await physics_frame
	await process_frame
	var radius_sum: float = PlayerScript.BODY_RADIUS + second.body_radius
	if not _assert_true(RECOVERY_START.distance_to(second.global_position) > radius_sum and second.global_position.x + second.body_radius < RECOVERY_WALL.position.x, "second entity must initially overlap neither Player nor terrain"):
		return false
	var result := await _run_recovery(fixture, Vector2.UP, 2.0, "constrained_path_second_entity")
	if not _safe_recovery(result):
		return false
	var minimum_gap := INF
	var recovery_constrained := false
	var body_input_constrained := false
	for sample in result.samples:
		var offset: Vector2 = sample.position - second.global_position
		minimum_gap = minf(minimum_gap, offset.length())
		recovery_constrained = recovery_constrained or sample.trace.get("recovery_changed", false)
		for input_step: Dictionary in sample.trace.get("input_steps", []):
			body_input_constrained = body_input_constrained or (input_step.bodies.blocked and input_step.bounded.distance_to(input_step.accepted) > 0.001)
		if not _assert_true(offset.length() >= radius_sum - 0.1 and (absf(offset.x) >= radius_sum or offset.y >= sqrt(radius_sum * radius_sum - offset.x * offset.x) - 0.1), "terrain-constrained path crossed a previously non-overlapping enemy"):
			return false
	if not _assert_true((recovery_constrained or body_input_constrained) and minimum_gap <= radius_sum + 0.5, "second-entity test never exercised a recovery or body-input constraint near the new body"):
		return false
	await _dispose(fixture)
	return true

func _test_actual_pause() -> bool:
	# SceneTree component test: real PAUSED notification, not Main/UI/save flows.
	var fixture := await _recovery_fixture(false)
	if not fixture.setup_ok:
		return false
	fixture.player._start_dash(Vector2.UP)
	fixture.player.set_physics_process(true)
	Input.action_press(&"move_up")
	self.paused = true
	await process_frame
	var stopped_at: Vector2 = fixture.player.global_position
	var dash_time: float = fixture.player.dash_timer
	var cooldown: float = fixture.player.dash_cooldown_remaining
	for index in range(3):
		await physics_frame
		await process_frame
		if not _assert_true(fixture.player.global_position == stopped_at and is_equal_approx(fixture.player.dash_timer, dash_time) and is_equal_approx(fixture.player.dash_cooldown_remaining, cooldown) and not fixture.player.is_stealthed(), "paused physics advanced position/skill clocks or failed pause cleanup"):
			return false
	self.paused = false
	var result := await _run_recovery(fixture, Vector2.UP, 2.0, "resume_after_real_pause")
	if not _safe_recovery(result) or not _assert_true(not fixture.player.stealth_recovery_pending and fixture.player.global_position.y < stopped_at.y - 40.0, "resuming after pause retained stale blocked motion"):
		return false
	await _dispose(fixture)
	return true

func _test_never_stealthed_control() -> bool:
	var fixture := await _fixture(RECOVERY_START, RECOVERY_WALL, false)
	var enemy := _enemy(fixture, Vector2(5.0, 0.0))
	fixture["enemy"] = enemy
	enemy.target_player = fixture.player
	await physics_frame
	await process_frame
	var radius_sum: float = PlayerScript.BODY_RADIUS + enemy.body_radius
	if not _assert_true(RECOVERY_START.distance_to(enemy.global_position) > radius_sum, "normal control must begin without forced body overlap"):
		return false
	enemy.apply_spawn_impulse(Vector2.RIGHT * PlayerScript.BASE_MOVE_SPEED, 1.0)
	enemy.set_physics_process(true)
	var result := await _run_recovery(fixture, Vector2.RIGHT, 1.0, "never_stealthed_normal_contact")
	enemy.set_physics_process(false)
	if not result.ok:
		return false
	var minimum_gap := INF
	var violations := 0
	var first_violation: Dictionary = {}
	for sample in result.samples:
		minimum_gap = minf(minimum_gap, sample.position.distance_to(sample.enemy_position))
		var point: Vector2 = sample.position
		if point.x > RECOVERY_WALL.position.x - sample.radius + 0.1 or point.distance_to(point.clamp(RECOVERY_WALL.position, RECOVERY_WALL.end)) < sample.radius - 0.1:
			violations += 1
			if first_violation.is_empty():
				first_violation = sample
		if not _assert_true(not sample.pending, "never-stealthed normal control unexpectedly entered recovery guard"):
			return false
	await _dispose(fixture)
	if violations > 0:
		print("NORMAL_CONTROL needs_review: terrain_violating_steps=%d minimum_enemy_gap=%.6f first_violation=%s; report separately, do not broaden the stealth fix" % [violations, minimum_gap, JSON.stringify(first_violation)])
		quit(2)
		return false
	return _assert_true(minimum_gap <= radius_sum + 0.2, "normal control never established actual enemy/body contact")
