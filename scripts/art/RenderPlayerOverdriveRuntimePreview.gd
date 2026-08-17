extends SceneTree

const PlayerScript = preload("res://scripts/actors/Player.gd")

const OUTPUT_PATH := "res://docs/art/previews/characters-combat/player-overdrive-runtime-v1.png"
const VIEWPORT_SIZE := Vector2i(1536, 900)
const ANGLES_DEGREES := [0, 45, 90, 135, 180, 225, 270, 315]
const ROWS := [
	{"label": "NORMAL MOVE · 1.00×", "action": "move", "overdrive": false, "elapsed": 0.12},
	{"label": "OVERDRIVE MOVE · 1.30×", "action": "move", "overdrive": true, "elapsed": 0.156},
	{"label": "OVERDRIVE FIRE · 1.50× READABILITY CAP", "action": "fire", "overdrive": true, "elapsed": 0.125},
]

func _initialize() -> void:
	print("RENDER START: Player overdrive runtime preview")
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
	_add_label(background, "PLAYER M2 — HIGH-SPEED OVERDRIVE RUNTIME GATE", Vector2(42, 24), 28)
	_add_label(background, "Fixed 45° camera · body turn follows aim · 8 sampled headings from 120 available", Vector2(42, 60), 16)

	for row_index in range(ROWS.size()):
		var row: Dictionary = ROWS[row_index]
		var y := 225.0 + row_index * 235.0
		_add_label(background, row.label, Vector2(42, y - 92.0), 18)
		for angle_index in range(ANGLES_DEGREES.size()):
			var angle_degrees: int = ANGLES_DEGREES[angle_index]
			var x := 285.0 + angle_index * 165.0
			await _spawn_player(
				viewport,
				Vector2(x, y),
				deg_to_rad(float(angle_degrees)),
				row.action,
				row.overdrive,
				row.elapsed
			)
			if row_index == 0:
				_add_label(background, "%03d°" % angle_degrees, Vector2(x - 24.0, 95.0), 14)

	_add_label(background, "Runtime scale 1.30× · opaque RGBA atlas · aura remains behind silhouette", Vector2(42, 846), 15)
	await process_frame
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	await process_frame
	var capture := viewport.get_texture().get_image()
	if capture == null or capture.is_empty() or capture.get_size() != VIEWPORT_SIZE:
		push_error("Player overdrive runtime capture is empty or incorrectly sized")
		quit(1)
		return
	var absolute_path := ProjectSettings.globalize_path(OUTPUT_PATH)
	DirAccess.make_dir_recursive_absolute(absolute_path.get_base_dir())
	if capture.save_png(absolute_path) != OK:
		push_error("Could not save player overdrive runtime capture: " + OUTPUT_PATH)
		quit(1)
		return
	viewport.queue_free()
	await create_timer(0.25).timeout
	await process_frame
	print("RENDER PASS: Player overdrive runtime preview %dx%d -> %s" % [capture.get_width(), capture.get_height(), OUTPUT_PATH])
	quit(0)

func _spawn_player(
	parent: Node,
	position: Vector2,
	aim_angle: float,
	action: String,
	overdrive: bool,
	elapsed: float
) -> void:
	var player := PlayerScript.new()
	player.position = position
	player.process_mode = Node.PROCESS_MODE_DISABLED
	parent.add_child(player)
	await process_frame
	player.set_physics_process(false)
	player.gun_angle = aim_angle
	player.visual_current_action = action
	player.visual_elapsed = elapsed
	player.velocity = Vector2.RIGHT.rotated(aim_angle) * player.BASE_MOVE_SPEED
	player.set_overdrive_active(overdrive)
	player.queue_redraw()

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
		var vertical := ColorRect.new()
		vertical.position = Vector2(x, 0)
		vertical.size = Vector2(1, VIEWPORT_SIZE.y)
		vertical.color = Color(0.08, 0.22, 0.26, 0.42)
		parent.add_child(vertical)
	for y in range(0, VIEWPORT_SIZE.y, 64):
		var horizontal := ColorRect.new()
		horizontal.position = Vector2(0, y)
		horizontal.size = Vector2(VIEWPORT_SIZE.x, 1)
		horizontal.color = Color(0.08, 0.22, 0.26, 0.42)
		parent.add_child(horizontal)
