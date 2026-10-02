extends "res://scripts/tests/StealthRecoveryTest.gd"

const ACCOUNTING_EPS := 0.001
const GEOMETRY_EPS := 0.1
const ACCOUNTING_SLOTS := 4

func _assert_true(condition: bool, message: String) -> bool:
	assertions += 1
	if condition:
		return true
	_release_input()
	push_error("TEST FAIL: StealthRecoveryAccountingTest: " + message)
	quit(1)
	return false

func _initialize() -> void:
	call_deferred("_run_suite")

func _run_suite() -> void:
	await process_frame
	if not _assert_true(root.is_node_ready(), "root must be ready before recovery fixtures"):
		return
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--physics-hz="):
			Engine.physics_ticks_per_second = argument.trim_prefix("--physics-hz=").to_int()
	if not _assert_true(Engine.physics_ticks_per_second in [30, 60, 120], "invalid physics-hz") or not _test_checker_contract():
		return
	if OS.get_cmdline_user_args().has("--checker-only"):
		print("TEST PASS: StealthRecoveryAccountingChecker %d" % assertions)
		quit(0)
		return
	if not await _test_real_ledger(false) or not await _test_real_ledger(true) or not await _test_real_ledger(false, true):
		return
	print("TEST PASS: StealthRecoveryAccountingTest %d" % assertions)
	quit(0)

