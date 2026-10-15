extends SceneTree
## Actual shelf rooms have two exits and never become single-door traps.
var checks := 0
var failures := 0
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error("TEST FAIL: ArchiveLayoutTest "+label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var path := "res://scripts/world/ArchiveArenaLayout.gd"
	check(ResourceLoader.exists(path),"archive-specific shelf layout missing")
	if failures: quit(1); return
	var layout = load(path).new(); root.add_child(layout)
	var fingerprints := {}; var openings := {}
	for seed_value in [0,1,2,3,7,13,29,97,123,521,20261011,-1]:
		layout.generate_map(seed_value)
		var entries: Array[Dictionary] = layout.get_obstacle_descriptors()
		var rooms: Array[Rect2] = layout.get_chambers()
		var doors: Array[Rect2] = layout.get_doorways()
		var fingerprint := str(entries); fingerprints[fingerprint] = true; openings[str(doors)] = true
		check(layout.PROFILE_ID==&"archive_shelf_chambers" and layout.world_bounds==layout.BOUNDS,"wrong archive profile")
		check(rooms.size()==4 and doors.size()==8 and entries.size()==32,"four twin-exit rooms with two interior stacks each absent")
		check(layout.get_child_count()==entries.size(),"physical shelf count differs")
		for radius in [13.0,16.0,24.0,56.0]:
			for target in [layout.BOSS_CENTER,Vector2(-1504,0),Vector2(1504,0),Vector2(0,864),Vector2(-1504,864),Vector2(1504,-864)]:
				check(layout.is_reachable(Vector2.ZERO,target,radius),"seed %s radius %s disconnected %s"%[seed_value,radius,target])
			for room in rooms: check(layout.is_reachable(Vector2.ZERO,room.get_center(),radius),"archive side room cannot be entered")
		for i in entries.size():
			var entry := entries[i]; var rect: Rect2 = entry.rect
			check(entry.kind==&"bookcase" and entry.chamber in range(4),"not a shelf chamber descriptor")
			check(rect.size.x>=48 and rect.size.y>=48,"tiny or invalid shelf piece")
			check(layout.world_bounds.grow(-72).encloses(rect),"shelf outside arena margin")
			check(not rect.intersects(layout.SPAWN_BUFFER) and not rect.intersects(layout.BOSS_BUFFER),"reserved zones blocked")
			check(not layout.is_position_walkable(rect.get_center(),13),"shelf silently walkable")
			var solid: StaticBody2D = layout.get_child(i)
			var collider: CollisionShape2D = solid.get_node("CollisionShape2D")
			check(collider.shape is RectangleShape2D and collider.shape.size==rect.size,"collider dimensions differ")
			check(Rect2(solid.position+collider.position-rect.size/2,rect.size).is_equal_approx(rect),"collider/navigation misaligned")
			check(solid.collision_layer&1!=0 and solid.is_in_group(&"arena_obstacles"),"terrain layer/group absent")
			for other in entries.slice(i+1):
				check(not rect.intersects(other.rect),"shelf pieces overlap")
				if other.chamber!=entry.chamber: check(not rect.grow(128).intersects(other.rect),"cross-room route too narrow")
		for room_index in rooms.size():
			var room := rooms[room_index]
			for door: Rect2 in doors.slice(room_index*2,room_index*2+2):
				check(maxf(door.size.x,door.size.y)>=224,"door below large-body clearance")
				for entry in entries: check(not door.intersects(entry.rect),"visual door blocked by shelf")
				var axis := Vector2.RIGHT if door.size.x<door.size.y else Vector2.DOWN
				var outside := door.get_center()+axis*128
				if room.has_point(outside): outside = door.get_center()-axis*128
				check(layout.is_reachable(room.get_center(),outside,56),"door does not lead outside")
				layout.obstacle_descriptors.append({"rect":door,"kind":&"test_closed","chamber":room_index})
				check(layout.is_reachable(room.get_center(),outside,56),"single closed door traps large actor")
				layout.obstacle_descriptors.pop_back()
		var sites: Array[Vector2] = layout.get_spore_sites()
		check(sites.size()==4,"side-room spore sites absent")
		for i in sites.size(): check(rooms[i].has_point(sites[i]) and layout.is_position_walkable(sites[i],56) and layout.is_reachable(Vector2.ZERO,sites[i],56),"site cannot be approached")
		layout.generate_map(seed_value)
		check(str(layout.get_obstacle_descriptors())==fingerprint,"same seed not deterministic")
		entries[0].rect = Rect2(); rooms[0] = Rect2(); doors[0] = Rect2(); sites[0] = Vector2.ZERO
		check(str(layout.get_obstacle_descriptors())==fingerprint and layout.get_chambers()[0].size!=Vector2.ZERO and layout.get_doorways()[0].size!=Vector2.ZERO and layout.get_spore_sites()[0]!=Vector2.ZERO,"returned data mutates map")
		await process_frame
	check(fingerprints.size()==12 and openings.size()>=6,"seeds do not change shelves and doors")
	layout.free(); await process_frame
	if not failures: print("TEST PASS: ArchiveLayoutTest %d"%checks)
	quit(1 if failures else 0)
