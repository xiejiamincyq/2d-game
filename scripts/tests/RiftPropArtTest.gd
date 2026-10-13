extends SceneTree
var checks := 0
var failures := 0
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error("TEST FAIL: RiftPropArtTest "+label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	check(ResourceLoader.exists("res://scripts/world/RiftPropArt.gd"),"original sixth equipment artwork missing")
	check(ResourceLoader.exists("res://scripts/world/RiftFloor.gd"),"original sixth ground artwork missing")
	if failures: quit(1); return
	var layout = load("res://scripts/world/RiftArenaLayout.gd").new(); root.add_child(layout)
	layout.generate_map(20261011)
	var floor_art = load("res://scripts/world/RiftFloor.gd").new(); root.add_child(floor_art)
	var islands: Array[Dictionary] = layout.get_islands(); var routes: Array[Dictionary] = layout.get_bypass_routes()
	floor_art.configure(layout.BOUNDS,islands,routes)
	check(floor_art.world_bounds==layout.BOUNDS and floor_art.island_profiles.size()==4 and floor_art.bypass_routes.size()==8,"floor omits actual geometry")
	islands[0].rect = Rect2(); routes[0].rect = Rect2()
	check(floor_art.island_profiles[0].rect.size!=Vector2.ZERO and floor_art.bypass_routes[0].rect.size!=Vector2.ZERO,"floor keeps mutable caller collections")
	for solid in layout.get_children():
		var art = solid.get_node_or_null("PropArt")
		check(art!=null,"physical module has no original prop layer")
		if art==null: continue
		check(art.get_script().resource_path=="res://scripts/world/RiftPropArt.gd" and art.kind==solid.kind and art.footprint==solid.footprint,"foreign or mismatched equipment art")
		var bounds: Rect2 = art.get_visual_bounds()
		check(bounds.encloses(Rect2(Vector2(-solid.footprint.x/2,-solid.footprint.y),solid.footprint)) and bounds.size.y>=solid.footprint.y+68,"art clips elevated silhouette")
		check(solid.occlusion_rect==bounds,"occlusion and visual bounds differ")
		var shape: CollisionShape2D = solid.get_node("CollisionShape2D")
		var size_before: Vector2 = shape.shape.size; var position_before: Vector2 = shape.position
		var at: Vector2 = solid.to_global(Vector2(0,-solid.footprint.y-16))
		solid.update_player_occlusion(at,true,1.0)
		check(is_equal_approx(art.modulate.a,0.32) and is_equal_approx(solid.modulate.a,1.0),"occlusion fades the entire collision base")
		check(shape.shape.size==size_before and shape.position==position_before and not shape.disabled,"occlusion changes physical terrain")
		solid.update_player_occlusion(at,false,1.0)
		check(is_equal_approx(art.modulate.a,1.0),"lost target leaves prop faded")
		solid.update_player_occlusion(solid.to_global(Vector2(0,48)),true,1.0)
		check(is_equal_approx(art.modulate.a,1.0),"player below platform incorrectly fades art")
	layout.free(); floor_art.free(); await process_frame
	if not failures: print("TEST PASS: RiftPropArtTest %d"%checks)
	quit(1 if failures else 0)
