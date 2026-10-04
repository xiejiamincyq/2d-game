extends RefCounted

const OBSERVATION_STEPS := 90 # 1.5 seconds at the diagnostic's 60 Hz.
const ESCAPE_STEPS := 180
var rng := RandomNumberGenerator.new()
var observation_steps := 0
var observation_anchor := Vector2.ZERO
var observation_span := 0.0
var escape_remaining := 0
var escape_heading := Vector2.ZERO
var wander_heading := Vector2.ZERO
var decisions := 0
var escape_events := 0
var random_heading_changes := 0

func _init(seed_value: int = 20260908) -> void:
	rng.seed = seed_value # Private pilot stream; never touches gameplay RNG.

func _observe_motion(position: Vector2) -> void:
	if observation_steps == 0:
		observation_anchor = position
	observation_span = maxf(observation_span, position.distance_to(observation_anchor))
	observation_steps += 1
	if escape_remaining > 0:
		escape_remaining -= 1
	if observation_steps >= OBSERVATION_STEPS:
		if observation_span < 18.0 and escape_remaining == 0:
			escape_heading = Vector2.RIGHT.rotated(rng.randi_range(0, 7) * PI / 4.0)
			escape_remaining = ESCAPE_STEPS
			escape_events += 1
		observation_steps = 0
		observation_span = 0.0
	decisions += 1
	if decisions % 72 == 0:
		wander_heading = Vector2.RIGHT.rotated(rng.randf_range(-PI, PI))
		random_heading_changes += 1

func nonzero_aim(position: Vector2, suggested: Vector2) -> Vector2:
	return position + Vector2(500, 0) if suggested.distance_squared_to(position) <= 0.000001 else suggested

# Input-only diagnostic pilot. No actor state, gameplay random stream or clock writes.
func choose_direction(position: Vector2, goal: Vector2, threats: Array, walkable: Callable) -> Vector2:
	if goal == Vector2.ZERO and threats.is_empty():
		return Vector2.ZERO
	_observe_motion(position)
	var best := Vector2.ZERO
	var best_score := -INF
	for heading in range(8):
		var direction := Vector2.RIGHT.rotated(heading * PI / 4.0).snapped(Vector2(0.000001, 0.000001)).normalized()
		var clear := true
		for distance in [24.0, 48.0, 72.0]:
			clear = clear and bool(walkable.call(position + direction * distance))
		if not clear:
			continue
		var score := direction.dot(goal.normalized()) * 2.0
		# Mild seeded exploration during travel; sustained escape breaks local cycles.
		if escape_remaining > 0:
			score = direction.dot(goal.normalized()) * 0.4 + direction.dot(escape_heading) * 6.0
		else:
			score += direction.dot(wander_heading) * 0.9
		for threat: Vector2 in threats:
			var offset := position - threat
			var distance := offset.length()
			if distance < 200.0:
				score += direction.dot(offset.normalized()) * (1.0 - distance / 200.0) * 8.0
		if score > best_score:
			best_score = score
			best = direction
	return best
