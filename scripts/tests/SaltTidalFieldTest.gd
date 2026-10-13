extends SceneTree
## Placement, scene integration and safe side lanes; not a chapter clear.
const Player = preload("res://scripts/actors/Player.gd")
var checks := 0
var failures := 0
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error("TEST FAIL: SaltTidalFieldTest "+label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var path := "res://scripts/world/SaltTidalField.gd"
	check(ResourceLoader.exists(path),"fixed tidal placement missing")
	if failures: quit(1); return
	var source = load(path)
	check(source!=null and source.can_instantiate(),"field does not parse")
	if failures: quit(1); return
	var layout = load("res://scripts/world/SaltArenaLayout.gd").new()
	root.add_child(layout)
	var field = source.new(); root.add_child(field)
	var fingerprints := {}
	for seed_value in [0,1,2,3,7,13,29,97,123,521,20261011,-1]:
		layout.generate_map(seed_value); field.configure(layout,seed_value)
		var sites: Array[Rect2] = field.get_sites()
		fingerprints[str(sites)] = true
		check(sites.size()==4 and field.get_child_count()==4,"four preplaced tide channels absent")
		for i in sites.size():
			var area := sites[i]
			check(minf(area.size.x,area.size.y)==60 and maxf(area.size.x,area.size.y)>=120,"strip dimensions not narrow")
			check(layout.get_causeways().any(func(gap): return gap.encloses(area)),"danger outside actual dry passage")
			check(not area.grow(13).intersects(layout.SPAWN_BUFFER) and not area.grow(13).intersects(layout.BOSS_BUFFER),"reserved buffers endangered")
			for entry in layout.get_obstacle_descriptors(): check(not area.intersects(entry.rect),"tide intersects blocked water")
			var band = field.get_child(i)
			check(band.global_position==layout.to_global(area.get_center()),"field/world coordinates diverge")
			check(not band.enabled and band.state==band.State.INACTIVE and band.initial_delay>=1.8,"generation starts active")
			var long_axis := Vector2.DOWN if area.size.x<area.size.y else Vector2.RIGHT
			var side_axis := long_axis.rotated(PI/2)
			for side in [-1,1]:
				for fraction in [-0.4,0.0,0.4]:
					var point: Vector2 = area.get_center()+side_axis*side*64+long_axis*fraction*maxf(area.size.x,area.size.y)
					check(layout.is_position_walkable(point,13),"ordinary side escape obstructed")
					check(not area.grow(13).has_point(point),"escape still overlaps danger")
		for y in range(-832,833,32):
			var point := Vector2(0,y)
			check(layout.is_position_walkable(point,13),"central safe route blocked")
			for area in sites: check(not area.grow(13).has_point(point),"all tides close central route")
		field.configure(layout,seed_value)
		check(field.get_sites()==sites and field.get_child_count()==4,"regeneration unstable or accumulates hazards")
		sites[0] = Rect2()
		check(field.get_sites()[0].size!=Vector2.ZERO,"external mutation changes live sites")
		await process_frame
	check(fingerprints.size()==12,"seed does not change tidal geometry")
	var player := Player.new(); root.add_child(player)
	await physics_frame; await process_frame
	field.bind_player(player); field.set_active(true)
	check(field.active and field.get_children().filter(func(band): return band.enabled).size()==2,"normal encounter is not two tides")
	field.set_active(true,4)
	check(field.get_children().all(func(band): return band.enabled),"risk count does not activate four reserved tides")
	field.set_active(false)
	check(not field.active and field.get_children().all(func(band): return not band.enabled),"encounter cancellation leaves armed tide")
	field.clear()
	check(field.get_child_count()==0 and field.get_sites().is_empty(),"owned clear leaves hazards")
	field.free(); layout.free(); player.free(); await process_frame
	var map = load("res://scenes/world/salt_waterway.tscn").instantiate()
	root.add_child(map)
	check(map.has_node("TidalField"),"actual map does not assemble tides")
	if map.has_node("TidalField"):
		var owned = map.get_node("TidalField")
		check(owned.get_child_count()==4 and not owned.active,"actual map starts dangerous")
		map.generate_map(97)
		check(owned.get_child_count()==4 and not owned.active,"actual regeneration leaves old/active tides")
	map.free(); await process_frame
	if not failures: print("TEST PASS: SaltTidalFieldTest %d"%checks)
	quit(1 if failures else 0)
