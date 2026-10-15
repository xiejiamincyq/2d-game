extends SceneTree
## Seed 30 exhausted all 24 retries and silently left chapter two without terrain.
## Actual generation must preserve full density, real colliders and both-size routes.
const Layout = preload("res://scripts/world/FoundryArenaLayout.gd")
const ROUTES = [Vector2(0,-660),Vector2(-1360,0),Vector2(1360,0),Vector2(0,800),Vector2(-760,700),Vector2(760,-700)]
const SEEDS = [-2147483648,-1,0,29,30,31,2147483647,4294967295]
var checks := 0
var failures := 0
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("TEST FAIL: FoundrySeedGenerationTest "+label)
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	for seed_value in SEEDS:
		var layout = Layout.new()
		root.add_child(layout)
		layout.generate_map(seed_value)
		var entries: Array[Dictionary] = layout.get_obstacle_descriptors()
		check(entries.size()>=26 and entries.size()<=28,"seed %s must produce 26..28 obstacles, got %s" % [seed_value,entries.size()])
		check(layout.get_child_count()>=26 and layout.get_child_count()==entries.size(),"seed %s must produce actual solid terrain, not an empty-map success" % seed_value)
		check(layout.world_bounds==Layout.BOUNDS and layout.map_seed==seed_value and layout.generator_version==2,"seed %s changed its map identity" % seed_value)
		# Empty maps are trivially connected. Never use that as positive route evidence.
		if entries.size()<26:
			layout.free()
			continue
		check(layout._layout_is_acceptable(),"seed %s returned rejected terrain" % seed_value)
		check(entries.filter(func(entry): return entry.kind==&"pipe_bank").size()==8,"seed %s loses eight pipe segments" % seed_value)
		check(entries.filter(func(entry): return entry.kind==&"furnace").size()==4,"seed %s loses four furnaces" % seed_value)
		check(entries.filter(func(entry): return entry.kind==&"slag_stack").size()>=14,"seed %s loses denser slag scenery role" % seed_value)
		for radius in [16.9,26.0,56.0]:
			for target in ROUTES:
				check(layout.is_reachable(Vector2.ZERO,target,radius),"seed %s radius %s cannot reach %s" % [seed_value,radius,target])
		for i in entries.size():
			var rect: Rect2 = entries[i].rect
			check(layout.world_bounds.grow(-72).encloses(rect),"seed %s terrain escapes 72px edge margin" % seed_value)
			check(not rect.intersects(Layout.SPAWN_BUFFER) and not rect.intersects(Layout.BOSS_BUFFER),"seed %s invades player/Boss buffers" % seed_value)
			for other in entries.slice(i+1):
				check(not rect.grow(64).intersects(other.rect),"seed %s loses 64px terrain separation" % seed_value)
			var solid: StaticBody2D = layout.get_child(i)
			var collider: CollisionShape2D = solid.get_node("CollisionShape2D")
			check(collider.shape is RectangleShape2D and collider.shape.size==rect.size,"seed %s collider differs from terrain size" % seed_value)
			check(Rect2(solid.position+collider.position-rect.size/2,rect.size).is_equal_approx(rect),"seed %s physical terrain differs from navigation footprint" % seed_value)
			check(solid.collision_layer&1!=0 and not collider.disabled,"seed %s terrain is not solid" % seed_value)
		var repeated = Layout.new()
		root.add_child(repeated)
		repeated.generate_map(seed_value)
		check(str(repeated.get_obstacle_descriptors())==str(entries),"seed %s is not reproducible" % seed_value)
		repeated.free()
		layout.free()
	await process_frame
	if not failures: print("TEST PASS: FoundrySeedGenerationTest %d" % checks)
	quit(1 if failures else 0)
