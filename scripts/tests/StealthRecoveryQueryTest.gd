extends "res://scripts/tests/StealthTerrainTest.gd"

# Engine prerequisite probe, not acceptance of the recovery movement algorithm.
# Match --fixed-fps 30/60/120 with -- --physics-hz=30/60/120.

func _assert_true(condition: bool, message: String) -> bool:
	assertions += 1
	if condition:
		return true
	_release_input()
	push_error("TEST FAIL: StealthRecoveryQueryTest: " + message)
	quit(1)
	return false

func _initialize() -> void:
	call_deferred("_run_suite")

func _run_suite() -> void:
	await process_frame
	if not _assert_true(root.is_node_ready(), "root must be ready before constructing fixtures"):
		return
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--physics-hz="):
			Engine.physics_ticks_per_second = argument.trim_prefix("--physics-hz=").to_int()
	if not _assert_true(Engine.physics_ticks_per_second in [30, 60, 120], "physics-hz must be 30, 60, or 120"):
		return
	for label in ["open", "nonoverlap", "wall_overlap", "enemy_overlap", "wall_enemy", "disabled_shape"]:
		if not await _test_query(label):
			return
	print("TEST PASS: StealthRecoveryQueryTest %d hz=%d cases=6" % [assertions, Engine.physics_ticks_per_second])
	quit(0)

func _test_query(label: String) -> bool:
	var has_wall := label in ["nonoverlap", "wall_overlap", "wall_enemy", "disabled_shape"]
	var start := Vector2.ZERO
	if label == "wall_overlap":
		start.x = THIN_WALL.position.x - PlayerScript.BODY_RADIUS + 5.0
	elif label in ["wall_enemy", "disabled_shape"]:
		start.x = THIN_WALL.position.x - PlayerScript.BODY_RADIUS
	var fixture := await _fixture(start, THIN_WALL if has_wall else Rect2())
	var player: Node = fixture.player
	if label in ["nonoverlap", "enemy_overlap", "wall_enemy", "disabled_shape"]:
		_enemy(fixture, Vector2(-200.0, 0.0) if label == "nonoverlap" else start + Vector2.LEFT * 30.0)
		await physics_frame
		await process_frame
	if label == "disabled_shape":
		# Keep the normal mask/layer: isolate the disabled-shape prerequisite.
		player.player_collision.set_deferred("disabled", true)
		await process_frame
		await physics_frame
		await process_frame
	player.velocity = Vector2(17.0, -23.0) # Zero motion must not consume this velocity.
	var shape_query := PhysicsShapeQueryParameters2D.new()
	shape_query.shape = player.player_collision.shape
	shape_query.transform = player.player_collision.global_transform
	shape_query.collision_mask = player.normal_collision_mask
	shape_query.collide_with_areas = false
	shape_query.exclude = [player.get_rid()]
	var overlaps: Array[Dictionary] = player.get_world_2d().direct_space_state.intersect_shape(shape_query, 32)
	var expected_overlap := label not in ["open", "nonoverlap"]
	if not _assert_true((not overlaps.is_empty()) == expected_overlap, label + ": physical fixture overlap precondition failed"):
		return false
	var before := _query_state(player)
	var parameters := PhysicsTestMotionParameters2D.new()
	parameters.from = player.global_transform # Body transform, not child shape transform.
	parameters.motion = Vector2.ZERO
	parameters.margin = player.safe_margin
	parameters.recovery_as_collision = true
	var result := PhysicsTestMotionResult2D.new()
	var collided := PhysicsServer2D.body_test_motion(player.get_rid(), parameters, result)
	var travel := result.get_travel() # Read even when the Boolean result is false.
	var after := _query_state(player)
	var body_enabled: bool = not player.player_collision.disabled
	var valid_recovery_evidence: bool = body_enabled and player.collision_mask == player.normal_collision_mask and player.collision_layer == player.normal_collision_layer
	print("RECOVERY QUERY: " + JSON.stringify({"case": label, "hz": Engine.physics_ticks_per_second,
		"physics_frame": Engine.get_physics_frames(), "query_returned_collision": collided,
		"travel": [travel.x, travel.y], "body_enabled": body_enabled,
		"valid_recovery_evidence": valid_recovery_evidence, "independent_shape_overlaps": overlaps.size(),
		"state_unchanged": before == after, "movement_acceptance": "not_tested"}))
	if not _assert_true(travel.is_finite(), label + ": query returned non-finite travel"):
		return false
	for key in before:
		if not _assert_true(before[key] == after[key], label + ": query changed " + str(key)):
			return false
	if label == "disabled_shape":
		if not _assert_true(not valid_recovery_evidence and expected_overlap and travel.is_zero_approx(), "disabled body zero travel must not count as absence of overlap or valid recovery"):
			return false
	elif not _assert_true(valid_recovery_evidence and (travel.length() > 0.001 if expected_overlap else travel.is_zero_approx()), label + ": unexpected zero-motion recovery travel"):
		return false
	await _dispose(fixture)
	return true

func _query_state(player: Node) -> Dictionary:
	return {"position": player.global_position, "transform": player.global_transform,
		"velocity": player.velocity, "layer": player.collision_layer, "mask": player.collision_mask,
		"disabled": player.player_collision.disabled, "shape_id": player.player_collision.shape.get_instance_id(),
		"shape_radius": player.player_collision.shape.radius, "shape_transform": player.player_collision.global_transform,
		"health": player.health.current_health, "max_health": player.health.max_health,
		"shield": player.shield, "pending": player.stealth_recovery_pending}
