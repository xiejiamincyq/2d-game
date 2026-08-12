extends SceneTree

const DEFAULT_MODEL_PATH := "res://assets/art/source/player/player_turnaround_model_mv_preview_v1.glb"
const DEFAULT_RUNTIME_PATH := "res://assets/art/actors/player/technical_previews/player_turnaround_mv_technical_preview.png"
const DEFAULT_PREVIEW_PATH := "res://docs/art/previews/characters-combat/player-turnaround-mv-12-angle-technical-preview-v1.png"
const SOURCE_SIZE := Vector2i(512, 512)
const FRAME_SIZE := Vector2i(64, 64)
const PREVIEW_FRAME_SIZE := Vector2i(256, 256)
const FRAME_COUNT := 12
const FRAME_STEP_DEGREES := 30
const CAMERA_PITCH_DEGREES := 45.0
const CAMERA_DISTANCE := 8.5
const TARGET_HEIGHT := 4.65
const PREVIEW_BACKGROUND := Color("061019")

var model_path := DEFAULT_MODEL_PATH
var runtime_path := DEFAULT_RUNTIME_PATH
var preview_path := DEFAULT_PREVIEW_PATH

func _initialize() -> void:
	model_path = _environment_path("PLAYER_MV_MODEL_PATH", DEFAULT_MODEL_PATH)
	runtime_path = _environment_path("PLAYER_MV_RUNTIME_PATH", DEFAULT_RUNTIME_PATH)
	preview_path = _environment_path("PLAYER_MV_PREVIEW_PATH", DEFAULT_PREVIEW_PATH)
	print("RENDER START: PlayerTurnaroundMVPreview")
	await _render_preview()

func _render_preview() -> void:
	var viewport := _build_viewport()
	root.add_child(viewport)
	var model := _load_model()
	if model == null:
		quit(1)
		return
	viewport.add_child(model)
	await process_frame
	await RenderingServer.frame_post_draw

	var runtime_atlas := Image.create_empty(
		FRAME_COUNT * FRAME_SIZE.x,
		FRAME_SIZE.y,
		false,
		Image.FORMAT_RGBA8
	)
	runtime_atlas.fill(Color(0, 0, 0, 0))
	var preview := Image.create_empty(
		6 * PREVIEW_FRAME_SIZE.x,
		2 * PREVIEW_FRAME_SIZE.y,
		false,
		Image.FORMAT_RGBA8
	)
	preview.fill(PREVIEW_BACKGROUND)

	for frame_index in range(FRAME_COUNT):
		var angle_degrees := frame_index * FRAME_STEP_DEGREES
		model.rotation_degrees.y = float(angle_degrees)
		viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
		await RenderingServer.frame_post_draw
		var source := viewport.get_texture().get_image()
		if source.is_empty():
			push_error("Multi-view preview returned an empty image at %d degrees" % angle_degrees)
			quit(1)
			return
		source.convert(Image.FORMAT_RGBA8)

		var runtime_frame := source.duplicate()
		runtime_frame.resize(FRAME_SIZE.x, FRAME_SIZE.y, Image.INTERPOLATE_LANCZOS)
		runtime_atlas.blit_rect(
			runtime_frame,
			Rect2i(Vector2i.ZERO, FRAME_SIZE),
			Vector2i(frame_index * FRAME_SIZE.x, 0)
		)

		var preview_frame := source.duplicate()
		preview_frame.resize(
			PREVIEW_FRAME_SIZE.x,
			PREVIEW_FRAME_SIZE.y,
			Image.INTERPOLATE_LANCZOS
		)
		var preview_cell := Vector2i(frame_index % 6, frame_index / 6)
		preview.blend_rect(
			preview_frame,
			Rect2i(Vector2i.ZERO, PREVIEW_FRAME_SIZE),
			preview_cell * PREVIEW_FRAME_SIZE
		)

	var runtime_absolute := ProjectSettings.globalize_path(runtime_path)
	DirAccess.make_dir_recursive_absolute(runtime_absolute.get_base_dir())
	if runtime_atlas.save_png(runtime_absolute) != OK:
		push_error("Could not save multi-view runtime preview: " + runtime_path)
		quit(1)
		return
	var preview_absolute := ProjectSettings.globalize_path(preview_path)
	DirAccess.make_dir_recursive_absolute(preview_absolute.get_base_dir())
	if preview.save_png(preview_absolute) != OK:
		push_error("Could not save multi-view review board: " + preview_path)
		quit(1)
		return
	viewport.queue_free()
	await process_frame
	print("RENDER PASS: PlayerTurnaroundMVPreview 12 true-yaw frames at exact 45-degree pitch")
	quit(0)

