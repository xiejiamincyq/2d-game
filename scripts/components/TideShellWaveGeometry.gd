extends RefCounted
## Exact first contact of a linearly moving circle with an expanding hollow rim.
## Caller owns walls, lifecycle, damage and physics clock; no scene mutation here.
static func hit_fraction(origin: Vector2,target_from: Vector2,target_to: Vector2,radius_from: float,radius_to: float,padding: float) -> float:
	if not origin.is_finite() or not target_from.is_finite() or not target_to.is_finite(): return -1
	if not is_finite(radius_from) or not is_finite(radius_to) or not is_finite(padding) or radius_from<0 or radius_to<radius_from or padding<0: return -1
	var offset := target_from-origin
	var motion := target_to-target_from
	var growth := radius_to-radius_from
	var times: Array[float] = [0.0,1.0]
	# Both moving boundaries matter: checking only end-radius fills the centre
	# and misses fast crossing targets. Quadratic roots partition valid intervals.
	for boundary in [radius_from+padding,radius_from-padding]:
		var a := motion.length_squared()-growth*growth
		var b: float = 2*(offset.dot(motion)-boundary*growth)
		var c: float = offset.length_squared()-boundary*boundary
		for time in _roots(a,b,c):
			if time>=-0.00000001 and time<=1.00000001:
				times.append(clampf(time,0,1))
	times.sort()
	for index in times.size():
		var time := times[index]
		if _inside(offset+motion*time,radius_from+growth*time,padding): return time
		if index+1<times.size():
			var middle := (time+times[index+1])*0.5
			if _inside(offset+motion*middle,radius_from+growth*middle,padding): return time
	return -1

static func _inside(offset: Vector2,radius: float,padding: float) -> bool:
	var distance_squared := offset.length_squared()
	var inner := maxf(0,radius-padding)
	var outer := radius+padding
	return distance_squared>=inner*inner-0.00001 and distance_squared<=outer*outer+0.00001

static func _roots(a: float,b: float,c: float) -> Array[float]:
	var magnitude := maxf(1,maxf(absf(a),maxf(absf(b),absf(c))))
	a /= magnitude
	b /= magnitude
	c /= magnitude
	if absf(a)<0.000000001:
		return [] if absf(b)<0.000000001 else [-c/b]
	var discriminant := b*b-4*a*c
	if discriminant< -0.000000001: return []
	var root := sqrt(maxf(0,discriminant))
	# Stable quadratic evaluation avoids losing the small root on fast sweeps.
	var q := -0.5*(b+root if b>=0 else b-root)
	if absf(q)<0.000000001: return [-b/(2*a)]
	return [q/a,c/q]
