extends SceneTree

const BossProjectilePatternScript = preload("res://scripts/components/BossProjectilePattern.gd")

var assertions := 0

func _assert_true(condition: bool, message: String) -> bool:
	assertions += 1
	if condition:
		return true
	push_error("TEST FAIL: BossPatternTest: " + message)
	quit(1)
	return false

func _initialize() -> void:
	var fixture := Node2D.new()
	root.add_child(fixture)
	var target := Node2D.new()
	var projectiles := Node2D.new()
	var pattern: Node2D = BossProjectilePatternScript.new()
	fixture.add_child(target)
	fixture.add_child(projectiles)
	fixture.add_child(pattern)
	target.global_position = Vector2(400.0, 0.0)
	pattern.global_position = Vector2.ZERO
	pattern.configure(projectiles, Rect2(-900.0, -600.0, 1800.0, 1200.0), target, 77, 12345)
	pattern.set_process(false)

	if not _assert_true(pattern.start_pattern(&"aimed_fan"), "Aimed Fan did not start through the public pattern API"):
		return
	var aimed_plan: Array = pattern.get_active_plan()
	if not _assert_true(aimed_plan.size() >= 10 and aimed_plan.size() <= 14, "Aimed Fan did not plan two 5-7 projectile rounds"):
		return
	for event: Dictionary in aimed_plan:
		if not _assert_true(float(event.time) >= 0.45, "Aimed Fan planned a projectile before its 0.45 second warning"):
			return
		if not _assert_true(float(event.speed) >= 220.0 and float(event.speed) <= 280.0, "Aimed Fan speed escaped 220-280 px/s"):
			return
	var first_round_time := float(aimed_plan[0].time)
	var second_round_time := -1.0
	for event: Dictionary in aimed_plan:
		if int(event.round) == 1:
			second_round_time = float(event.time)
			break
	if not _assert_true(second_round_time - first_round_time >= 0.55, "Aimed Fan did not preserve a 0.55 second dodge window between rounds"):
		return

	pattern.advance(0.44)
	if not _assert_true(projectiles.get_child_count() == 0, "Aimed Fan fired during its warning"):
		return
	target.global_position = Vector2(0.0, 400.0)
	pattern.advance(0.02)
	if not _assert_true(projectiles.get_child_count() >= 5, "Aimed Fan warning did not resolve into its first round"):
		return
	for projectile in projectiles.get_children():
		if not _assert_true(projectile.velocity.normalized().dot(Vector2.RIGHT) > 0.8, "Aimed Fan tracked the target after locking"):
			return

	var deterministic_a: Node2D = BossProjectilePatternScript.new()
	var deterministic_b: Node2D = BossProjectilePatternScript.new()
	fixture.add_child(deterministic_a)
	fixture.add_child(deterministic_b)
	deterministic_a.configure(projectiles, Rect2(), target, 88, 991)
	deterministic_b.configure(projectiles, Rect2(), target, 89, 991)
	deterministic_a.set_process(false)
	deterministic_b.set_process(false)
	if not _assert_true(deterministic_a.start_pattern(&"aimed_fan") and deterministic_b.start_pattern(&"aimed_fan"), "deterministic fixtures did not start"):
		return
	if not _assert_true(deterministic_a.get_active_plan() == deterministic_b.get_active_plan(), "equal seeds produced different Aimed Fan plans"):
		return

	pattern.cancel(true)
	await process_frame
	target.global_position = Vector2(400.0, 0.0)
	pattern.configure(projectiles, Rect2(-900.0, -600.0, 1800.0, 1200.0), target, 77, 2468)
	if not _assert_true(pattern.start_pattern(&"twin_spiral"), "Twin Spiral did not start through the public pattern API"):
		return
	var spiral_plan: Array = pattern.get_active_plan()
	if not _assert_true(spiral_plan.size() >= 16 and spiral_plan.size() <= 20 and spiral_plan.size() <= 72, "Twin Spiral did not plan 8-10 two-shot groups within its cap"):
		return
	var group_times: Array[float] = []
	var offsets: Array[Vector2] = []
	for event: Dictionary in spiral_plan:
		if not group_times.has(float(event.time)):
			group_times.append(float(event.time))
		if not offsets.has(Vector2(event.offset)):
			offsets.append(Vector2(event.offset))
		if not _assert_true(float(event.speed) >= 150.0 and float(event.speed) <= 210.0, "Twin Spiral speed escaped 150-210 px/s"):
			return
		var angle_from_player := absf(wrapf(Vector2(event.direction).angle(), -PI, PI))
		if not _assert_true(angle_from_player <= deg_to_rad(60.0) + 0.001, "Twin Spiral invaded its declared 240 degree safe channel"):
			return
	if not _assert_true(group_times.size() >= 8 and group_times.size() <= 10 and offsets.size() == 2, "Twin Spiral did not use 8-10 groups from two relative firing points"):
		return
	for index in range(1, group_times.size()):
		if not _assert_true(is_equal_approx(group_times[index] - group_times[index - 1], 0.14), "Twin Spiral group interval was not 0.14 seconds"):
			return

	pattern.cancel(true)
	await process_frame
	pattern.configure(projectiles, Rect2(-900.0, -600.0, 1800.0, 1200.0), target, 77, 8642)
	if not _assert_true(pattern.start_pattern(&"broken_ring"), "Broken Ring did not start through the public pattern API"):
		return
	var ring_plan: Array = pattern.get_active_plan()
	if not _assert_true(ring_plan.size() >= 60 and ring_plan.size() <= 72, "Broken Ring did not plan three 20-24 projectile rounds"):
		return
	var round_events := {0: [], 1: [], 2: []}
	var gap_centers: Array[float] = []
	for event: Dictionary in ring_plan:
		(round_events[int(event.round)] as Array).append(event)
		var gap_degrees := float(event.gap_degrees)
		var gap_center := float(event.gap_center)
		if not gap_centers.has(gap_center):
			gap_centers.append(gap_center)
		if not _assert_true(gap_degrees >= 46.0 and gap_degrees <= 60.0, "Broken Ring gap escaped 46-60 degrees"):
			return
		var from_gap_center := absf(wrapf(Vector2(event.direction).angle() - gap_center, -PI, PI))
		if not _assert_true(from_gap_center + 0.001 >= deg_to_rad(gap_degrees * 0.5), "Broken Ring projectile invaded the safe gap"):
			return
	for round_index in range(3):
		var round_count := (round_events[round_index] as Array).size()
		if not _assert_true(round_count >= 20 and round_count <= 24, "Broken Ring round %d did not contain 20-24 projectiles" % round_index):
			return
	if not _assert_true(gap_centers.size() == 3 and absf(wrapf(gap_centers[0], -PI, PI)) <= 0.001, "Broken Ring first gap did not face the player"):
		return
	for index in range(1, gap_centers.size()):
		var rotation_degrees := absf(rad_to_deg(wrapf(gap_centers[index] - gap_centers[index - 1], -PI, PI)))
		if not _assert_true(rotation_degrees >= 25.0 and rotation_degrees <= 35.0, "Broken Ring gap did not rotate 25-35 degrees between rounds"):
			return

	pattern.cancel()
	await process_frame
	if not _assert_true(projectiles.get_child_count() == 0 and not pattern.is_pattern_active(), "cancel did not clear this controller's active pattern and projectiles"):
		return
	if not _assert_true(not pattern.start_pattern(&"aimed_fan"), "cancel removed the required inter-pattern blank window"):
		return
	pattern.advance(pattern.PATTERN_BLANK_WINDOW_SECONDS + 0.01)
	if not _assert_true(pattern.start_pattern(&"aimed_fan"), "pattern did not recover after the inter-pattern blank window"):
		return
	pattern.advance(0.46)
	var owned_projectile: Node = projectiles.get_child(0)
	if not _assert_true(owned_projectile.is_in_group(&"boss_projectiles"), "Boss projectile did not enter its dedicated group"):
		return
	if not _assert_true(int(owned_projectile.get_meta(&"boss_owner_id", -1)) == 77, "Boss projectile did not carry boss_owner_id metadata"):
		return
	pattern.clear()
	await process_frame
	if not _assert_true(projectiles.get_child_count() == 0 and not pattern.is_pattern_active(), "clear did not cancel and remove this controller's projectiles"):
		return

	var foreign_projectile := Node2D.new()
	foreign_projectile.add_to_group(&"boss_projectiles")
	projectiles.add_child(foreign_projectile)
	for index in range(138):
		var filler := Node2D.new()
		filler.add_to_group(&"boss_projectiles")
		fixture.add_child(filler)
	pattern.advance(pattern.PATTERN_BLANK_WINDOW_SECONDS + 0.01)
	pattern.configure(projectiles, Rect2(), target, 77, 54321)
	if not _assert_true(pattern.start_pattern(&"aimed_fan"), "cap fixture could not start Aimed Fan"):
		return
	pattern.advance(0.46)
	var global_boss_projectiles := get_nodes_in_group(&"boss_projectiles")
	if not _assert_true(global_boss_projectiles.size() == pattern.GLOBAL_PROJECTILE_CAP, "global Boss projectile cap did not stop exactly at 140"):
		return
	pattern.clear()
	await process_frame
	if not _assert_true(is_instance_valid(foreign_projectile), "controller clear removed a projectile it did not own"):
		return

	for pattern_id in [&"aimed_fan", &"twin_spiral", &"broken_ring"]:
		if not _assert_true(_make_plan(pattern_id, 112233) == _make_plan(pattern_id, 112233), "%s changed for an equal seed" % pattern_id):
			return
		var at_30_hz := _simulate_pattern(pattern_id, 30)
		if not _assert_true(at_30_hz == _simulate_pattern(pattern_id, 60), "%s changed between 30Hz and 60Hz" % pattern_id):
			return
		if not _assert_true(at_30_hz == _simulate_pattern(pattern_id, 120), "%s changed between 30Hz and 120Hz" % pattern_id):
			return

	var budget_target := Node2D.new()
	var budget_projectiles := Node2D.new()
	var budget_pattern: Node2D = BossProjectilePatternScript.new()
	budget_target.position = Vector2(400.0, 0.0)
	if not _assert_true(budget_pattern.has_method("get_total_spawned"), "controller did not expose generation-budget telemetry"):
		return
	var simulated_seconds := 30.0
	var elapsed := 0.0
	while elapsed < simulated_seconds:
		budget_pattern.configure(budget_projectiles, Rect2(), budget_target, 501, 90)
		budget_pattern.start_pattern(&"broken_ring")
		budget_pattern.advance(0.33)
		budget_pattern.cancel(false)
		elapsed += 0.33
	var generated := int(budget_pattern.get_total_spawned())
	var sustained_rate := float(maxi(0, generated - int(budget_pattern.SPAWN_BURST_CAPACITY))) / elapsed
	if not _assert_true(sustained_rate <= budget_pattern.MAX_PROJECTILES_PER_SECOND + 0.001, "sustained generation budget exceeded 40 projectiles/second"):
		return
	budget_pattern.free()
	budget_projectiles.free()
	budget_target.free()

	fixture.queue_free()
	await process_frame
	print("TEST PASS: BossPatternTest %d" % assertions)
	quit(0)

func _make_plan(pattern_id: StringName, seed_value: int) -> Array[Dictionary]:
	var target := Node2D.new()
	var projectiles := Node2D.new()
	var pattern: Node2D = BossProjectilePatternScript.new()
	target.position = Vector2(420.0, -35.0)
	pattern.configure(projectiles, Rect2(), target, 600, seed_value)
	pattern.start_pattern(pattern_id)
	var plan: Array[Dictionary] = pattern.get_active_plan()
	pattern.free()
	projectiles.free()
	target.free()
	return plan

func _simulate_pattern(pattern_id: StringName, frames_per_second: int) -> Array:
	var target := Node2D.new()
	var projectiles := Node2D.new()
	var pattern: Node2D = BossProjectilePatternScript.new()
	target.position = Vector2(420.0, -35.0)
	pattern.configure(projectiles, Rect2(), target, 601, 778899)
	pattern.start_pattern(pattern_id)
	for frame in range(frames_per_second * 3):
		pattern.advance(1.0 / float(frames_per_second))
	var signature: Array = []
	for projectile in projectiles.get_children():
		signature.append([projectile.velocity, projectile.position, projectile.get_meta(&"boss_pattern")])
	pattern.free()
	projectiles.free()
	target.free()
	return signature
