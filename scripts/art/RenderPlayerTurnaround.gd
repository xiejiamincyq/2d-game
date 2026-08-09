extends SceneTree

const PlayerTurnaroundModelScript = preload("res://scripts/art/PlayerTurnaroundModel.gd")

const SOURCE_SIZE := Vector2i(512, 512)
const FRAME_SIZE := Vector2i(64, 64)
const FRAME_STEP_DEGREES := 3
const FRAME_COUNT := 120
const ATLAS_COLUMNS := 12
const ATLAS_ROWS := 10
const DIRECTIONS_PATH := "res://assets/art/actors/player/turnaround_directions"
const ATLAS_PATH := "res://assets/art/actors/player/player_turnaround_atlas.png"
const PREVIEW_PATH := "res://docs/art/previews/characters-combat/player-turnaround-120-runtime-preview-v1.png"
const PREVIEW_BACKGROUND := Color("061019")

func _initialize() -> void:
	print("RENDER START: PlayerTurnaround")
	await _render_all()

func _render_all() -> void:
	var viewport := _build_viewport()
	root.add_child(viewport)
	var model: Node3D = PlayerTurnaroundModelScript.build()
	viewport.add_child(model)
	await process_frame
	await RenderingServer.frame_post_draw

	var directions_absolute := ProjectSettings.globalize_path(DIRECTIONS_PATH)
	DirAccess.make_dir_recursive_absolute(directions_absolute)
	_clear_generated_frames(directions_absolute)
	var atlas := Image.create_empty(
		ATLAS_COLUMNS * FRAME_SIZE.x,
		ATLAS_ROWS * FRAME_SIZE.y,
		false,
		Image.FORMAT_RGBA8
	)
	atlas.fill(Color(0, 0, 0, 0))
	var frames: Array[Image] = []

	for frame_index in range(FRAME_COUNT):
		var angle_degrees := frame_index * FRAME_STEP_DEGREES
		# Runtime angle 0 points right; positive angles advance clockwise in screen space.
		model.rotation_degrees.y = 90.0 - float(angle_degrees)
		PlayerTurnaroundModelScript.set_projection_angle(model, float(angle_degrees))
		viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
		await RenderingServer.frame_post_draw
		var source := viewport.get_texture().get_image()
		if source.is_empty():
			push_error("Turnaround render returned an empty image at %d degrees" % angle_degrees)
			quit(1)
			return
		source.convert(Image.FORMAT_RGBA8)
		source.resize(FRAME_SIZE.x, FRAME_SIZE.y, Image.INTERPOLATE_LANCZOS)
		frames.append(source)
		var frame_path := DIRECTIONS_PATH + "/angle_%03d.png" % angle_degrees
		if source.save_png(ProjectSettings.globalize_path(frame_path)) != OK:
			push_error("Could not save turnaround frame: " + frame_path)
			quit(1)
			return
		var cell := Vector2i(frame_index % ATLAS_COLUMNS, floori(float(frame_index) / float(ATLAS_COLUMNS)))
		atlas.blit_rect(source, Rect2i(Vector2i.ZERO, FRAME_SIZE), cell * FRAME_SIZE)

	if atlas.save_png(ProjectSettings.globalize_path(ATLAS_PATH)) != OK:
		push_error("Could not save turnaround atlas: " + ATLAS_PATH)
		quit(1)
		return
	_write_preview(frames)
	viewport.queue_free()
	await process_frame
	print("RENDER PASS: PlayerTurnaround %d frames at %d-degree steps, atlas %dx%d" % [
		FRAME_COUNT,
		FRAME_STEP_DEGREES,
		atlas.get_width(),
		atlas.get_height(),
	])
	quit(0)

func _build_viewport() -> SubViewport:
	var viewport := SubViewport.new()
	viewport.name = "PlayerTurnaroundViewport"
	viewport.size = SOURCE_SIZE
	viewport.transparent_bg = true
	viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.msaa_3d = Viewport.MSAA_4X
	viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
	viewport.world_3d = World3D.new()

	var environment := WorldEnvironment.new()
	var environment_resource := Environment.new()
	environment_resource.background_mode = Environment.BG_COLOR
	environment_resource.background_color = Color(0, 0, 0, 0)
	environment_resource.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment_resource.ambient_light_color = Color("708399")
	environment_resource.ambient_light_energy = 0.34
	environment_resource.ssao_enabled = true
	environment_resource.ssao_radius = 1.4
	environment_resource.ssao_intensity = 2.1
	environment.environment = environment_resource
	viewport.add_child(environment)

	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 5.9
	camera.position = Vector3(0, 6.4, 9.2)
	camera.look_at_from_position(camera.position, Vector3(0, 2.0, 0), Vector3.UP)
	camera.current = true
	viewport.add_child(camera)

	var key_light := DirectionalLight3D.new()
	key_light.light_color = Color("cde8ff")
	key_light.light_energy = 1.85
	key_light.rotation_degrees = Vector3(-42, -32, 0)
	key_light.shadow_enabled = true
	viewport.add_child(key_light)

	var fill_light := DirectionalLight3D.new()
	fill_light.light_color = Color("ffd8bb")
	fill_light.light_energy = 0.38
	fill_light.rotation_degrees = Vector3(-28, 148, 0)
	fill_light.shadow_enabled = false
	viewport.add_child(fill_light)

	var cyan_rim := OmniLight3D.new()
	cyan_rim.light_color = Color("33fff2")
	cyan_rim.light_energy = 1.7
	cyan_rim.omni_range = 8.0
	cyan_rim.position = Vector3(-3.5, 4.5, -3.0)
	cyan_rim.shadow_enabled = false
	viewport.add_child(cyan_rim)
	return viewport

func _clear_generated_frames(directory_path: String) -> void:
	var directory := DirAccess.open(directory_path)
	if directory == null:
		return
	for file_name in directory.get_files():
		if file_name.begins_with("angle_") and file_name.ends_with(".png"):
			directory.remove(file_name)

func _write_preview(frames: Array[Image]) -> void:
	var scale_factor := 3
	var cell_size := FRAME_SIZE * scale_factor
	var preview := Image.create_empty(6 * cell_size.x, 2 * cell_size.y, false, Image.FORMAT_RGBA8)
	preview.fill(PREVIEW_BACKGROUND)
	for sample_index in range(12):
		var frame := frames[sample_index * 10].duplicate()
		frame.resize(cell_size.x, cell_size.y, Image.INTERPOLATE_NEAREST)
		var position := Vector2i(sample_index % 6, sample_index / 6) * cell_size
		preview.blend_rect(frame, Rect2i(Vector2i.ZERO, cell_size), position)
	var preview_absolute := ProjectSettings.globalize_path(PREVIEW_PATH)
	DirAccess.make_dir_recursive_absolute(preview_absolute.get_base_dir())
	if preview.save_png(preview_absolute) != OK:
		push_error("Could not save turnaround preview: " + PREVIEW_PATH)
		quit(1)
