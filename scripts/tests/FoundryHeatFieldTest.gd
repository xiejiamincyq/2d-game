extends SceneTree
var checks := 0
var failures := 0
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error("TEST FAIL: FoundryHeatFieldTest "+label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var path := "res://scripts/world/FoundryHeatField.gd"
	check(ResourceLoader.exists(path),"heat placement controller missing")
	if failures: quit(1); return
	var source = load(path)
	check(source!=null and source.can_instantiate(),"field parse")
	if failures: quit(1); return
	var layout = load("res://scripts/world/FoundryArenaLayout.gd").new()
	root.add_child(layout)
	var field = source.new(); root.add_child(field)
	var fingerprints := {}
	for seed_value in [0,1,2,3,7,13,29,97,123,521,20261011,-1]:
		layout.generate_map(seed_value); field.configure(layout,seed_value)
		var sites: Array[Vector2] = field.get_sites()
		check(sites.size()==6 and field.get_child_count()==6,"six safe vent sites")
		fingerprints[str(sites)] = true
		for at in sites:
			check(layout.is_position_walkable(at,62),"terrain or bounds conflicts full hazard")
			check(not layout.SPAWN_BUFFER.grow(59).has_point(at),"spawn buffer heat")
			check(not layout.BOSS_BUFFER.grow(59).has_point(at),"Boss entrance buffer heat")
			check(absf(at.x)>160+59,"continuous central safe corridor")
			check(layout.is_reachable(Vector2.ZERO,at,13),"isolated vent site")
			for other in sites:
				check(at==other or at.distance_to(other)>=170,"hazards merged into large trap")
		for vent in field.get_children():
			check(not vent.enabled and vent.state==vent.State.INACTIVE,"map disabled by default")
			check(vent.initial_delay>=1.5,"initial warning stagger has safe cooldown")
		# All vent disks active: a body-sized straight safe spine remains traversable.
		for y in range(-800,801,40):
			var point := Vector2(0,y)
			check(layout.is_position_walkable(point,13),"solid closes safe spine")
			for site in sites: check(point.distance_to(site)>59,"heat closes safe spine")
		field.configure(layout,seed_value)
		check(field.get_sites()==sites and field.get_child_count()==6,"seed stable, regeneration frees old hazards")
		sites[0] = Vector2.ZERO
		check(field.get_sites()[0]!=Vector2.ZERO,"exported sites mutate live controller")
		await process_frame
	check(fingerprints.size()>=10,"seed does not change vent positions")
	field.configure(layout,521,null,16)
	check(field.get_sites().size()==16 and field.get_child_count()==16,"later risk encounter can use sixteen reserved sites")
	field.clear()
	check(field.get_child_count()==0 and field.get_sites().is_empty() and not field.active,"clear owns and cancels all vents")
	field.free(); layout.free()
	var map = load("res://scenes/world/ember_foundry.tscn").instantiate()
	root.add_child(map)
	check(map.has_node("HeatField"),"actual map assembles heat field")
	if map.has_node("HeatField"):
		var owned = map.get_node("HeatField")
		check(owned.get_child_count()==6 and not owned.active,"actual map hazard off until encounter")
		map.generate_map(97)
		check(owned.get_child_count()==6 and not owned.active,"map regenerate cancels danger")
	map.free(); await process_frame
	if not failures: print("TEST PASS: FoundryHeatFieldTest %d"%checks)
	quit(1 if failures else 0)
