extends SceneTree
var checks := 0
var failures := 0
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error("TEST FAIL: ArchiveMapTest "+label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var path := "res://scenes/world/luminous_archive.tscn"
	check(ResourceLoader.exists(path),"editable archive map missing")
	if failures: quit(1); return
	var map = load(path).instantiate(); map.map_seed = 521; root.add_child(map); await process_frame
	check(map.y_sort_enabled and map.layout.y_sort_enabled,"native sorting absent")
	check(map.floor_view.z_index==-100 and map.floor_view.bounds==map.layout.world_bounds,"ground does not match actual map")
	check(map.floor_view.chambers==map.layout.get_chambers() and map.floor_view.doorways==map.layout.get_doorways(),"floor invents rooms/doors")
	check(map.floor_view is Node2D and not map.floor_view is Sprite2D,"map is a raster recolor")
	for solid in map.layout.get_children():
		check(solid.art is Node2D and not solid.art is Sprite2D,"original upper shelf art absent")
		check(solid.z_index==0,"shelf sorting changes collision footprint")
		solid.update_player_occlusion(solid.position-Vector2(0,solid.obstacle_size.y),true,1)
		check(solid.modulate.a==1 and solid.art.modulate.a<1,"opaque base/upper occlusion contract broken")
		solid.update_player_occlusion(Vector2(9000,9000),true,1)
		check(solid.art.modulate.a==1,"upper art alpha does not recover")
	map.generate_map(20261011)
	check(map.floor_view.map_seed==20261011 and map.floor_view.chambers==map.layout.get_chambers(),"stale room decoration")
	check(map.layout.get_child_count()==24,"regeneration doubles shelf colliders")
	map.free(); await process_frame
	if not failures: print("TEST PASS: ArchiveMapTest %d"%checks)
	quit(1 if failures else 0)
