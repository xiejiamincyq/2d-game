extends SceneTree
## Sixth region uses connected stair-shaped equipment, not fourth-region rooms.
var checks := 0
var failures := 0
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error("TEST FAIL: RiftLayoutTest "+label)
func _initialize() -> void: call_deferred("run")
func path_clear(layout,points: Array,radius: float,label: String) -> void:
	for i in range(points.size()-1):
		var start: Vector2 = points[i]; var finish: Vector2 = points[i+1]
		var steps := maxi(1,ceili(start.distance_to(finish)/16.0))
		for step in range(steps+1):
			check(layout.is_position_walkable(start.lerp(finish,float(step)/steps),radius),label)
func run() -> void:
	var path := "res://scripts/world/RiftArenaLayout.gd"
	check(ResourceLoader.exists(path),"sixth-region stepped equipment collision layout missing")
	if failures: quit(1); return
	var layout = load(path).new(); root.add_child(layout)
	var fingerprints := {}; var variants := {}
	for seed_value in [0,1,2,3,7,13,29,97,123,521,20261011,-1]:
		layout.generate_map(seed_value)
		var entries: Array[Dictionary] = layout.get_obstacle_descriptors()
		var islands: Array[Dictionary] = layout.get_islands()
		var routes: Array[Dictionary] = layout.get_bypass_routes()
		var sites: Array[Vector2] = layout.get_fault_sites()
		var fingerprint := str(entries); fingerprints[fingerprint] = true; variants[str(routes)] = true
		check(layout.PROFILE_ID==&"rift_stepped_equipment" and layout.world_bounds==layout.BOUNDS,"wrong profile")
		check(entries.size()==16 and islands.size()==4 and routes.size()==8 and sites.size()==4,"four connected stepped islands/two bypasses each/four safe sites missing")
		check(layout.get_child_count()==entries.size(),"physical obstacle count differs")
		for radius in [16.9,14.0,16.0,24.0,56.0]:
			for target in [layout.BOSS_CENTER,Vector2(-1472,0),Vector2(1472,0),Vector2(0,896),Vector2(-1472,896),Vector2(1472,-896)]:
				check(layout.is_reachable(Vector2.ZERO,target,radius),"seed %s radius %s cannot approach %s"%[seed_value,radius,target])
			for site in sites:
				check(layout.is_position_walkable(site,radius) and layout.is_reachable(Vector2.ZERO,site,radius),"fault site inaccessible")
		for site in sites: check(layout.is_position_walkable(site,96),"fault clock clearance lost")
		for i in entries.size():
			var entry := entries[i]; var rect: Rect2 = entry.rect
			check(entry.kind in [&"scope_bench",&"relay_plinth"] and entry.island in range(4),"foreign descriptor")
			check(rect.size.x>=156 and rect.size.y>=108,"invalid solid module size")
			check(layout.world_bounds.grow(-72).encloses(rect) and not rect.intersects(layout.SPAWN_BUFFER) and not rect.intersects(layout.BOSS_BUFFER),"module covers reserved zone")
			check(not layout.is_position_walkable(rect.get_center(),16.9),"solid footprint silently walkable")
			var solid: StaticBody2D = layout.get_child(i)
			var collider: CollisionShape2D = solid.get_node("CollisionShape2D")
			check(collider.shape is RectangleShape2D and collider.shape.size==rect.size,"physical footprint dimensions differ")
			check(Rect2(solid.position+collider.position-rect.size/2,rect.size).is_equal_approx(rect),"physical/navigation offset")
			check(solid.collision_layer&3==3 and solid.is_in_group(&"arena_obstacles"),"terrain query membership lost")
			for other in entries.slice(i+1):
				if entry.island!=other.island: check(not rect.grow(44).intersects(other.rect),"different islands merge or narrow corridor")
		for island in islands:
			var modules := entries.filter(func(e): return e.island==island.id)
			check(modules.size()==4,"equipment island is decorative or hollow room")
			for i in range(3): check(modules[i].rect.intersects(modules[i+1].rect),"adjacent stair modules disconnected")
			check(absf(modules[0].rect.get_center().y-modules[3].rect.get_center().y)>=160,"not a stepped island")
			check(routes.filter(func(r): return r.island==island.id).size()==2,"island lacks top/bottom bypass")
			var blocked := false
			for i in 65:
				if not layout.is_position_walkable(island.left.lerp(island.right,float(i)/64),16.9): blocked = true
			check(blocked,"equipment does not interrupt direct movement")
		for route in routes:
			check(route.rect.size.y>=224 and layout.world_bounds.encloses(route.rect),"bypass below clearance or outside world")
			for entry in entries: check(not route.rect.intersects(entry.rect),"published bypass has solid module")
			var island := islands[route.island]
			var points: Array = [island.left,Vector2(island.left.x,route.rect.get_center().y),Vector2(island.right.x,route.rect.get_center().y),island.right]
			path_clear(layout,points,56,"large body cannot traverse actual bypass")
			check(layout.is_reachable(island.left,island.right,56),"island probes unreachable")
			layout.obstacle_descriptors.append({"rect":route.rect,"kind":&"test_closed","island":route.island})
			var alternative: Dictionary = routes.filter(func(r): return r.island==route.island and r.side!=route.side)[0]
			var alternate_points: Array = [island.left,Vector2(island.left.x,alternative.rect.get_center().y),Vector2(island.right.x,alternative.rect.get_center().y),island.right]
			path_clear(layout,alternate_points,56,"blocking one bypass blocks the other")
			check(layout.is_reachable(island.left,island.right,56),"one closed bypass traps body")
			layout.obstacle_descriptors.pop_back()
		layout.generate_map(seed_value)
		check(str(layout.get_obstacle_descriptors())==fingerprint,"seed is not deterministic")
		entries[0].rect = Rect2(); islands[0].rect = Rect2(); routes[0].rect = Rect2(); sites[0] = Vector2.ZERO
		check(str(layout.get_obstacle_descriptors())==fingerprint and layout.get_islands()[0].rect.size!=Vector2.ZERO and layout.get_bypass_routes()[0].rect.size!=Vector2.ZERO and layout.get_fault_sites()[0]!=Vector2.ZERO,"caller mutates authoritative geometry")
		await process_frame
	check(fingerprints.size()==12 and variants.size()>=6,"seed only recolors fixed geometry")
	layout.free(); await process_frame
	if not failures: print("TEST PASS: RiftLayoutTest %d"%checks)
	quit(1 if failures else 0)