# Independent vector accounting: no Player/TerrainSweep movement helper is called.
# playable_bounds is an optional TEST-ATTACHED center-position rectangle.
func check_trace(trace: Dictionary) -> Dictionary:
	var errors: Array[String] = []
	for key in ["start", "accepted", "requested_motion", "recovery_requested", "recovery_accepted"]:
		if not trace.has(key) or typeof(trace[key]) != TYPE_VECTOR2 or not trace[key].is_finite():
			errors.append("missing/nonfinite Vector2: " + key)
	for key in ["recovery_slots", "slots_used"]:
		if not trace.has(key) or typeof(trace[key]) != TYPE_INT:
			errors.append("missing integer: " + key)
	if not trace.has("input_steps") or typeof(trace.input_steps) != TYPE_ARRAY:
		errors.append("missing input_steps ledger")
	if not trace.has("changed_any") or typeof(trace.changed_any) != TYPE_BOOL:
		errors.append("missing changed_any history flag")
	if not errors.is_empty():
		return {"ok": false, "errors": errors}
	var requested: Vector2 = trace.requested_motion
	var recovery: Vector2 = trace.recovery_requested
	var recovery_accepted: Vector2 = trace.recovery_accepted
	_require(errors, _is_prefix(recovery_accepted, recovery), "R is not a straight safe prefix")
	_require(errors, trace.recovery_slots in [0, 1], "R used more than one slot")
	_require(errors, recovery.length() <= ACCOUNTING_EPS or trace.recovery_slots == 1, "nonzero R has no processing slot")
	_require(errors, trace.slots_used == trace.recovery_slots + trace.input_steps.size() and trace.slots_used <= ACCOUNTING_SLOTS, "shared R/U slots are not accounted once or exceed four")
	var remaining := requested
	var position: Vector2 = trace.start + recovery_accepted
	var input_distance := 0.0
	var changed := recovery.distance_to(recovery_accepted) > ACCOUNTING_EPS
	for index in range(trace.input_steps.size()):
		var raw: Variant = trace.input_steps[index]
		if typeof(raw) != TYPE_DICTIONARY:
			errors.append("input step is not a dictionary")
			break
		var record: Dictionary = raw
		var valid := true
		for key in ["before", "bounded", "accepted", "after"]:
			if not record.has(key) or typeof(record[key]) != TYPE_VECTOR2 or not record[key].is_finite():
				errors.append("input[%d] missing/nonfinite %s" % [index, key])
				valid = false
		if not record.has("normals") or typeof(record.normals) != TYPE_ARRAY:
			errors.append("input[%d] missing normals" % index)
			valid = false
		if not valid:
			break
		var before: Vector2 = record.before
		var bounded: Vector2 = record.bounded
		var accepted: Vector2 = record.accepted
		var after: Vector2 = record.after
		_require(errors, before.distance_to(remaining) <= ACCOUNTING_EPS, "input[%d] source chain replenished remaining" % index)
		var expected_bounded := before
		if trace.has("playable_bounds"):
			var bounds: Rect2 = trace.playable_bounds
			expected_bounded = (position + before).clamp(bounds.position, bounds.end) - position
		_require(errors, bounded.distance_to(expected_bounded) <= ACCOUNTING_EPS, "input[%d] world clamp differs from independent oracle" % index)
		_require(errors, _is_prefix(accepted, bounded), "input[%d] accepted is not alpha * bounded" % index)
		var projected := bounded - accepted
		changed = changed or before.distance_to(bounded) > ACCOUNTING_EPS or bounded.distance_to(accepted) > ACCOUNTING_EPS
		for normal_value in record.normals:
			if typeof(normal_value) != TYPE_VECTOR2 or not normal_value.is_finite() or absf(normal_value.length() - 1.0) > ACCOUNTING_EPS:
				errors.append("input[%d] effective normal must be finite/unit length" % index)
				continue
			var normal: Vector2 = normal_value
			var old_length := projected.length()
			var inward := projected.dot(normal)
			_require(errors, inward <= ACCOUNTING_EPS, "input[%d] effective normal points away from remaining" % index)
			if inward < 0.0:
				projected -= normal * inward
			changed = changed or inward < -ACCOUNTING_EPS
			_require(errors, projected.length() <= old_length + ACCOUNTING_EPS, "input projection amplified remaining")
		_require(errors, after.distance_to(projected) <= ACCOUNTING_EPS, "input[%d] after differs from ordered normal projections" % index)
		input_distance += accepted.length()
		_require(errors, input_distance + after.length() <= requested.length() + ACCOUNTING_EPS, "input[%d] cumulative path budget increased" % index)
		position += accepted
		remaining = after
		changed = changed or record.get("query_saturated", false) or record.get("embedded", false)
		if record.has("changed_any"):
			_require(errors, record.changed_any == changed, "input[%d] changed_any lost monotonic history" % index)
	if trace.has("discarded_remaining"):
		_require(errors, typeof(trace.discarded_remaining) == TYPE_VECTOR2, "discard must be a Vector2")
		if typeof(trace.discarded_remaining) == TYPE_VECTOR2:
			_require(errors, trace.discarded_remaining.distance_to(remaining) <= ACCOUNTING_EPS, "discard is not the last projected remaining")
	if remaining.length() > ACCOUNTING_EPS:
		_require(errors, typeof(trace.get("discarded_remaining")) == TYPE_VECTOR2, "unspent remaining needs explicit discard")
		_require(errors, not str(trace.get("termination_reason", "")).is_empty(), "discard needs a termination reason")
		changed = true
	_require(errors, position.distance_to(trace.accepted) <= ACCOUNTING_EPS, "end-start does not equal Raccepted + sum Uaccepted")
	# Saturation/embedded classification is separately reported, never a clean step.
	changed = changed or trace.get("query_saturated", false) or trace.get("embedded", false)
	_require(errors, trace.changed_any == changed, "changed_any does not preserve all stage changes")
	return {"ok": errors.is_empty(), "errors": errors}

func _require(errors: Array[String], condition: bool, message: String) -> void:
	if not condition:
		errors.append(message)

func _is_prefix(part: Vector2, whole: Vector2) -> bool:
	if whole.length() <= ACCOUNTING_EPS:
		return part.length() <= ACCOUNTING_EPS
	var ratio := part.dot(whole) / whole.length_squared()
	return part.distance_to(whole * clampf(ratio, 0.0, 1.0)) <= ACCOUNTING_EPS

func _step(before: Vector2, accepted: Vector2, normals: Array = [], after := Vector2.ZERO) -> Dictionary:
	return {"before": before, "bounded": before, "accepted": accepted, "normals": normals, "after": after}

