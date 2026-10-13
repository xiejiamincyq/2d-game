extends SceneTree
var checks := 0
var failures := 0
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error("TEST FAIL: EchoMapTest "+label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var path := "res://scenes/world/echo_court.tscn"
	check(ResourceLoader.exists(path),"editable original fifth map missing")
	if failures: quit(1); return
	var map = load(path).instantiate(); map.map_seed = 521; root.add_child(map); await process_frame
	check(map.y_sort_enabled and map.layout.y_sort_enabled,"native sorting missing")
	check(map.floor_view.z_index==-100 and map.floor_view.bounds==map.layout.world_bounds,"floor differs from map bounds")
	check(map.floor_view.rings==map.layout.get_ring_profiles() and map.floor_view.gates==map.layout.get_gateways() and map.floor_view.echo_sites==map.layout.get_echo_sites(),"floor invents paths/sites")
	check(map.floor_view is Node2D and not map.floor_view is Sprite2D,"fifth map is a bitmap recolor")
	for solid in map.layout.get_children():
		check(solid.art is Node2D and not solid.art is Sprite2D,"original elevated pillar absent")
		check(solid.z_index==0,"sorting changes terrain semantics")
		solid.update_player_occlusion(solid.position-Vector2(0,solid.obstacle_size.y),true,1)
		check(solid.modulate.a==1 and solid.art.modulate.a<1,"base fades or upper fails to clear player")
		solid.update_player_occlusion(Vector2(9000,9000),true,1)
		check(solid.art.modulate.a==1,"pillar opacity does not restore")
	map.generate_map(20261011)
	check(map.floor_view.map_seed==20261011 and map.floor_view.gates==map.layout.get_gateways(),"old decoration after regeneration")
	check(map.layout.get_child_count()==map.layout.get_obstacle_descriptors().size(),"regeneration duplicates collision")
	check(not map.is_in_group(&"enemies") and map.find_children("*Health*","",true,false).is_empty(),"dormant site pretending to be active mechanism")
	map.free(); await process_frame
	if not failures: print("TEST PASS: EchoMapTest %d"%checks)
	quit(1 if failures else 0)
