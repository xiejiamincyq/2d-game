extends RefCounted
class_name PlayerMotionPreviewRenderSupport

static func record_frame(
	source: Image,
	group_index: int,
	action_index: int,
	frame_index: int,
	runtime_atlas: Image,
	candidate_sheet: Image,
	comparison: Image,
	runtime_frame_size: Vector2i,
	candidate_frame_size: Vector2i,
	group_color: Color,
	action_color: Color
) -> void:
	var runtime_frame := source.duplicate()
	runtime_frame.resize(runtime_frame_size.x, runtime_frame_size.y, Image.INTERPOLATE_LANCZOS)
	var runtime_row := group_index * 2 + action_index
	runtime_atlas.blit_rect(runtime_frame, Rect2i(Vector2i.ZERO, runtime_frame_size), Vector2i(frame_index * runtime_frame_size.x, runtime_row * runtime_frame_size.y))
	var candidate_frame := source.duplicate()
	candidate_frame.resize(candidate_frame_size.x, candidate_frame_size.y, Image.INTERPOLATE_LANCZOS)
	var sheet_position := Vector2i(frame_index * candidate_frame_size.x, action_index * candidate_frame_size.y)
	candidate_sheet.blend_rect(candidate_frame, Rect2i(Vector2i.ZERO, candidate_frame_size), sheet_position)
	var comparison_cell := Vector2i(frame_index % 3, action_index * 2 + frame_index / 3)
	var comparison_position := Vector2i(group_index * candidate_frame_size.x * 3, 0) + comparison_cell * candidate_frame_size
	comparison.blend_rect(candidate_frame, Rect2i(Vector2i.ZERO, candidate_frame_size), comparison_position)
	comparison.fill_rect(Rect2i(comparison_position, Vector2i(candidate_frame_size.x, 4)), group_color)
	comparison.fill_rect(Rect2i(comparison_position + Vector2i(0, 4), Vector2i(candidate_frame_size.x, 2)), action_color)

static func capture(owner_tree: SceneTree, viewport: SubViewport, label: String, frame_index: int) -> Image:
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	await RenderingServer.frame_post_draw
	var source := viewport.get_texture().get_image()
	if source.is_empty():
		push_error("Motion preview capture empty: %s frame %d" % [label, frame_index])
		owner_tree.quit(1)
		return Image.new()
	source.convert(Image.FORMAT_RGBA8)
	return source

static func save_png(owner_tree: SceneTree, image: Image, path: String, label: String) -> bool:
	var absolute := ProjectSettings.globalize_path(path)
	DirAccess.make_dir_recursive_absolute(absolute.get_base_dir())
	if image.save_png(absolute) != OK:
		push_error("Could not save %s: %s" % [label, path])
		owner_tree.quit(1)
		return false
	return true

static func opaque_visible_ratio(image: Image) -> float:
	var visible_pixels := 0
	var opaque_pixels := 0
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			var alpha := image.get_pixel(x, y).a
			if alpha > 0.05:
				visible_pixels += 1
				if alpha >= 0.95:
					opaque_pixels += 1
	if visible_pixels == 0:
		return 0.0
	return float(opaque_pixels) / float(visible_pixels)

static func corner_alpha_max(image: Image) -> float:
	return maxf(
		maxf(image.get_pixel(0, 0).a, image.get_pixel(image.get_width() - 1, 0).a),
		maxf(image.get_pixel(0, image.get_height() - 1).a, image.get_pixel(image.get_width() - 1, image.get_height() - 1).a)
	)

static func build_viewport(
	viewport_name: String,
	source_size: Vector2i,
	body_height: float,
	camera_pitch_degrees: float,
	camera_distance: float,
	enable_msaa: bool = true,
	enable_screen_space_aa: bool = true
) -> SubViewport:
	var viewport := SubViewport.new()
	viewport.name = viewport_name
	viewport.size = source_size
	viewport.transparent_bg = true
	viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.msaa_3d = Viewport.MSAA_4X if enable_msaa else Viewport.MSAA_DISABLED
	viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA if enable_screen_space_aa else Viewport.SCREEN_SPACE_AA_DISABLED
	viewport.world_3d = World3D.new()
	var environment := WorldEnvironment.new()
	var environment_resource := Environment.new()
	environment_resource.background_mode = Environment.BG_COLOR
	environment_resource.background_color = Color(0, 0, 0, 0)
	environment_resource.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment_resource.ambient_light_color = Color("a9bdd0")
	environment_resource.ambient_light_energy = 0.82
	environment_resource.ssao_enabled = true
	environment_resource.ssao_radius = 1.25
	environment_resource.ssao_intensity = 2.0
	environment.environment = environment_resource
	viewport.add_child(environment)
	var target := Vector3(0, body_height * 0.5, 0)
	var pitch_radians := deg_to_rad(camera_pitch_degrees)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 5.8
	camera.position = target + Vector3(0, sin(pitch_radians) * camera_distance, cos(pitch_radians) * camera_distance)
	camera.look_at_from_position(camera.position, target, Vector3.UP)
	camera.current = true
	viewport.add_child(camera)
	var key_light := DirectionalLight3D.new()
	key_light.light_color = Color("d8ecff")
	key_light.light_energy = 1.35
	key_light.rotation_degrees = Vector3(-45, -32, 0)
	key_light.shadow_enabled = true
	viewport.add_child(key_light)
	var fill_light := DirectionalLight3D.new()
	fill_light.light_color = Color("f2d6e8")
	fill_light.light_energy = 0.58
	fill_light.rotation_degrees = Vector3(-35, 145, 0)
	viewport.add_child(fill_light)
	var cyan_rim := OmniLight3D.new()
	cyan_rim.light_color = Color("33fff2")
	cyan_rim.light_energy = 0.7
	cyan_rim.omni_range = 8.0
	cyan_rim.position = Vector3(-3.5, 4.5, -3.0)
	viewport.add_child(cyan_rim)
	return viewport
