extends SceneTree

const EnemyScript = preload("res://scripts/actors/Enemy.gd")

const OUTPUT_PATH := "res://docs/art/previews/characters-combat/enemy-static-runtime-v1.png"
const VIEWPORT_SIZE := Vector2i(1536, 900)

func _initialize() -> void:
	print("RENDER START: Static enemy runtime preview")
	var viewport := SubViewport.new()
	viewport.size = VIEWPORT_SIZE
	viewport.transparent_bg = false
	viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)

	var background := ColorRect.new()
	background.size = Vector2(VIEWPORT_SIZE)
	background.color = Color("071018")
	viewport.add_child(background)
	_add_grid(background)
	_add_label(background, "B CHIBI ENEMIES — SINGLE-SPRITE RUNTIME GATE", Vector2(42, 24), 28)
	_add_label(background, "fixed elevated-oblique camera · right-facing masters · horizontal player-facing flip", Vector2(42, 60), 16)

	var fixtures := [
		{"kind": EnemyScript.EnemyKind.SCRAPPER, "name": "SCRAPPER", "scale": EnemyScript.SCRAPPER_RUNTIME_SCALE},
		{"kind": EnemyScript.EnemyKind.DASHER, "name": "DASHER", "scale": EnemyScript.DASHER_RUNTIME_SCALE},
		{"kind": EnemyScript.EnemyKind.SPITTER, "name": "SPITTER", "scale": EnemyScript.SPITTER_RUNTIME_SCALE},
		{"kind": EnemyScript.EnemyKind.BRUISER, "name": "BRUISER", "scale": EnemyScript.BRUISER_RUNTIME_SCALE},
		{"kind": EnemyScript.EnemyKind.MARKSMAN, "name": "MARKSMAN", "scale": EnemyScript.MARKSMAN_RUNTIME_SCALE},
		{"kind": EnemyScript.EnemyKind.LOBBER, "name": "LOBBER", "scale": EnemyScript.LOBBER_RUNTIME_SCALE},
		{"kind": EnemyScript.EnemyKind.OVERSEER, "name": "OVERSEER", "scale": EnemyScript.OVERSEER_RUNTIME_SCALE},
	]
	for index in range(fixtures.size()):
		var fixture: Dictionary = fixtures[index]
		var column := index % 4
		var row := index / 4
		var center := Vector2(190.0 + float(column) * 380.0, 220.0 + float(row) * 292.0)
		_add_label(background, fixture.name, center + Vector2(-68, -102), 17)
		await _spawn_enemy(viewport, fixture.kind, center + Vector2(-58, 0), Vector2(0.78, 0.78), false)
		await _spawn_enemy(viewport, fixture.kind, center + Vector2(58, 0), Vector2(0.78, 0.78), true)
		_add_label(background, "MASTER", center + Vector2(-88, 74), 12)
		_add_label(background, "FLIP", center + Vector2(38, 74), 12)

	_add_label(background, "ACTUAL GAMEPLAY SCALE", Vector2(42, 742), 16)
	for index in range(fixtures.size()):
		var fixture: Dictionary = fixtures[index]
		var position := Vector2(180.0 + float(index) * 195.0, 823.0)
		await _spawn_enemy(viewport, fixture.kind, position, fixture.scale, index % 2 == 1)
		_add_label(background, fixture.name, position + Vector2(-48, 52), 11)

	await process_frame
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	await process_frame
	var capture := viewport.get_texture().get_image()
	if capture == null or capture.is_empty() or capture.get_size() != VIEWPORT_SIZE:
		push_error("Static enemy runtime capture is empty or incorrectly sized")
		quit(1)
		return
	var absolute_path := ProjectSettings.globalize_path(OUTPUT_PATH)
	DirAccess.make_dir_recursive_absolute(absolute_path.get_base_dir())
	if capture.save_png(absolute_path) != OK:
		push_error("Could not save static enemy runtime capture: " + OUTPUT_PATH)
		quit(1)
		return
	viewport.queue_free()
	await create_timer(0.25).timeout
	await process_frame
	print("RENDER PASS: Static enemy runtime preview %dx%d -> %s" % [capture.get_width(), capture.get_height(), OUTPUT_PATH])
	quit(0)

func _spawn_enemy(parent: Node, kind: int, position: Vector2, visual_scale: Vector2, flip_h: bool) -> void:
	var enemy := EnemyScript.new()
	enemy.position = position
	enemy.setup(kind, 1, parent)
	enemy.set_physics_process(false)
	parent.add_child(enemy)
	await process_frame
	enemy.set_physics_process(false)
	enemy.static_visual.scale = visual_scale
	enemy.static_visual.flip_h = flip_h
	enemy.static_visual_half_height = 64.0 * visual_scale.y
	enemy.queue_redraw()

func _add_label(parent: Control, value: String, position: Vector2, font_size: int) -> void:
	var label := Label.new()
	label.text = value
	label.position = position
	label.add_theme_color_override("font_color", Color("d7ffff"))
	label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.9))
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	label.add_theme_font_size_override("font_size", font_size)
	parent.add_child(label)

func _add_grid(parent: Control) -> void:
	for x in range(0, VIEWPORT_SIZE.x, 64):
		var line := ColorRect.new()
		line.position = Vector2(x, 0)
		line.size = Vector2(1, VIEWPORT_SIZE.y)
		line.color = Color(0.08, 0.22, 0.26, 0.42)
		parent.add_child(line)
	for y in range(0, VIEWPORT_SIZE.y, 64):
		var line := ColorRect.new()
		line.position = Vector2(0, y)
		line.size = Vector2(VIEWPORT_SIZE.x, 1)
		line.color = Color(0.08, 0.22, 0.26, 0.42)
		parent.add_child(line)