func _load_model() -> Node3D:
	var resource := ResourceLoader.load(model_path)
	if not resource is PackedScene:
		push_error("Multi-view GLB could not be loaded: " + model_path)
		return null
	var model := (resource as PackedScene).instantiate() as Node3D
	if model == null:
		push_error("Multi-view GLB did not instantiate as Node3D")
		return null
	var meshes: Array[MeshInstance3D] = []
	_collect_meshes(model, meshes)
	if meshes.is_empty():
		push_error("Multi-view GLB contains no mesh instances")
		return null
	var bounds := _combined_bounds(model, meshes)
	if bounds.size.y <= 0.0:
		push_error("Multi-view GLB has invalid bounds")
		return null
	var model_scale := TARGET_HEIGHT / bounds.size.y
	model.scale = Vector3.ONE * model_scale
	var center := bounds.get_center()
	model.position = Vector3(-center.x, -bounds.position.y, -center.z) * model_scale

	var material := StandardMaterial3D.new()
	material.albedo_color = Color("7f8790")
	material.metallic = 0.18
	material.roughness = 0.72
	for mesh_instance in meshes:
		mesh_instance.material_override = material
		mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	return model

func _build_viewport() -> SubViewport:
	var viewport := SubViewport.new()
	viewport.name = "PlayerTurnaroundMVPreviewViewport"
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
	environment_resource.ambient_light_energy = 0.48
	environment_resource.ssao_enabled = true
	environment_resource.ssao_radius = 1.25
	environment_resource.ssao_intensity = 2.0
	environment.environment = environment_resource
	viewport.add_child(environment)

	var target := Vector3(0, TARGET_HEIGHT * 0.5, 0)
	var pitch_radians := deg_to_rad(CAMERA_PITCH_DEGREES)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 5.8
	camera.position = target + Vector3(
		0,
		sin(pitch_radians) * CAMERA_DISTANCE,
		cos(pitch_radians) * CAMERA_DISTANCE
	)
	camera.look_at_from_position(camera.position, target, Vector3.UP)
	camera.current = true
	viewport.add_child(camera)

	var key_light := DirectionalLight3D.new()
	key_light.light_color = Color("d8ecff")
	key_light.light_energy = 1.65
	key_light.rotation_degrees = Vector3(-45, -32, 0)
	key_light.shadow_enabled = true
	viewport.add_child(key_light)

	var fill_light := DirectionalLight3D.new()
	fill_light.light_color = Color("f2d6e8")
	fill_light.light_energy = 0.32
	fill_light.rotation_degrees = Vector3(-35, 145, 0)
	viewport.add_child(fill_light)

	var cyan_rim := OmniLight3D.new()
	cyan_rim.light_color = Color("33fff2")
	cyan_rim.light_energy = 1.25
	cyan_rim.omni_range = 8.0
	cyan_rim.position = Vector3(-3.5, 4.5, -3.0)
	viewport.add_child(cyan_rim)
	return viewport

func _environment_path(variable_name: String, fallback: String) -> String:
	var value := OS.get_environment(variable_name)
	return fallback if value.is_empty() else value

func _collect_meshes(node: Node, output: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D:
		output.append(node as MeshInstance3D)
	for child in node.get_children():
		_collect_meshes(child, output)

func _combined_bounds(root_node: Node3D, meshes: Array[MeshInstance3D]) -> AABB:
	var minimum := Vector3(INF, INF, INF)
	var maximum := Vector3(-INF, -INF, -INF)
	for mesh_instance in meshes:
		var local_bounds := mesh_instance.get_aabb()
		var relative := _transform_relative_to(mesh_instance, root_node)
		for x in [0.0, 1.0]:
			for y in [0.0, 1.0]:
				for z in [0.0, 1.0]:
					var corner := local_bounds.position + local_bounds.size * Vector3(x, y, z)
					var point := relative * corner
					minimum = minimum.min(point)
					maximum = maximum.max(point)
	return AABB(minimum, maximum - minimum)

func _transform_relative_to(node: Node3D, ancestor: Node3D) -> Transform3D:
	var result := Transform3D.IDENTITY
	var current: Node = node
	while current != null and current != ancestor:
		if current is Node3D:
			result = (current as Node3D).transform * result
		current = current.get_parent()
	return result
