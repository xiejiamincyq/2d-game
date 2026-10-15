extends SceneTree
var checks := 0
var failures := 0
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("TEST FAIL: SaltMapTest "+label)
func _initialize() -> void:
	var path := "res://scenes/world/salt_waterway.tscn"
	check(ResourceLoader.exists(path),"editable salt scene missing")
	if failures: quit(1); return
	var scene = load(path)
	var map = scene.instantiate()
	map.map_seed = 521
	root.add_child(map)
	await process_frame
	check(map.y_sort_enabled and map.layout.y_sort_enabled,"map sorting is not native")
	check(map.floor_view.z_index==-100,"ground does not stay below actors")
	check(map.floor_view.bounds==map.layout.world_bounds,"floor/collision bounds differ")
	check(map.floor_view.descriptors==map.layout.get_obstacle_descriptors(),"floor uses another map")
	check(map.floor_view.causeways==map.layout.get_causeways(),"floor invents walkable bridges")
	check(map.floor_view is Node2D and not map.floor_view is Sprite2D,"third map is raster recolor")
	for solid in map.layout.get_children():
		check(solid.art is Node2D and not solid.art is Sprite2D,"native salt scenery missing")
		check(solid.z_index==(-90 if solid.obstacle_kind==&"reservoir" else 0),"low basin can sort over actor bodies")
		solid.update_player_occlusion(solid.position-Vector2(0,solid.obstacle_size.y),true,1)
		check(solid.modulate.a==1,"solid base fades")
		check(solid.art.modulate.a<1 if solid.obstacle_kind==&"sluice_wall" else solid.art.modulate.a==1,"wrong low water/high lock occlusion")
		solid.update_player_occlusion(Vector2(9000,9000),true,1)
		check(solid.art.modulate.a==1,"lock alpha does not recover")
	map.generate_map(20261011)
	check(map.floor_view.map_seed==20261011 and map.floor_view.causeways==map.layout.get_causeways(),"regeneration leaves stale floor")
	check(map.layout.get_child_count()==22,"regeneration duplicates or omits denser collision")
	map.free()
	await process_frame
	if not failures: print("TEST PASS: SaltMapTest %d"%checks)
	quit(1 if failures else 0)
