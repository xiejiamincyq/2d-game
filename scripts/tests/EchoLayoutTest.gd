extends SceneTree
## Real pillar-ring geometry, not floor-only rings or a recolored shelf plan.
var checks := 0
var failures := 0
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error("TEST FAIL: EchoLayoutTest "+label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var path := "res://scripts/world/EchoArenaLayout.gd"
	check(ResourceLoader.exists(path),"fifth-region concentric collision layout missing")
	if failures: quit(1); return
	var layout = load(path).new(); root.add_child(layout)
	var fingerprints := {}; var gateway_variants := {}
	for seed_value in [0,1,2,3,7,13,29,97,123,521,20261011,-1]:
		layout.generate_map(seed_value)
		var entries: Array[Dictionary] = layout.get_obstacle_descriptors()
		var rings: Array[Dictionary] = layout.get_ring_profiles()
		var gates: Array[Dictionary] = layout.get_gateways()
		var sites: Array[Vector2] = layout.get_echo_sites()
		var fingerprint := str(entries); fingerprints[fingerprint] = true; gateway_variants[str(gates)] = true
		check(layout.PROFILE_ID==&"echo_concentric_columns" and layout.world_bounds==layout.BOUNDS,"wrong fifth-region profile")
		check(rings.size()==2 and gates.size()==4 and sites.size()==4 and entries.size()>=20,"two pillar rings/two gateways each/four dormant sites missing")
		check(layout.get_child_count()==entries.size(),"physical pillars differ from descriptors")
		for radius in [16.9,15.0,16.0,24.0,56.0]:
			for target in [layout.BOSS_CENTER,Vector2(-1504,0),Vector2(1504,0),Vector2(0,864),Vector2(-1504,864),Vector2(1504,-864)]:
				check(layout.is_reachable(Vector2.ZERO,target,radius),"seed %s radius %s loses route %s"%[seed_value,radius,target])
			for site in sites: check(layout.is_position_walkable(site,radius) and layout.is_reachable(Vector2.ZERO,site,radius),"future echo site cannot be approached")
		for ring_index in range(2):
			check(entries.filter(func(e): return e.ring==ring_index).size()>=8,"ring is decorative or sparse placeholder")
			check(gates.filter(func(g): return g.ring==ring_index).size()==2,"ring lacks independent exits")
		for i in entries.size():
			var entry := entries[i]; var rect: Rect2 = entry.rect
			check(entry.kind in [&"gravestone",&"bell_column"] and entry.ring in [0,1],"foreign/invalid pillar descriptor")
			check(rect.size.x>=64 and rect.size.y>=64,"invalid pillar footprint")
			check(layout.world_bounds.grow(-72).encloses(rect) and not rect.intersects(layout.SPAWN_BUFFER) and not rect.intersects(layout.BOSS_BUFFER),"pillar blocks reserved zones")
			check(not layout.is_position_walkable(rect.get_center(),16.9),"pillar silently walkable")
			var solid: StaticBody2D = layout.get_child(i)
			var collider: CollisionShape2D = solid.get_node("CollisionShape2D")
			check(collider.shape is RectangleShape2D and collider.shape.size==rect.size,"physical footprint dimensions differ")
			check(Rect2(solid.position+collider.position-rect.size/2,rect.size).is_equal_approx(rect),"physical/navigation pillar offset")
			check(solid.collision_layer&1!=0 and solid.is_in_group(&"arena_obstacles"),"pillar terrain contract missing")
			for other in entries.slice(i+1): check(not rect.grow(44).intersects(other.rect),"pillar spacing too narrow or overlapping")
		for gate in gates:
			var opening: Rect2 = gate.rect
			check(opening.size.x>=256 and opening.size.y>=256,"large-body exit below clearance")
			check(not opening.grow(56).has_point(gate.inside) and not opening.grow(56).has_point(gate.outside),"gateway probes overlap closed footprint: seed %s ring %s"%[seed_value,gate.ring])
			for entry in entries: check(not opening.intersects(entry.rect),"published gateway obstructed")
			check(layout.is_reachable(gate.inside,gate.outside,56),"gateway fails to connect inside/outside")
			layout.obstacle_descriptors.append({"rect":opening,"kind":&"test_closed","ring":gate.ring})
			check(layout.is_reachable(gate.inside,gate.outside,56),"one blocked gateway traps actor instead of alternate route")
			layout.obstacle_descriptors.pop_back()
		layout.generate_map(seed_value)
		check(str(layout.get_obstacle_descriptors())==fingerprint,"same seed not deterministic")
		entries[0].rect = Rect2(); rings[0].radii = Vector2.ZERO; gates[0].rect = Rect2(); sites[0] = Vector2.ZERO
		check(str(layout.get_obstacle_descriptors())==fingerprint and layout.get_ring_profiles()[0].radii!=Vector2.ZERO and layout.get_gateways()[0].rect.size!=Vector2.ZERO and layout.get_echo_sites()[0]!=Vector2.ZERO,"caller mutates authoritative map")
		await process_frame
	check(fingerprints.size()==12 and gateway_variants.size()>=6,"seed only recolors fixed map")
	layout.free(); await process_frame
	if not failures: print("TEST PASS: EchoLayoutTest %d"%checks)
	quit(1 if failures else 0)
