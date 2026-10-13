extends RefCounted
## Diagnostic statistics: retain slow frames and reject absent/invalid windows.

static func qualify_report(inherited: Dictionary, before: Dictionary, after: Dictionary) -> Dictionary:
	var qualified := inherited.duplicate(true)
	qualified.erase("native_scope")
	qualified["native_player"] = {"sampled":false,"reason":"performance-only run; no native pose or screenshot observations"}
	qualified["health_events"] = {"sampled":false,"reason":"performance-only run; no health-event observer"}
	var preserved := not before.is_empty() and before.size() == after.size()
	for path in before:
		preserved = preserved and after.has(path) and after.get(path) == before[path]
	qualified["user_save_hashes_before"] = before.duplicate()
	qualified["user_save_hashes_after"] = after.duplicate()
	qualified["user_saves_preserved"] = preserved
	return qualified

static func distribution(values: PackedFloat64Array) -> Dictionary:
	if values.is_empty(): return {}
	var sorted := values.duplicate()
	var total := 0.0
	for value in sorted:
		if not is_finite(value) or value < 0.0: return {}
		total += value
	sorted.sort()
	return {"count":sorted.size(),"mean":total / sorted.size(),
		"p50":sorted[int(ceil(sorted.size() * 0.50)) - 1],
		"p95":sorted[int(ceil(sorted.size() * 0.95)) - 1],
		"p99":sorted[int(ceil(sorted.size() * 0.99)) - 1],"maximum":sorted[-1]}

static func summarize(rows: Array[Dictionary]) -> Dictionary:
	if rows.is_empty(): return {}
	var intervals := PackedFloat64Array()
	var process := PackedFloat64Array()
	var physics := PackedFloat64Array()
	var enemy_peak := 0
	var projectile_peak := 0
	var draw_peak := 0
	var total_ms := 0.0
	var over_60 := 0
	var over_30 := 0
	for row in rows:
		var interval: float = row.interval_ms
		intervals.append(interval)
		process.append(row.process_ms)
		physics.append(row.physics_ms)
		total_ms += interval
		over_60 += int(interval > 16.667)
		over_30 += int(interval > 33.333)
		enemy_peak = maxi(enemy_peak, row.enemies)
		projectile_peak = maxi(projectile_peak, row.projectiles)
		draw_peak = maxi(draw_peak, row.draw_calls)
	var times := distribution(intervals)
	var process_times := distribution(process)
	var physics_times := distribution(physics)
	if times.is_empty() or process_times.is_empty() or physics_times.is_empty() or total_ms <= 0.0: return {}
	return {"frames":rows.size(),"wall_seconds":total_ms / 1000.0,
		"effective_callback_fps":rows.size() * 1000.0 / total_ms,
		"interval_ms":times,"process_ms":process_times,"physics_ms":physics_times,
		"enemy_peak":enemy_peak,"projectile_peak":projectile_peak,"draw_call_peak":draw_peak,
		"intervals_over_16_667_ms":over_60,"intervals_over_33_333_ms":over_30}
