extends RefCounted

const TerrainSweep = preload("res://scripts/world/TerrainSweep.gd")
const CHANGE_EPS := 0.001

# Only the enabled-body window after stealth uses this solver. Recovery is a
# read-only proposal, then one safe straight prefix; input owns a separate,
# monotonically diminishing slide remainder. No native move/rollback/retry.
static func move(player: CharacterBody2D, collision: CollisionShape2D, mask: int, requested: Vector2, bounds: Rect2) -> Dictionary:
	var start := player.global_position
	var parameters := PhysicsTestMotionParameters2D.new()
	parameters.from = player.global_transform
	parameters.motion = Vector2.ZERO
	parameters.margin = player.safe_margin
	parameters.recovery_as_collision = true
	var native_result := PhysicsTestMotionResult2D.new()
	var recovery_collision := PhysicsServer2D.body_test_motion(player.get_rid(), parameters, native_result)
	var recovery := native_result.get_travel() # A false query result does not gate travel.
	var initial_entities := _entity_state(collision, mask, player.safe_margin)
	var bounded_recovery := _straight_prefix(start, recovery, bounds)
	var recovery_check := TerrainSweep.constrain_restored_motion(collision, bounded_recovery, mask)
	var recovery_accepted: Vector2 = recovery_check.motion
	var slots := 0 if recovery.is_zero_approx() else 1
	var recovery_slots := slots
	var recovery_changed := recovery.distance_to(recovery_accepted) > CHANGE_EPS
	var changed := recovery_changed
	var saturated: bool = recovery_check.query_saturated or initial_entities.saturated
	var embedded: bool = recovery_check.embedded or _bounded(start, bounds).distance_to(start) > CHANGE_EPS
	if saturated or embedded:
		recovery_accepted = Vector2.ZERO
		recovery_changed = recovery.distance_to(recovery_accepted) > CHANGE_EPS
		changed = recovery_changed
	player.global_position += recovery_accepted
	var query_count: int = 1 + initial_entities.query_count + recovery_check.query_count
	var remainder := requested
	var input_steps: Array[Dictionary] = []
	var termination := "input_complete"
	while not remainder.is_zero_approx() and slots < player.max_slides and not saturated and not embedded:
		var before := remainder
		var bounded := _bounded(player.global_position + before, bounds) - player.global_position
		var world_discard := before - bounded
		# Axis-aligned world bounds discard the corresponding input velocity too.
		if absf(world_discard.x) > CHANGE_EPS:
			player.velocity.x = 0.0
		if absf(world_discard.y) > CHANGE_EPS:
			player.velocity.y = 0.0
		var check := TerrainSweep.constrain_restored_motion(collision, bounded, mask)
		query_count += check.query_count
		slots += 1
		saturated = saturated or check.query_saturated
		embedded = embedded or check.embedded
		var accepted: Vector2 = check.motion
		player.global_position += accepted
		remainder = bounded - accepted
		var effective_normals: Array[Vector2] = []
		for normal: Vector2 in check.normals:
			if remainder.dot(normal) < 0.0:
				effective_normals.append(normal)
				remainder = remainder.slide(normal)
				if player.velocity.dot(normal) < 0.0:
					player.velocity = player.velocity.slide(normal)
		changed = changed or world_discard.length() > CHANGE_EPS or bounded.distance_to(accepted) > CHANGE_EPS or saturated or embedded
		input_steps.append({"before": before, "bounded": bounded, "world_discard": world_discard,
			"accepted": accepted, "normals": effective_normals, "after": remainder,
			"changed_any": changed, "query_saturated": check.query_saturated, "embedded": check.embedded,
			"terrain": check.terrain, "bodies": check.bodies})
		if saturated or embedded:
			break
		if check.blocked and check.normals.is_empty():
			termination = "unresolved_contact"
			break
		var conflict := false
		for normal: Vector2 in check.normals:
			conflict = conflict or remainder.dot(normal) < -0.000001
		if conflict:
			termination = "conflicting_contacts"
			break
	var budget_exhausted := not remainder.is_zero_approx() and slots >= player.max_slides
	if saturated:
		termination = "query_saturated"
	elif embedded:
		termination = "embedded"
	elif budget_exhausted:
		termination = "budget_exhausted"
	var unresolved := not remainder.is_zero_approx() or saturated or embedded
	if unresolved:
		player.velocity = Vector2.ZERO
	changed = changed or remainder.length() > CHANGE_EPS or saturated or embedded
	var final_entities := _entity_state(collision, mask, player.safe_margin)
	query_count += final_entities.query_count
	saturated = saturated or final_entities.saturated
	changed = changed or saturated
	if saturated:
		termination = "query_saturated"
	# A normal U wall slide is not failed overlap recovery. Require a whole
	# enabled step clear of entities and exceptional solver outcomes, rather
	# than keeping the guard forever merely because input points into a wall.
	var pending: bool = recovery_changed or initial_entities.nearby or final_entities.nearby or saturated or embedded or unresolved
	return {"step": Engine.get_physics_frames(), "start": start, "accepted": player.global_position,
		"accepted_delta": player.global_position - start, "requested_motion": requested,
		"recovery_requested": recovery, "recovery_accepted": recovery_accepted,
		"recovery_query_collision": recovery_collision, "recovery_check": recovery_check,
		"recovery_changed": recovery_changed, "recovery_slots": recovery_slots,
		"input_steps": input_steps, "slots_used": slots, "query_count": query_count,
		"changed_any": changed, "query_saturated": saturated, "embedded": embedded,
		"budget_exhausted": budget_exhausted, "discarded_remaining": remainder,
		"termination_reason": termination, "initial_entities": initial_entities, "final_entities": final_entities,
		"entity_overlap": final_entities.overlap, "entity_proximity": final_entities.nearby,
		"pending": pending, "reason": "recovery_pending" if pending else "clean_enabled_step"}

static func _entity_state(collision: CollisionShape2D, mask: int, margin: float) -> Dictionary:
	var actual := TerrainSweep.entity_contact_state(collision, mask, 0.0)
	var nearby := TerrainSweep.entity_contact_state(collision, mask, margin)
	return {"overlap": actual.overlap, "nearby": nearby.overlap,
		"saturated": actual.saturated or nearby.saturated, "query_count": actual.query_count + nearby.query_count}

static func _bounded(position: Vector2, bounds: Rect2) -> Vector2:
	return position if bounds.size == Vector2.ZERO else position.clamp(bounds.position, bounds.end)

static func _straight_prefix(start: Vector2, motion: Vector2, bounds: Rect2) -> Vector2:
	var clamped_motion := _bounded(start + motion, bounds) - start
	var fraction := 1.0
	if not is_zero_approx(motion.x):
		fraction = minf(fraction, clampf(clamped_motion.x / motion.x, 0.0, 1.0))
	if not is_zero_approx(motion.y):
		fraction = minf(fraction, clampf(clamped_motion.y / motion.y, 0.0, 1.0))
	return motion * fraction
