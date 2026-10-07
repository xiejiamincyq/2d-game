extends RefCounted

# Steering owns only local movement. Attacks, terrain and entity collision remain
# in Enemy; big bodies are obstacles, never leaders that set a small pack's pace.
const NEIGHBOR_RADIUS := 240.0
const SOCIAL_RADIUS := 140.0
const SEPARATION_PADDING := 48.0
const ALIGNMENT_WEIGHT := 0.30
const COHESION_WEIGHT := 0.08
const TURN_ACCELERATION := 6.0

var initialized := false
var bypass_id := 0
var bypass_side := 0.0

func steer(body: CharacterBody2D, desired: Vector2, neighbors: Array[Node], speed: float, radius: float, delta: float) -> Vector2:
	if desired == Vector2.ZERO or speed <= 0.0:
		initialized = false
		bypass_id = 0
		return Vector2.ZERO
	var forward := desired.normalized()
	var tangent := forward.orthogonal()
	var separation := Vector2.ZERO
	var alignment := Vector2.ZERO
	var center_offset := Vector2.ZERO
	var mean_speed := 0.0
	var weight_sum := 0.0
	var blocker: CharacterBody2D
	var closest_blocker := INF
	for candidate in neighbors:
		if not is_instance_valid(candidate) or candidate == body or candidate.is_queued_for_deletion():
			continue
		var other := candidate as CharacterBody2D
		if other == null or bool(other.get("death_resolved")):
			continue
		var other_radius_value: Variant = other.get("body_radius")
		if other_radius_value == null:
			continue
		var other_radius := float(other_radius_value)
		var offset := other.global_position - body.global_position
		var distance := offset.length()
		if distance > NEIGHBOR_RADIUS:
			continue
		if other_radius >= 24.0:
			var gap := radius + other_radius + 24.0
			var predicted := offset + other.velocity * 0.20
			var along := predicted.dot(forward)
			# Predict a slow collider in the forward corridor before contact.
			if along >= 0.0 and along < gap + speed * 0.75 and absf(predicted.dot(tangent)) < gap and other.velocity.dot(forward) < speed * 0.85:
				if along < closest_blocker:
					closest_blocker = along
					blocker = other
			continue
		var gap := radius + other_radius + SEPARATION_PADDING
		if distance < gap:
			var away := -offset.normalized() if distance > 0.001 else (Vector2.RIGHT if body.get_instance_id() < other.get_instance_id() else Vector2.LEFT)
			separation += away * (1.0 - distance / gap)
		if distance <= SOCIAL_RADIUS:
			var weight := 1.0 - distance / (SOCIAL_RADIUS + 1.0)
			alignment += other.velocity * weight
			center_offset += offset * weight
			mean_speed += other.velocity.length() * weight
			weight_sum += weight
	var pace := 1.0
	if weight_sum > 0.0:
		alignment /= weight_sum
		center_offset /= weight_sum
		# Neighbor pace has a bounded influence, not full-speed copying.
		pace = 0.80 + 0.20 * clampf(mean_speed / weight_sum / speed, 0.0, 1.0)
	var steering := forward + separation.limit_length(1.0) * 3.0
	steering += (alignment / maxf(speed, 1.0)).limit_length(1.0) * ALIGNMENT_WEIGHT
	steering += center_offset.limit_length(SOCIAL_RADIUS) / SOCIAL_RADIUS * COHESION_WEIGHT
	if blocker != null:
		if bypass_id != blocker.get_instance_id():
			bypass_id = blocker.get_instance_id()
			var lateral := (blocker.global_position - body.global_position).dot(tangent)
			if absf(lateral) > 1.0:
				bypass_side = -signf(lateral)
			elif absf(alignment.dot(tangent)) > 1.0:
				bypass_side = signf(alignment.dot(tangent))
			else:
				bypass_side = 1.0 if int(body.get("formation_slot_index")) % 2 == 0 else -1.0
		# Commit to one flank while the collider is in the corridor, rather than
		# alternating sides or braking behind it. Physical shapes stay enabled.
		steering = forward * 0.40 + tangent * bypass_side + separation.limit_length(1.0) * 0.40
	else:
		bypass_id = 0
	var target := steering.normalized() * speed * minf(desired.length(), 1.0) * pace
	var result := target
	if initialized:
		result = body.velocity.limit_length(speed).move_toward(target, speed * TURN_ACCELERATION * maxf(delta, 0.0))
	initialized = true
	return result.limit_length(speed)
