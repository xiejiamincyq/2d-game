extends SceneTree

const MainScene = preload("res://scenes/Main.tscn")
const EnemyScript = preload("res://scripts/actors/Enemy.gd")
const ArcPulseVisualScript = preload("res://scripts/components/ArcPulseVisual.gd")
const TestSupport = preload("res://scripts/tests/TestSupport.gd")

const OUTPUT_PATH := "res://docs/art/previews/characters-combat/art-stress-combat-runtime-v1.png"
const VIEWPORT_SIZE := Vector2i(1536, 900)

func _initialize() -> void:
	print("RENDER START: Art stress combat runtime preview")
	var fixture := await _create_stress_fixture()
	var viewport: SubViewport = fixture["viewport"]

	await process_frame
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	await process_frame
	var capture := viewport.get_texture().get_image()
	if capture == null or capture.is_empty() or capture.get_size() != VIEWPORT_SIZE:
		push_error("Art stress combat capture is empty or incorrectly sized")
		quit(1)
		return
	var absolute_path := ProjectSettings.globalize_path(OUTPUT_PATH)
	DirAccess.make_dir_recursive_absolute(absolute_path.get_base_dir())
	if capture.save_png(absolute_path) != OK:
		push_error("Could not save art stress combat capture: " + OUTPUT_PATH)
		quit(1)
		return
	viewport.queue_free()
	await create_timer(0.25).timeout
	await process_frame
	print("RENDER PASS: Art stress combat runtime preview %dx%d -> %s" % [capture.get_width(), capture.get_height(), OUTPUT_PATH])
	quit(0)

func _create_stress_fixture() -> Dictionary:
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
	scene.player.set_overdrive_active(true)
	scene.player.global_position = Vector2.ZERO
	scene.player.gun_angle = deg_to_rad(25.0)
	scene.player.velocity = Vector2(250.0, 95.0)
	scene.player.visual_current_action = "fire"
	scene.player.visual_elapsed = 0.22
	scene.player.visual_fire_timer = 0.5
	scene.player.queue_redraw()
	scene.ui.set_overdrive_charge(100.0, true)
	scene.ui.set_overdrive(true, 6.8)

	var camera := scene.player.get_node("PlayerCamera") as Camera2D
	camera.position_smoothing_enabled = false
	camera.reset_smoothing()
	_spawn_dasher_ring(scene)
	_spawn_support_enemies(scene)
	_spawn_projectile_fan(scene)
	_spawn_effect_clusters(scene)
	_spawn_arc_pulses(scene)
	return {"viewport": viewport, "scene": scene}

func _spawn_dasher_ring(scene: Node) -> void:
	for index in range(16):
		var angle := TAU * float(index) / 16.0
		var radius := Vector2(330.0 + float(index % 3) * 34.0, 245.0 + float(index % 2) * 28.0)
		var position := Vector2(cos(angle) * radius.x, sin(angle) * radius.y + 42.0)
		_spawn_enemy(scene, EnemyScript.EnemyKind.DASHER, position, index % 2, index % 6)

func _spawn_support_enemies(scene: Node) -> void:
	var scrapper_positions := [
		Vector2(-520, -170), Vector2(-480, 180), Vector2(510, -145), Vector2(540, 190),
		Vector2(-120, -290), Vector2(145, 315),
	]
	for position in scrapper_positions:
		_spawn_enemy(scene, EnemyScript.EnemyKind.SCRAPPER, position, 0, 0)
	for position in [Vector2(-560, 10), Vector2(570, 25), Vector2(-235, 300), Vector2(255, -275)]:
		_spawn_enemy(scene, EnemyScript.EnemyKind.BRUISER, position, 0, 0)

func _spawn_enemy(scene: Node, kind: int, position: Vector2, variant: int, animation_frame: int) -> void:
	var enemy := EnemyScript.new()
	enemy.global_position = position
	enemy.setup(kind, 3, scene.projectiles)
	if kind == EnemyScript.EnemyKind.DASHER:
		enemy.set_dasher_variant(variant)
	scene.enemies.add_child(enemy)
	enemy.set_physics_process(false)
	if kind == EnemyScript.EnemyKind.DASHER:
		enemy.dasher_visual.frame = animation_frame

func _spawn_projectile_fan(scene: Node) -> void:
	for index in range(12):
		var direction := Vector2.RIGHT.rotated(TAU * float(index) / 12.0)
		scene.player._spawn_bullet(direction)
	var projectile_index := 0
	for projectile in scene.projectiles.get_children():
		projectile.global_position += projectile.velocity.normalized() * (62.0 + float(projectile_index % 4) * 42.0)
		projectile.set_physics_process(false)
		projectile_index += 1

func _spawn_effect_clusters(scene: Node) -> void:
	var centers := [Vector2(-315, -115), Vector2(345, 135), Vector2(-80, 245), Vector2(220, -205)]
	for center_index in range(centers.size()):
		var center: Vector2 = centers[center_index]
		for spark_index in range(4):
			scene.combat_vfx.request_effect(
				&"spark",
				center,
				Vector2.RIGHT.rotated(float(spark_index) * TAU / 4.0),
				1.0
			)
		if center_index % 2 == 0:
			scene.combat_vfx.request_effect(&"ring", center, Vector2.UP, 1.15)
		else:
			scene.combat_vfx.request_effect(&"blast", center, Vector2.UP, 0.72)
	scene.combat_vfx._process(0.05)
	scene.combat_vfx.set_process(false)
	scene.combat_vfx.queue_redraw()

func _spawn_arc_pulses(scene: Node) -> void:
	for pulse_index in range(2):
		var pulse := ArcPulseVisualScript.new()
		pulse.global_position = Vector2.ZERO
		pulse.setup(190.0 + float(pulse_index) * 95.0)
		pulse.age = 0.24 + float(pulse_index) * 0.12
		pulse.tint = Color("33fff2") if pulse_index == 0 else Color("b45cff")
		pulse.process_mode = Node.PROCESS_MODE_DISABLED
		scene.projectiles.add_child(pulse)
		pulse.queue_redraw()
