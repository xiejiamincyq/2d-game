extends SceneTree
## Second chapter geometry/real colliders, not chapter readiness or a victory.
var checks := 0
var failures := 0
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("TEST FAIL: FoundryMapTest "+label)
func _initialize() -> void:
	var path := "res://scripts/world/FoundryArenaLayout.gd"
	check(ResourceLoader.exists(path),"distinct foundry layout is missing")
	if failures: quit(1); return
	var source = load(path)
	check(source!=null and source.can_instantiate(),"foundry layout does not parse")
	if failures: quit(1); return
	var layout = source.new()
	root.add_child(layout)
	var fingerprints := {}
	var densities := {}
	for seed_value in [0,1,2,3,7,13,29,97,123,521,20261011,-1]:
		layout.generate_map(seed_value)
		var entries: Array[Dictionary] = layout.get_obstacle_descriptors()
		var fingerprint := str(entries)
		fingerprints[fingerprint] = true
		densities[entries.size()] = true
		check(entries.size()>=26 and entries.size()<=28,"foundry obstacle count outside denser design")
		check(layout.PROFILE_ID==&"furnace_lanes" and layout.world_bounds==layout.BOUNDS,"chapter profile mismatch")
		check(layout.is_position_walkable(Vector2.ZERO,56) and layout.is_position_walkable(layout.BOSS_CENTER,56),"spawn/Boss buffer blocked")
		for radius in [13.0,14.0,16.9,24.0,56.0]:
			for target in [layout.BOSS_CENTER,Vector2(-1360,0),Vector2(1360,0),Vector2(0,800),Vector2(-760,700),Vector2(760,-700)]:
				check(layout.is_reachable(Vector2.ZERO,target,radius),"seed %s radius %s disconnected route %s"%[seed_value,radius,target])
		check(layout.get_child_count()==entries.size(),"descriptor/collider count mismatch after regeneration")
		var kinds := {}
		for i in entries.size():
			var entry := entries[i]
			var rect: Rect2 = entry.rect
			kinds[entry.kind] = true
			check(layout.world_bounds.grow(-72).encloses(rect),"obstacle escapes arena")
			check(not rect.intersects(layout.SPAWN_BUFFER) and not rect.intersects(layout.BOSS_BUFFER),"obstacle invades reserved buffer")
			var solid: StaticBody2D = layout.get_child(i)
			var collider: CollisionShape2D = solid.get_node("CollisionShape2D")
			check(collider.shape is RectangleShape2D and collider.shape.size==rect.size,"visible footprint/collider size differs")
			check(Rect2(solid.position+collider.position-rect.size/2,rect.size).is_equal_approx(rect),"physical footprint shifted from navigation")
			check(solid.collision_layer&1!=0 and solid.is_in_group(&"arena_obstacles"),"actual terrain collision contract absent")
			check(not layout.is_position_walkable(rect.get_center(),13),"navigation ignores solid")
			check(solid.get_node("Art") is Node2D and not solid.get_node("Art") is Sprite2D,"foundry is old raster recolor")
			solid.update_player_occlusion(solid.position-Vector2(0,rect.size.y),true,1)
			check(solid.modulate.a==1 and solid.art.modulate.a<1,"occlusion fades physical footprint or never yields")
			solid.update_player_occlusion(Vector2(9000,9000),true,1)
			check(solid.art.modulate.a==1,"occluded decoration stays transparent")
			for other in entries.slice(i+1):
				check(not rect.grow(64).intersects(other.rect),"adjacent obstacle clearance below 64px")
		check(kinds.has(&"furnace") and kinds.has(&"pipe_bank") and kinds.has(&"slag_stack"),"three original foundry scenery roles missing")
		check(entries.filter(func(entry): return entry.kind==&"pipe_bank").size()==8,"broken pipe lane bands missing")
		layout.generate_map(seed_value)
		check(str(layout.get_obstacle_descriptors())==fingerprint,"same seed changes layout")
		var exported: Array[Dictionary] = layout.get_obstacle_descriptors()
		exported[0].rect = Rect2()
		check(str(layout.get_obstacle_descriptors())==fingerprint,"export mutates live terrain")
		await process_frame
	check(fingerprints.size()==12,"seeds do not change structural foundry layout")
	check(densities.size()>=3,"seed only jitters one fixed-density workstation template")
	layout.free()
	await process_frame
	if not failures: print("TEST PASS: FoundryMapTest %d"%checks)
	quit(1 if failures else 0)
