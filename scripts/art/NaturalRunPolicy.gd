extends RefCounted

func nonzero_aim(position: Vector2, suggested: Vector2) -> Vector2:
	return position + Vector2(500, 0) if suggested.distance_squared_to(position) <= 0.000001 else suggested

# Input-only diagnostic pilot. No actor state, random stream or clock writes.
func choose_direction(position: Vector2, goal: Vector2, threats: Array, walkable: Callable) -> Vector2:
	if goal == Vector2.ZERO and threats.is_empty():
		return Vector2.ZERO
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
		for threat: Vector2 in threats:
			var offset := position - threat
			var distance := offset.length()
			if distance < 200.0:
				score += direction.dot(offset.normalized()) * (1.0 - distance / 200.0) * 8.0
		if score > best_score:
			best_score = score
			best = direction
	return best
