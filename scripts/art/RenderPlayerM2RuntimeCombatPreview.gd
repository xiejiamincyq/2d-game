extends SceneTree

const MainScene = preload("res://scenes/Main.tscn")
const EnemyScript = preload("res://scripts/actors/Enemy.gd")
const TestSupport = preload("res://scripts/tests/TestSupport.gd")

const OUTPUT_PATH := "res://docs/art/previews/characters-combat/player-m2-runtime-combat-v1.png"
const VIEWPORT_SIZE := Vector2i(1280, 720)

func _initialize() -> void:
	print("RENDER START: Player M2 runtime combat preview")
	var viewport := SubViewport.new()
	viewport.size = VIEWPORT_SIZE
	viewport.transparent_bg = false
	viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)

	var scene := MainScene.instantiate()
	viewport.add_child(scene)
	await process_frame
	scene._start_run()
	await process_frame

	scene.wave_director.active = false
	scene.wave_director.spawn_queue.clear()
	TestSupport.stop_audio(scene.audio)
	scene.player.set_physics_process(false)
	scene.player.global_position = Vector2.ZERO
	scene.player.gun_angle = PI / 4.0
	scene.player.velocity = Vector2(150.0, 150.0)
	scene.player.visual_current_action = "fire"
	scene.player.visual_elapsed = 0.18
	scene.player.visual_fire_timer = 0.5
	scene.player.queue_redraw()

	var camera := scene.player.get_node("PlayerCamera") as Camera2D
	camera.position_smoothing_enabled = false
	camera.reset_smoothing()

	_spawn_enemy(scene, EnemyScript.EnemyKind.DASHER, Vector2(175.0, 115.0), 0, 1)
	_spawn_enemy(scene, EnemyScript.EnemyKind.DASHER, Vector2(-210.0, -120.0), 1, 4)
	_spawn_enemy(scene, EnemyScript.EnemyKind.SCRAPPER, Vector2(270.0, -70.0), 0, 0)
	_spawn_enemy(scene, EnemyScript.EnemyKind.BRUISER, Vector2(-300.0, 150.0), 0, 0)
	scene.player._spawn_bullet(Vector2.RIGHT.rotated(PI / 4.0))
	for projectile in scene.projectiles.get_children():
		projectile.set_physics_process(false)

	await process_frame
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	await process_frame
	var capture := viewport.get_texture().get_image()
	if capture == null or capture.is_empty() or capture.get_size() != VIEWPORT_SIZE:
		push_error("Player M2 runtime combat capture is empty or incorrectly sized")
		quit(1)
		return
	var absolute_path := ProjectSettings.globalize_path(OUTPUT_PATH)
	DirAccess.make_dir_recursive_absolute(absolute_path.get_base_dir())
	if capture.save_png(absolute_path) != OK:
		push_error("Could not save player M2 runtime combat capture: " + OUTPUT_PATH)
		quit(1)
		return
	viewport.queue_free()
	await create_timer(0.25).timeout
	await process_frame
	print("RENDER PASS: Player M2 runtime combat preview %dx%d -> %s" % [capture.get_width(), capture.get_height(), OUTPUT_PATH])
	quit(0)

func _spawn_enemy(scene: Node, kind: int, position: Vector2, variant: int, animation_frame: int) -> void:
	var enemy := EnemyScript.new()
	enemy.global_position = position
	enemy.setup(kind, 1, scene.projectiles)
	if kind == EnemyScript.EnemyKind.DASHER:
		enemy.set_dasher_variant(variant)
	scene.enemies.add_child(enemy)
	enemy.set_physics_process(false)
	if kind == EnemyScript.EnemyKind.DASHER:
		enemy.dasher_visual.frame = animation_frame