func _synthetic(requested: Vector2, steps: Array, changed := false) -> Dictionary:
	var end := Vector2.ZERO
	for record in steps:
		end += record.accepted
	return {"start": Vector2.ZERO, "accepted": end, "requested_motion": requested,
		"recovery_requested": Vector2.ZERO, "recovery_accepted": Vector2.ZERO, "recovery_slots": 0,
		"input_steps": steps, "slots_used": steps.size(), "changed_any": changed}

func _expect_checker(trace: Dictionary, expected: bool, label: String, required_error := "") -> bool:
	var result := check_trace(trace)
	print("ACCOUNTING MATH: %s expected=%s actual=%s errors=%s" % [label, expected, result.ok, result.errors])
	return _assert_true(result.ok == expected and (required_error.is_empty() or str(result.errors).contains(required_error)), label + ": " + str(result.errors))

func _test_checker_contract() -> bool:
	if not _assert_true(_segment_rect_gap(Vector2.ZERO, Vector2(160, 0), Rect2(80, -100, 20, 200)) == 0.0 and _segment_point_gap(Vector2.ZERO, Vector2(20, 0), Vector2(10, 0)) == 0.0, "segment oracle must reject transit through obstacles despite clear endpoints"):
		return false
	if not _assert_true(absf(_segment_rect_gap(Vector2.ZERO, Vector2(10, 0), Rect2(15, 5, 10, 10)) - sqrt(50.0)) <= ACCOUNTING_EPS, "segment rectangle oracle must preserve round-corner clearance"):
		return false
	var free := _synthetic(Vector2(2, -2), [_step(Vector2(2, -2), Vector2(2, -2))])
	if not _expect_checker(free, true, "unobstructed input"):
		return false
	var projected := _synthetic(Vector2(2, -2), [_step(Vector2(2, -2), Vector2(1, -1), [Vector2.LEFT], Vector2.UP), _step(Vector2.UP, Vector2.UP)], true)
	projected.recovery_requested = Vector2(2, 0)
	projected.recovery_accepted = Vector2(1, 0)
	projected.recovery_slots = 1
	projected.slots_used = 3
	projected.accepted += Vector2(1, 0)
	if not _expect_checker(projected, true, "independent R prefix and continuous U projection"):
		return false
	var replenished := _synthetic(Vector2(2, -2), [_step(Vector2(2, -2), Vector2(1, -1), [Vector2(-1, 1).normalized()]), _step(Vector2(1, 1), Vector2(1, 1))], true)
	if not _assert_true(absf(Vector2(1, -1).length() + Vector2(1, 1).length() - Vector2(2, -2).length()) <= ACCOUNTING_EPS, "counterexample must not exceed original scalar path budget"):
		return false
	if not _expect_checker(replenished, false, "zero remaining cannot restart as original-input retry", "source chain"):
		return false
	var bounded := _synthetic(Vector2(3, 0), [_step(Vector2(3, 0), Vector2.RIGHT)], true)
	bounded.input_steps[0].bounded = Vector2.RIGHT
	bounded.playable_bounds = Rect2(-1, -1, 2, 2)
	if not _expect_checker(bounded, true, "independent world clamp"):
		return false
	var cancellation := _synthetic(Vector2.LEFT, [_step(Vector2.LEFT, Vector2.ZERO, [Vector2.RIGHT])], true)
	cancellation.recovery_requested = Vector2.RIGHT
	cancellation.recovery_slots = 1
	cancellation.slots_used = 2
	if not _expect_checker(cancellation, true, "history changes even when final equals unconstrained endpoint"):
		return false
	cancellation.changed_any = false
	if not _expect_checker(cancellation, false, "endpoint equality cannot clear changed history", "changed_any"):
		return false
	for exceptional in ["query_saturated", "embedded"]:
		var zero_step := _synthetic(Vector2.ZERO, [_step(Vector2.ZERO, Vector2.ZERO)], true)
		zero_step[exceptional] = true
		zero_step.input_steps[0][exceptional] = true
		zero_step.input_steps[0].changed_any = true
		if not _expect_checker(zero_step, true, "zero bounded stage preserves " + exceptional):
			return false
		zero_step.input_steps[0].changed_any = false
		if not _expect_checker(zero_step, false, "stage cannot defer " + exceptional + " until final", "monotonic history"):
			return false
	for fault in ["source", "prefix", "projection", "endpoint", "slots", "history", "R_prefix"]:
		var bad: Dictionary = projected.duplicate(true)
		match fault:
			"source": bad.input_steps[1].before = Vector2(1, -1)
			"prefix": bad.input_steps[0].accepted = Vector2(1, 1)
			"projection": bad.input_steps[0].after = Vector2(0, -2)
			"endpoint": bad.accepted += Vector2.RIGHT
			"slots": bad.slots_used = 5
			"history": bad.changed_any = false
			"R_prefix": bad.recovery_accepted = Vector2.UP
		if not _expect_checker(bad, false, "reject " + fault):
			return false
	var exhausted := _synthetic(Vector2(4, 0), [_step(Vector2(4, 0), Vector2.RIGHT, [], Vector2(3, 0)), _step(Vector2(3, 0), Vector2.RIGHT, [], Vector2(2, 0)), _step(Vector2(2, 0), Vector2.RIGHT, [], Vector2.RIGHT), _step(Vector2.RIGHT, Vector2.ZERO, [], Vector2.RIGHT)], true)
	exhausted.discarded_remaining = Vector2.RIGHT
	exhausted.termination_reason = "budget_exhausted"
	if not _expect_checker(exhausted, true, "four slots discard explicit unspent remainder"):
		return false
	exhausted.input_steps[1].changed_any = false
	return _expect_checker(exhausted, false, "stage history may not reset", "monotonic history")

