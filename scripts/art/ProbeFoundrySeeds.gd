extends SceneTree
## Bounded diagnosis only: actual candidates, without generating error/empty maps.
const Layout = preload("res://scripts/world/FoundryArenaLayout.gd")
const ROUTES = [Vector2(0,-660),Vector2(-1360,0),Vector2(1360,0),Vector2(0,800),Vector2(-760,700),Vector2(760,-700)]
func _initialize() -> void: call_deferred("_run")
func _reason(layout) -> String:
	if layout.obstacle_descriptors.size()<16: return "count_%d" % layout.obstacle_descriptors.size()
	for i in layout.obstacle_descriptors.size():
		var rect: Rect2 = layout.obstacle_descriptors[i].rect
		if not layout.world_bounds.grow(-72).encloses(rect): return "edge"
		if rect.intersects(Layout.SPAWN_BUFFER) or rect.intersects(Layout.BOSS_BUFFER): return "buffer"
		for other in layout.obstacle_descriptors.slice(i+1):
			if rect.grow(64).intersects(other.rect): return "spacing"
	for radius in [26.0,56.0]:
		for target in ROUTES:
			if not layout.is_reachable(Vector2.ZERO,target,radius): return "route_%s_%s" % [radius,target]
	return "accepted"
func _run() -> void:
	var layout = Layout.new()
	layout.world_bounds = Layout.BOUNDS
	layout.generator_version = 2
	for seed_value in range(1024):
		var reasons := {}
		var accepted := false
		for attempt in range(24):
			layout.obstacle_descriptors = layout._build_descriptors(seed_value+attempt*104729)
			if layout._layout_is_acceptable():
				accepted = true
				break
			var reason := _reason(layout)
			reasons[reason] = int(reasons.get(reason,0))+1
		if not accepted:
			print("FOUNDRY SEED REPRO: seed=%d attempts=24 reasons=%s" % [seed_value,JSON.stringify(reasons)])
			for target in ROUTES:
				var cell: Vector2 = layout._cell_to_world(layout._world_to_cell(target))
				for entry in layout.obstacle_descriptors:
					if Rect2(entry.rect).grow(26).has_point(cell): print("BLOCKED ROUTE CELL: target=%s cell=%s kind=%s rect=%s" % [target,cell,entry.kind,entry.rect])
			layout.free()
			quit(0)
			return
	print("FOUNDRY SEED PROBE: no exhausted seed in bounded range 0..1023")
	layout.free()
	quit(1)
