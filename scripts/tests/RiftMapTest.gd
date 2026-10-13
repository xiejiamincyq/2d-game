extends SceneTree
var checks := 0
var failures := 0
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error("TEST FAIL: RiftMapTest "+label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var path := "res://scenes/world/rift_observatory.tscn"
	check(ResourceLoader.exists(path),"editable sixth observatory map missing")
	if failures: quit(1); return
	var map = load(path).instantiate(); map.map_seed = 521; root.add_child(map); await process_frame
	check(map.y_sort_enabled and map.layout.y_sort_enabled,"native sorting missing")
	check(map.floor_view.z_index==-100 and map.floor_view.world_bounds==map.layout.world_bounds,"floor bounds differ")
	check(map.floor_view.island_profiles==map.layout.get_islands() and map.floor_view.bypass_routes==map.layout.get_bypass_routes(),"painted paths differ from collision geometry")
	check(map.floor_view is Node2D and not map.floor_view is Sprite2D,"bitmap map fallback")
	check(map.layout.is_position_walkable(Vector2.ZERO,16.9) and map.layout.is_position_walkable(map.layout.BOSS_CENTER,56),"spawn/boss buffer blocked")
	for solid in map.layout.get_children():
		check(solid.prop_art is Node2D and not solid.prop_art is Sprite2D and solid.z_index==0,"foreign artwork or sorting semantics")
		solid.update_player_occlusion(solid.to_global(Vector2(0,-solid.footprint.y)),true,1)
		check(solid.modulate.a==1 and solid.prop_art.modulate.a<1,"base fades or upper blocks player")
		solid.update_player_occlusion(Vector2(9000,9000),true,1)
		check(solid.prop_art.modulate.a==1,"opacity not restored")
	var before := str(map.layout.get_obstacle_descriptors())
	map.generate_map(20261011)
	check(map.map_seed==20261011 and str(map.layout.get_obstacle_descriptors())!=before,"regeneration keeps old layout")
	check(map.floor_view.island_profiles==map.layout.get_islands() and map.floor_view.bypass_routes==map.layout.get_bypass_routes(),"regeneration keeps old decoration")
	check(map.layout.get_child_count()==16 and map.layout.get_obstacle_descriptors().size()==16,"regeneration duplicates physical modules")
	check(not map.is_in_group(&"enemies") and map.find_children("*Health*","",true,false).is_empty(),"map pretends dormant mechanism/Boss is complete")
	map.free(); await process_frame
	if not failures: print("TEST PASS: RiftMapTest %d"%checks)
	quit(1 if failures else 0)
