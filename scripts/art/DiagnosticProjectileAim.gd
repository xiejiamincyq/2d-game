extends RefCounted
## Diagnostic normal-pointer aiming only. Never mutates projectiles or actors.
static func intercept(relative_position: Vector2, relative_velocity: Vector2, speed: float, maximum_time: float = 6.0) -> Dictionary:
	var fallback := {"solved": false, "time": 0.0, "direction": relative_position.normalized() if relative_position.is_finite() and relative_position.length_squared() > 0 else Vector2.RIGHT}
	if not relative_position.is_finite() or not relative_velocity.is_finite() or not is_finite(speed) or speed <= 0 or not is_finite(maximum_time) or maximum_time <= 0:
		return fallback
	var c := relative_position.length_squared()
	if c <= 0: return fallback
	var a := relative_velocity.length_squared() - speed * speed
	var b := 2.0 * relative_position.dot(relative_velocity)
	var time := INF
	if absf(a) <= 0.0000001 * maxf(relative_velocity.length_squared(), speed * speed):
		if b < 0: time = -c / b
	else:
		var discriminant := b * b - 4.0 * a * c
		if discriminant >= 0:
			# Stable quadratic roots avoid cancellation when one root is tiny.
			var q := -0.5 * (b + (1.0 if b >= 0 else -1.0) * sqrt(discriminant))
			if q != 0:
				for candidate in [q / a, c / q]:
					if candidate > 0: time = minf(time, candidate)
	if not is_finite(time) or time <= 0 or time > maximum_time: return fallback
	var direction := (relative_position + relative_velocity * time).normalized()
	if not direction.is_finite() or direction == Vector2.ZERO: return fallback
	return {"solved": true, "time": time, "direction": direction}