func _test_real_ledger(corner: bool, second_body := false) -> bool:
	var rect := Rect2(80, 80, 20, 20) if corner else RECOVERY_WALL
	var start := Vector2(80, 80) - Vector2.ONE.normalized() * PlayerScript.BODY_RADIUS if corner else RECOVERY_START
	var direction := Vector2(1, -1).normalized() if corner else Vector2.UP
	var fixture: Dictionary
	if not corner:
		fixture = await _recovery_fixture()
	else:
		fixture = await _fixture(start, rect, true)
		fixture["enemy"] = _enemy(fixture, start - Vector2(33.1, 0))
		await physics_frame
		await process_frame
		var before := _fixture_state(fixture)
		fixture.player.clear_runtime_modifiers()
		await process_frame
		var restored := _fixture_state(fixture)
		fixture["setup_ok"] = _assert_true(before.enemy_query_hit and before.disabled and restored.pending and restored.enemy_query_hit and not restored.disabled, "outer-corner fixture must actually restore an overlapping enabled body")
	if not fixture.setup_ok:
		return false
	var label := "outer_convex_corner" if corner else "first_enabled_restore"
	var circles := [_circle_geometry(fixture.enemy, start)]
	if second_body:
		var second := _enemy(fixture, Vector2(55, -60))
		await physics_frame
		await process_frame
		circles.append(_circle_geometry(second, start))
		if not _assert_true(start.distance_to(circles[1].position) > PlayerScript.BODY_RADIUS + circles[1].radius + GEOMETRY_EPS, "second body must initially be separated"):
			return false
		label = "restoration_then_second_body"
	var result := await _run_recovery(fixture, direction, 0.8, label)
	if not result.ok:
		return false
	var checked := 0
	var previous := start
	for sample in result.samples:
		var point: Vector2 = sample.position
		if not _assert_true(point.distance_to(point.clamp(rect.position, rect.end)) >= sample.radius - GEOMETRY_EPS and (corner or point.x <= 63.1 + GEOMETRY_EPS), label + " independently measured terrain penetration"):
			return false
		var trace: Dictionary = sample.trace
		if sample.step == 1 or not trace.is_empty():
			var accounting := check_trace(trace)
			if not _assert_true(accounting.ok, "%s step=%d missing/invalid real ledger: %s trace=%s" % [label, sample.step, accounting.errors, JSON.stringify(trace)]):
				return false
			if not _check_accepted_geometry(trace, sample.radius, rect, circles, label):
				return false
			if not _assert_true(trace.start.distance_to(previous) <= ACCOUNTING_EPS and trace.accepted.distance_to(point) <= ACCOUNTING_EPS and trace.requested_motion.distance_to(direction * PlayerScript.BASE_MOVE_SPEED / Engine.physics_ticks_per_second) <= ACCOUNTING_EPS, label + " ledger is not this actual input/physics step"):
				return false
			checked += 1
		previous = point
	print("ACCOUNTING REAL: label=%s hz=%d checked=%d first=%s" % [label, Engine.physics_ticks_per_second, checked, JSON.stringify(result.samples[0].trace)])
	if not _assert_true(checked > 0 and point_distance_from_rect(start, rect) <= PlayerScript.BODY_RADIUS + GEOMETRY_EPS, "real trace needs a non-vacuous contact fixture"):
		return false
	if second_body and not _assert_true(circles[1].closest <= PlayerScript.BODY_RADIUS + circles[1].radius + 0.5, "second-body case never approached real contact"):
		return false
	await _dispose(fixture)
	return true

