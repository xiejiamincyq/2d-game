extends SceneTree

const EnemyScript = preload("res://scripts/actors/Enemy.gd")

const OUTPUT_PATH := "res://docs/art/previews/characters-combat/enemy-dasher-actions-runtime-v1.png"
const VIEWPORT_SIZE := Vector2i(1536, 900)
const FRAME_LABELS := ["RUN 1", "RUN 2", "RUN 3", "WINDUP", "STRIKE", "RECOVER"]

func _initialize() -> void:
	print("RENDER START: Dasher action runtime preview")
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
	_add_title(background, "DASHER A/B — MOVE + ATTACK RUNTIME GATE", Vector2(42, 24), 28)
	_add_title(background, "Godot shader preview · 3×2 atlas · fixed 45° camera · right-facing master", Vector2(42, 60), 16)

	for variant in range(2):
		var y := 245.0 + variant * 310.0
		_add_title(background, "A — HUMANOID SPRINTER" if variant == 0 else "B — SCRAP RUNNER", Vector2(42, y - 135.0), 20)
		for frame in range(6):
			var x := 160.0 + frame * 235.0
			await _spawn_dasher(viewport, variant, frame, Vector2(x, y), Vector2.ONE, false)
			_add_title(background, FRAME_LABELS[frame], Vector2(x - 50.0, y + 118.0), 15)

	_add_title(background, "64 PX RUNTIME + FLIP CHECK", Vector2(42, 798), 16)
	for index in range(4):
		var variant := index % 2
		var frame := 1 if index < 2 else 4
		await _spawn_dasher(viewport, variant, frame, Vector2(820.0 + index * 150.0, 825.0), Vector2(0.5, 0.5), index >= 2)

	await process_frame
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	await process_frame
	var capture := viewport.get_texture().get_image()
	if capture == null or capture.is_empty() or capture.get_size() != VIEWPORT_SIZE:
		push_error("Dasher action runtime capture is empty or incorrectly sized")
		quit(1)
		return
	var absolute_path := ProjectSettings.globalize_path(OUTPUT_PATH)
	DirAccess.make_dir_recursive_absolute(absolute_path.get_base_dir())
	if capture.save_png(absolute_path) != OK:
		push_error("Could not save Dasher action runtime capture: " + OUTPUT_PATH)
		quit(1)
		return
	viewport.queue_free()
	await create_timer(0.25).timeout
	await process_frame
	print("RENDER PASS: Dasher action runtime preview %dx%d -> %s" % [capture.get_width(), capture.get_height(), OUTPUT_PATH])
	quit(0)

func _spawn_dasher(
	parent: Node,
	variant: int,
	frame: int,
	position: Vector2,
	visual_scale: Vector2,
	flip_h: bool
) -> void:
	var enemy := EnemyScript.new()
	enemy.position = position
	enemy.setup(EnemyScript.EnemyKind.DASHER, 1, parent)
	enemy.set_physics_process(false)
	parent.add_child(enemy)
	await process_frame
	enemy.set_physics_process(false)
	enemy.set_dasher_variant(variant)
	enemy.dasher_visual.frame = frame
	enemy.dasher_visual.scale = visual_scale
	enemy.dasher_visual.flip_h = flip_h

func _add_title(parent: Control, value: String, position: Vector2, font_size: int) -> void:
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
