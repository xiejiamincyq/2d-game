extends SceneTree
## Salt geometry is its own profile; this does not open chapter three.
var checks := 0
var failures := 0
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("TEST FAIL: SaltLayoutTest "+label)
func _initialize() -> void:
	var path := "res://scripts/world/SaltArenaLayout.gd"
	check(ResourceLoader.exists(path),"third region layout is missing")
	if failures: quit(1); return
	var source = load(path)
	check(source!=null and source.can_instantiate(),"salt profile cannot instantiate")
	if failures: quit(1); return
	var layout = source.new()
	root.add_child(layout)
	var fingerprints := {}
	var connections := {}
	for seed_value in [0,1,2,3,7,13,29,97,123,521,20261011,-1]:
		layout.generate_map(seed_value)
		var entries: Array[Dictionary] = layout.get_obstacle_descriptors()
		var fingerprint := str(entries)
		fingerprints[fingerprint] = true
		connections[str(layout.get_causeways())] = true
		check(layout.PROFILE_ID==&"salt_causeways" and layout.world_bounds==layout.BOUNDS,"wrong salt profile")
		check(entries.size()==10,"four split pools and two lock walls absent")
		check(layout.get_causeways().size()==4,"actual causeway gaps absent")
		for radius in [13.0,14.0,16.0,24.0,56.0]:
			for target in [layout.BOSS_CENTER,Vector2(-1472,0),Vector2(1472,0),Vector2(0,832),Vector2(-1504,896),Vector2(1504,-896)]:
				check(layout.is_reachable(Vector2.ZERO,target,radius),"seed %s radius %s disconnected %s"%[seed_value,radius,target])
			for passage in layout.get_causeways():
				check(layout.is_reachable(Vector2.ZERO,passage.get_center(),radius),"causeway cannot be entered at radius %s"%radius)
		check(layout.get_child_count()==entries.size(),"physical descriptor count differs")
		for i in entries.size():
			var entry := entries[i]
			var rect: Rect2 = entry.rect
			check(layout.world_bounds.grow(-72).encloses(rect),"water outside arena margin")
			check(not rect.intersects(layout.SPAWN_BUFFER) and not rect.intersects(layout.BOSS_BUFFER),"reserved zone blocked")
			var solid: StaticBody2D = layout.get_child(i)
			var collider: CollisionShape2D = solid.get_node("CollisionShape2D")
			check(collider.shape is RectangleShape2D and collider.shape.size==rect.size,"solid has wrong collider size")
			check(Rect2(solid.position+collider.position-rect.size/2,rect.size).is_equal_approx(rect),"solid shifted relative to navigation")
			check(solid.collision_layer&1!=0 and solid.is_in_group(&"arena_obstacles"),"terrain query layer/group missing")
			check(not layout.is_position_walkable(rect.get_center(),13),"water/lock is silently walkable")
			for other in entries.slice(i+1):
				check(not rect.grow(64).intersects(other.rect),"solid clearance under 64px")
		for passage in layout.get_causeways():
			check(minf(passage.size.x,passage.size.y)>=220,"boss causeway below clearance")
			for entry in entries: check(not passage.intersects(entry.rect),"seed %s visual causeway %s blocked by %s"%[seed_value,passage,entry.rect])
			var axis := Vector2.DOWN if passage.size.x<passage.size.y else Vector2.RIGHT
			var extent: float = maxf(passage.size.x,passage.size.y)/2+88
			var start: Vector2 = passage.get_center()-axis*extent
			var end: Vector2 = passage.get_center()+axis*extent
			check(layout.is_reachable(start,end,56),"dry passage endpoints disconnected")
			# Query-only failure injection: if this causeway closes, an outer loop
			# still links its two entrances. No runtime bridge is ever closed.
			layout.obstacle_descriptors.append({"rect":passage,"kind":&"test_closed"})
			check(layout.is_reachable(start,end,56),"only one route exists around reservoir")
			layout.obstacle_descriptors.pop_back()
		layout.generate_map(seed_value)
		check(str(layout.get_obstacle_descriptors())==fingerprint,"same seed differs")
		var exported: Array[Dictionary] = layout.get_obstacle_descriptors()
		if not exported.is_empty(): exported[0].rect = Rect2()
		check(str(layout.get_obstacle_descriptors())==fingerprint,"export mutates terrain")
		await process_frame
	check(fingerprints.size()==12,"seeds do not change layout")
	check(connections.size()>=6,"causeway openings never change")
	layout.free()
	await process_frame
	if not failures: print("TEST PASS: SaltLayoutTest %d"%checks)
	quit(1 if failures else 0)
