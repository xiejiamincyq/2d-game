extends SceneTree

const MainScript = preload("res://scripts/Main.gd")
const EnemyScript = preload("res://scripts/actors/Enemy.gd")

func _initialize() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var scene := MainScript.new()
	scene.audio_enabled = false
	viewport.add_child(scene)
	await process_frame
	scene.snapshot_store.save_path = "user://mint_farm_render_test.json"
	scene._start_run()
	scene.arena_layout.generate(scene.WORLD_BOUNDS, 20260831)
	scene.player.advance_entrance(scene.player.get_entrance_duration() + 0.01)
	scene.player.global_position = Vector2(380, -180)
	scene.player.gun_angle = 0.0
	var camera := scene.player.get_node("PlayerCamera") as Camera2D
	camera.position_smoothing_enabled = false
	camera.reset_smoothing()
	scene.process_mode = Node.PROCESS_MODE_DISABLED
	for point in [Vector2(280, -100), Vector2(560, -60), Vector2(780, -360), Vector2(40, -290)]:
		var enemy := EnemyScript.new()
		enemy.setup(EnemyScript.EnemyKind.SCRAPPER, 1, scene.projectiles, scene.player)
		enemy.position = scene.arena_layout.resolve_spawn_position(point, 14.0)
		scene.enemies.add_child(enemy)
		enemy.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	var capture := viewport.get_texture().get_image()
	var path := "res://docs/art/previews/environment/mint-farm-runtime-v3.png"
	if capture == null or capture.is_empty() or capture.save_png(ProjectSettings.globalize_path(path)) != OK:
		push_error("Mint farm capture failed")
		quit(1)
		return
	scene.snapshot_store.clear_snapshot()
	viewport.queue_free()
	await process_frame
	if not await _render_depth_fixture():
		quit(1)
		return
	print("RENDER PASS: Mint farm runtime preview")
	quit(0)

func _render_depth_fixture() -> bool:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var world := Node2D.new()
	world.y_sort_enabled = true
	viewport.add_child(world)
	var floor_node = load("res://scripts/world/FloorGrid.gd").new()
	world.add_child(floor_node)
	var types = scene_types()
	for i in range(types.size()):
		var item: Dictionary = types[i]
		var obstacle = load("res://scripts/world/ArenaObstacle.gd").new()
		var center := Vector2(200 + i * 285, 355)
		var size: Vector2 = item["size"]
		obstacle.setup(Rect2(center - size * 0.5, size), item["kind"])
		world.add_child(obstacle)
		for y in [center.y - size.y * 0.5 - 14.0, center.y + size.y * 0.5 + 38.0]:
			var player = load("res://scripts/actors/Player.gd").new()
			player.position = Vector2(center.x, y)
			player.process_mode = Node.PROCESS_MODE_DISABLED
			world.add_child(player)
			player.advance_entrance(player.get_entrance_duration() + 0.01)
			player.queue_redraw()
		# Separate inspection fixture: show each prop hiding/revealing a rear player.
		# This pass inspects solid plinths; v2 retains the faded comparison.
		obstacle.update_player_occlusion(Vector2.ZERO, false, 1.0)
	await process_frame
	await RenderingServer.frame_post_draw
	var capture := viewport.get_texture().get_image()
	if capture == null or capture.is_empty() or capture.save_png(ProjectSettings.globalize_path("res://docs/art/previews/environment/mint-farm-depth-v3.png")) != OK:
		push_error("Mint farm depth fixture capture failed")
		viewport.queue_free()
		await process_frame
		return false
	viewport.queue_free()
	await process_frame
	return true

func scene_types() -> Array:
	return load("res://scripts/world/ArenaLayout.gd").OBSTACLE_TYPES