func _circle_geometry(enemy: Node, start: Vector2) -> Dictionary:
	for child in enemy.get_children():
		if child is CollisionShape2D and child.shape is CircleShape2D:
			_assert_true(not child.disabled and child.global_scale.is_equal_approx(Vector2.ONE) and not enemy.is_physics_processing(), "geometry oracle needs an enabled stationary unscaled circle")
			var radius: float = child.shape.radius
			var gap := start.distance_to(child.global_position)
			return {"position": child.global_position, "radius": radius, "closest": gap,
				"minimum_gap": minf(gap, radius + PlayerScript.BODY_RADIUS)}
	_assert_true(false, "enemy fixture has no real circle shape")
	return {}

func _check_accepted_geometry(trace: Dictionary, radius: float, rect: Rect2, circles: Array, label: String) -> bool:
	var from: Vector2 = trace.start
	var motions: Array[Vector2] = [trace.recovery_accepted]
	for record in trace.input_steps:
		motions.append(record.accepted)
	for motion in motions:
		var to := from + motion
		if not _assert_true(_segment_rect_gap(from, to, rect) >= radius - GEOMETRY_EPS, label + " accepted R/U segment crosses terrain before its safe endpoint"):
			return false
		for circle: Dictionary in circles:
			var gap := _segment_point_gap(from, to, circle.position)
			if not _assert_true(gap >= circle.minimum_gap - GEOMETRY_EPS, label + " accepted R/U segment deepens an old overlap or enters a new body"):
				return false
			circle.closest = minf(circle.closest, gap)
			# Once any overlap has reduced, later segments cannot regain that depth.
			circle.minimum_gap = maxf(circle.minimum_gap, minf(to.distance_to(circle.position), radius + circle.radius))
		from = to
	return true

func _segment_point_gap(from: Vector2, to: Vector2, point: Vector2) -> float:
	var delta := to - from
	var along := 0.0 if delta.length_squared() == 0.0 else clampf((point - from).dot(delta) / delta.length_squared(), 0.0, 1.0)
	return point.distance_to(from + delta * along)

func _segment_rect_gap(from: Vector2, to: Vector2, rect: Rect2) -> float:
	var gap := minf(point_distance_from_rect(from, rect), point_distance_from_rect(to, rect))
	var corners := [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]
	for index in range(4):
		var edge_start: Vector2 = corners[index]
		var edge_end: Vector2 = corners[(index + 1) % 4]
		var delta := to - from
		var edge := edge_end - edge_start
		var cross := delta.cross(edge)
		if not is_zero_approx(cross):
			var t := (edge_start - from).cross(edge) / cross
			var u := (edge_start - from).cross(delta) / cross
			if t >= 0.0 and t <= 1.0 and u >= 0.0 and u <= 1.0:
				return 0.0
		gap = minf(gap, _segment_point_gap(from, to, edge_start))
		gap = minf(gap, minf(_segment_point_gap(edge_start, edge_end, from), _segment_point_gap(edge_start, edge_end, to)))
	return gap

func point_distance_from_rect(point: Vector2, rect: Rect2) -> float:
	return point.distance_to(point.clamp(rect.position, rect.end))
