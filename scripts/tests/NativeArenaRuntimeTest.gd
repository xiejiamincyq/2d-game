extends SceneTree
const Floor = preload("res://scripts/world/FloorGrid.gd")
const Obstacle = preload("res://scripts/world/ArenaObstacle.gd")
const Layout = preload("res://scripts/world/ArenaLayout.gd")
const Terrain = preload("res://scripts/world/TerrainSweep.gd")
var checks := 0
var failures := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("TEST FAIL: " + suite_name() + " " + message)
func _initialize() -> void:
	await process_frame
	var floor_script: Script = Floor
	var obstacle_script: Script = Obstacle
	check(not floor_script.get_script_constant_map().has("FLOOR_TEXTURE") and obstacle_script.get_script_constant_map().has("PropArt"), "actual legacy floor/obstacle still use pending raster")
	if failures: quit(1); return
	var host := Node2D.new()
	root.add_child(host)
	var floor_view := Floor.new()
	host.add_child(floor_view)
	await process_frame
	check(floor_view.z_index == -100 and floor_view.last_draw_command_count == 1 and floor_view.FLOOR_EXTENT == 4096, "native floor coverage/order/budget changed")
	_check_source_contract(floor_view)
	var layout := Layout.new()
	host.add_child(layout)
	layout.generate(Rect2(-1400,-900,2800,1800),20261012)
	layout.set_process(false)
	var descriptors: Array = layout.get_obstacle_descriptors()
	check(descriptors.size() >= 9 and descriptors.size() <= 13 and layout.GENERATOR_VERSION == 2, "random map/version/density changed")
	for source in Layout.OBSTACLE_TYPES:
		for size_scale in [0.5,1.0,2.0]:
			var size: Vector2 = source.size * size_scale
			var rect := Rect2(Vector2(40,60),size)
			var actual := Obstacle.new()
			actual.setup(rect,source.kind)
			host.add_child(actual)
			var art = actual.get_node_or_null("Art")
			var collision: CollisionShape2D = actual.get_node("CollisionShape2D")
			check(art is Node2D and not art is Sprite2D and art.get_script().resource_path == "res://scripts/world/ArenaPaperPropArt.gd", "actual prop is raster " + String(source.kind))
			if art == null:
				host.free()
				await process_frame
				quit(1)
				return
			check(art.scale == Vector2.ONE and actual.scale == Vector2.ONE and actual.rotation == 0 and actual.modulate.a == 1, "art distorts physical contact edge")
			check(Rect2(collision.global_position-size*0.5,size).is_equal_approx(rect) and collision.shape.size == size, "new art changes real collider")
			check(actual.collision_layer == 1|Terrain.QUERY_LAYER and actual.collision_mask == 0 and actual.is_in_group("arena_obstacles"), "obstacle query policy changed")
			check(actual.occlusion_rect == art.get_visual_rect() and actual.occlusion_rect.encloses(Rect2(-size.x*0.5,-size.y,size.x,size.y)), "visual/occlusion bounds exclude collision footprint")
			var player_at := actual.to_global(Vector2(0,-size.y*0.6))
			actual.update_player_occlusion(player_at,true,0.02)
			check(art.modulate.a < 1 and art.modulate.a > 0.32 and actual.modulate.a == 1, "solid footprint faded or upper decor does not yield")
			actual.update_player_occlusion(player_at,true,1)
			check(is_equal_approx(art.modulate.a,0.32) and actual.modulate.a == 1, "occlusion floor/physical alpha drift")
			actual.update_player_occlusion(actual.to_global(Vector2(0,60)),true,1)
			check(art.modulate.a == 1, "foreground decor does not return opaque")
			actual.update_player_occlusion(player_at,false,1)
			check(art.modulate.a == 1, "inactive occlusion stays faded")
			# Real physics query, not descriptor-only overlap evidence.
			var probe := CharacterBody2D.new()
			probe.collision_layer = 2
			probe.collision_mask = 1
			var shape := CollisionShape2D.new()
			var circle := CircleShape2D.new()
			circle.radius = 17
			shape.shape = circle
			probe.add_child(shape)
			probe.position = Vector2(rect.position.x-25,rect.get_center().y)
			host.add_child(probe)
			await physics_frame
			var hit := probe.move_and_collide(Vector2(size.x+60,0),true)
			check(hit != null and hit.get_collider() == actual, "new prop fails actual player-sized collision query")
			probe.free()
			actual.free()
	for index in descriptors.size():
		var solid = layout.get_child(index)
		var collision: CollisionShape2D = solid.get_node("CollisionShape2D")
		check(Rect2(collision.global_position-collision.shape.size*0.5,collision.shape.size).is_equal_approx(descriptors[index].rect), "actual random-map collider differs from saved descriptor")
	host.free()
	await process_frame
	if not failures: print("TEST PASS: %s %d" % [suite_name(), checks])
	quit(1 if failures else 0)
func suite_name() -> String: return "NativeArenaRuntimeTest"
func _check_source_contract(floor_view: Node2D) -> void:
	check(floor_view.material is ShaderMaterial and floor_view.material.shader.resource_path == "res://assets/art/shaders/paper_arena_floor_v1.gdshader", "original native floor shader absent")
