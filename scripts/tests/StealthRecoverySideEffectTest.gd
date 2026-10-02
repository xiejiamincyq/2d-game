extends "res://scripts/tests/StealthRecoveryTest.gd"

const CoinSensor = preload("res://scripts/pickups/CoinPickup.gd")
const ProjectileSensor = preload("res://scripts/components/Projectile.gd")

func _assert_true(condition: bool, message: String) -> bool:
	assertions += 1
	if condition:
		return true
	_release_input()
	self.paused = false
	push_error("TEST FAIL: StealthRecoverySideEffectTest: " + message)
	quit(1)
	return false

func _initialize() -> void:
	call_deferred("_run_suite")

func _run_suite() -> void:
	await process_frame
	if not _assert_true(root.is_node_ready(), "root must be ready before creating sensor/recovery fixtures"):
		return
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--physics-hz="):
			Engine.physics_ticks_per_second = argument.trim_prefix("--physics-hz=").to_int()
	if not _assert_true(Engine.physics_ticks_per_second in [30, 60, 120], "physics-hz must be 30, 60, or 120"):
		return
	for kind in ["coin", "projectile"]:
		for positive in [false, true]:
			if not await _test_sensor(kind, positive):
				return
	print("TEST PASS: StealthRecoverySideEffectTest %d" % assertions)
	quit(0)

func _flush_sensor_steps(count: int) -> bool:
	var first := Engine.get_physics_frames()
	for index in range(count):
		await physics_frame
		await process_frame
		if not _assert_true(Engine.get_physics_frames() == first + index + 1, "sensor flush skipped/duplicated an actual physics step"):
			return false
	return true

func _test_sensor(kind: String, positive: bool) -> bool:
	var fixture := await _recovery_fixture()
	if not fixture.setup_ok:
		return false
	var player: Node = fixture.player
	var sensor: Area2D = CoinSensor.new() if kind == "coin" else ProjectileSensor.new()
	var expected_radius := 9.0 if kind == "coin" else 4.0
	var sensor_position := RECOVERY_START + (Vector2(0.0, -35.0) if positive else Vector2(PlayerScript.BODY_RADIUS + expected_radius + 2.0, 0.0))
	var collections := [0]
	var collected_value := [0]
	var player_entries := [0]
	if kind == "coin":
		sensor.value = 7
		sensor.target_player = player
		sensor.collected.connect(func(value: int) -> void:
			collections[0] += 1
			collected_value[0] += value)
	else:
		sensor.target_group = &"player"
		sensor.damage = 3.0
	sensor.position = sensor_position
	fixture.scene.add_child(sensor)
	# Freeze only homing/translation/lifetime logic. Keep the genuine Area2D
	# monitoring and component-owned body_entered handlers completely intact.
	sensor.set_physics_process(false)
	sensor.body_entered.connect(func(body: Node) -> void:
		if body == player:
			player_entries[0] += 1)
	if not await _flush_sensor_steps(2):
		return false
	var circles: Array[CollisionShape2D] = []
	for child in sensor.get_children():
		if child is CollisionShape2D:
			circles.append(child)
	if not _assert_true(circles.size() == 1 and circles[0].shape is CircleShape2D and is_equal_approx(circles[0].shape.radius, expected_radius) and not circles[0].disabled and sensor.monitoring and not sensor.is_physics_processing(), "sensor must retain its actual active circular Area shape while motion is disabled"):
		return false
	var radius_sum: float = player.player_collision.shape.radius + circles[0].shape.radius
	if not positive and not _assert_true(absf(player.global_position.distance_to(sensor_position) - radius_sum - 2.0) <= 0.001, "negative sensor must begin exactly 2 px beyond the accepted body"):
		return false
	if not _assert_true(player.global_position.distance_to(sensor_position) > radius_sum + 0.1 and not sensor.get_overlapping_bodies().has(player) and player_entries[0] == 0, "sensor already touched the accepted start; negative/positive geometry is not distinguishable"):
		return false
	if not _assert_true(player.health.can_accept_damage() and is_zero_approx(player.shield) and not player.is_damage_immune(), "damage control was protected by shield or immunity"):
		return false
	var health_before: float = player.health.current_health
	var direction := Vector2.UP if positive else Vector2.RIGHT
	var result := await _run_recovery(fixture, direction, 0.8, "sensor_%s_positive_%s" % [kind, positive])
	if not _safe_recovery(result):
		return false
	# Area callbacks may arrive on the next server flush; retain the accepted
	# position for three further real steps instead of stopping at the movement tick.
	if not await _flush_sensor_steps(3):
		return false
	var proposal_contacts := 0
	var accepted_contacts := 0
	var minimum_accepted_gap := INF
	for sample in result.samples:
		var accepted_gap: float = sample.position.distance_to(sensor_position) - radius_sum
		minimum_accepted_gap = minf(minimum_accepted_gap, accepted_gap)
		if accepted_gap < -0.1:
			accepted_contacts += 1
		# This is a read-only native recovery proposal, never an actual body pose.
		# Do not write it back merely to manufacture an Area callback negative control.
		if sample.trace.has("start") and sample.trace.has("recovery_requested"):
			var proposal: Vector2 = sample.trace.start + sample.trace.recovery_requested
			if proposal.distance_to(sensor_position) < radius_sum - 0.1:
				proposal_contacts += 1
	var health_lost: float = health_before - player.health.current_health
	print("RECOVERY SIDE EFFECT: kind=%s positive=%s sensor=%s radius_sum=%.6f readonly_proposal_contacts=%d accepted_contacts=%d minimum_accepted_gap=%.6f player_entries=%d collections=%d value=%d health_lost=%.6f" % [kind, positive, sensor_position, radius_sum, proposal_contacts, accepted_contacts, minimum_accepted_gap, player_entries[0], collections[0], collected_value[0], health_lost])
	if positive:
		if not _assert_true(accepted_contacts > 0 and player_entries[0] == 1, "positive control did not demonstrate an accepted physical contact and one genuine Area callback"):
			return false
		if kind == "coin":
			if not _assert_true(collections[0] == 1 and collected_value[0] == 7 and is_zero_approx(health_lost), "accepted CoinPickup contact did not irreversibly collect exactly once"):
				return false
		elif not _assert_true(is_equal_approx(health_lost, 3.0), "accepted hostile Projectile contact did not cause actual damage"):
			return false
	else:
		if not _assert_true(proposal_contacts > 0 and accepted_contacts == 0 and minimum_accepted_gap > 0.1, "readonly recovery proposal does not exercise the required rejected-contact geometry; this negative control is unproven, not a safety pass"):
			return false
		if not _assert_true(is_instance_valid(sensor) and not sensor.is_queued_for_deletion() and player_entries[0] == 0 and collections[0] == 0 and is_zero_approx(health_lost), "read-only rejected recovery proposal was accompanied by an irreversible Area pickup/damage callback"):
			return false
	await _dispose(fixture)
	return true
