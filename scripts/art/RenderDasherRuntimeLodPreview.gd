extends SceneTree

const OUTPUT_PATH := "res://docs/art/previews/characters-combat/dasher-runtime-lod-comparison-v1.png"
const VIEWPORT_SIZE := Vector2i(1536, 900)
const FRAME_LABELS := ["RUN 1", "RUN 2", "RUN 3", "WINDUP", "STRIKE", "RECOVER"]
const ROWS := [
	{"label": "REFERENCE 512 PX CELL · 12.00 MiB", "cell": 512, "a": "res://.godot/dasher_lod_a_512.png", "b": "res://.godot/dasher_lod_b_512.png"},
	{"label": "CANDIDATE 256 PX CELL · 3.00 MiB", "cell": 256, "a": "res://.godot/dasher_lod_a_256.png", "b": "res://.godot/dasher_lod_b_256.png"},
	{"label": "CANDIDATE 192 PX CELL · 1.69 MiB", "cell": 192, "a": "res://.godot/dasher_lod_a_192.png", "b": "res://.godot/dasher_lod_b_192.png"},
	{"label": "CANDIDATE 128 PX CELL · 0.75 MiB", "cell": 128, "a": "res://.godot/dasher_lod_a_128.png", "b": "res://.godot/dasher_lod_b_128.png"},
]

func _initialize() -> void:
	print("RENDER START: Dasher runtime LOD comparison")
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
	_add_label(background, "DASHER RUNTIME TEXTURE LOD GATE", Vector2(42, 24), 28)
	_add_label(background, "A above B · all samples rendered at the exact 64 px runtime canvas", Vector2(42, 60), 16)
	for frame_index in range(FRAME_LABELS.size()):
		_add_label(background, FRAME_LABELS[frame_index], Vector2(278.0 + frame_index * 205.0, 92.0), 14)

	for row_index in range(ROWS.size()):
		var row: Dictionary = ROWS[row_index]
		var y := 190.0 + row_index * 175.0
		_add_label(background, row.label, Vector2(42, y - 64.0), 16)
		var texture_a := _load_texture(row.a)
		var texture_b := _load_texture(row.b)
		if texture_a == null or texture_b == null:
			quit(1)
			return
		for frame_index in range(6):
			var x := 320.0 + frame_index * 205.0
			_add_sprite(viewport, texture_a, frame_index, int(row.cell), Vector2(x, y - 24.0))
			_add_sprite(viewport, texture_b, frame_index, int(row.cell), Vector2(x, y + 48.0))

	_add_label(background, "Gate: identity + limb silhouette + cyan outline + transparent separation at 64 px", Vector2(42, 846), 15)
	await process_frame
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	await process_frame
	var capture := viewport.get_texture().get_image()
	if capture == null or capture.is_empty() or capture.get_size() != VIEWPORT_SIZE:
		push_error("Dasher runtime LOD capture is empty or incorrectly sized")
		quit(1)
		return
	var absolute_path := ProjectSettings.globalize_path(OUTPUT_PATH)
	DirAccess.make_dir_recursive_absolute(absolute_path.get_base_dir())
	if capture.save_png(absolute_path) != OK:
		push_error("Could not save Dasher runtime LOD capture: " + OUTPUT_PATH)
		quit(1)
		return
	viewport.queue_free()
	await create_timer(0.25).timeout
	await process_frame
	print("RENDER PASS: Dasher runtime LOD comparison %dx%d -> %s" % [capture.get_width(), capture.get_height(), OUTPUT_PATH])
	quit(0)

func _load_texture(path: String) -> ImageTexture:
	var image := Image.load_from_file(ProjectSettings.globalize_path(path))
	if image.is_empty():
		push_error("Could not load Dasher LOD image: " + path)
		return null
	return ImageTexture.create_from_image(image)

func _add_sprite(parent: Node, texture: Texture2D, frame: int, cell_size: int, position: Vector2) -> void:
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	sprite.hframes = 3
	sprite.vframes = 2
	sprite.frame = frame
	sprite.position = position
	sprite.scale = Vector2.ONE * (64.0 / float(cell_size))
	parent.add_child(sprite)

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
