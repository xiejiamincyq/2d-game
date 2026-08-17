extends SceneTree

const WEAPON_MODEL_PATH := "res://assets/art/source/player/player_weapon_model_mv_v1.glb"
const BODY_MODEL_PATH := "res://assets/art/source/player/player_turnaround_model_mv_a_alpha_v3.glb"
const RUNTIME_PATH := "res://assets/art/actors/player/technical_previews/player_weapon_model_mv_v1.png"
const PREVIEW_PATH := "res://docs/art/previews/characters-combat/player-weapon-model-12-angle-attachment-v1.png"
const SOURCE_SIZE := Vector2i(256, 256)
const FRAME_SIZE := Vector2i(64, 64)
const PREVIEW_FRAME_SIZE := Vector2i(256, 256)
const FRAME_COUNT := 12
const FRAME_STEP_DEGREES := 30
const CAMERA_PITCH_DEGREES := 45.0
const CAMERA_DISTANCE := 8.5
const BODY_HEIGHT := 4.65
const WEAPON_LENGTH := 2.55
const WEAPON_REVIEW_SCALE := 1.6
const PREVIEW_BACKGROUND := Color("061019")
const ATTACHMENT_BACKGROUND := Color("11161d")

func _initialize() -> void:
	print("RENDER START: PlayerWeaponModelPreview")
	await _render_preview()

func _render_preview() -> void:
	var viewport := _build_viewport()
	root.add_child(viewport)
	var rig := Node3D.new()
	viewport.add_child(rig)
	var body := _load_body()
	var weapon := _load_weapon()
	if body == null or weapon == null:
		quit(1)
		return
	rig.add_child(body)
	rig.add_child(weapon)
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
		4 * PREVIEW_FRAME_SIZE.y,
		false,
		Image.FORMAT_RGBA8
	)
	preview.fill(PREVIEW_BACKGROUND)
	preview.fill_rect(
		Rect2i(0, 2 * PREVIEW_FRAME_SIZE.y, preview.get_width(), 2 * PREVIEW_FRAME_SIZE.y),
		ATTACHMENT_BACKGROUND
	)

	body.visible = false
	weapon.position = Vector3(0, BODY_HEIGHT * 0.52, 0)
	weapon.rotation_degrees = Vector3.ZERO
	weapon.scale = Vector3.ONE * WEAPON_REVIEW_SCALE
	for frame_index in range(FRAME_COUNT):
		if frame_index % 3 == 0:
			print("RENDER PROGRESS: weapon-only %d/%d" % [frame_index, FRAME_COUNT])
		rig.rotation_degrees.y = float(frame_index * FRAME_STEP_DEGREES)
		var source := await _capture(viewport, frame_index)
		if source.is_empty():
			return
		var runtime_frame := source.duplicate()
		runtime_frame.resize(FRAME_SIZE.x, FRAME_SIZE.y, Image.INTERPOLATE_LANCZOS)
		runtime_atlas.blit_rect(
			runtime_frame,
			Rect2i(Vector2i.ZERO, FRAME_SIZE),
			Vector2i(frame_index * FRAME_SIZE.x, 0)
		)
		_blend_preview_frame(preview, source, frame_index, 0)

	body.visible = true
	weapon.position = Vector3(-0.72, 1.78, 0.18)
	weapon.rotation_degrees = Vector3(0, -90.0, 0)
	weapon.scale = Vector3.ONE
	for frame_index in range(FRAME_COUNT):
		if frame_index % 3 == 0:
			print("RENDER PROGRESS: attachment %d/%d" % [frame_index, FRAME_COUNT])
		rig.rotation_degrees.y = float(frame_index * FRAME_STEP_DEGREES)
		var source := await _capture(viewport, frame_index)
		if source.is_empty():
			return
		_blend_preview_frame(preview, source, frame_index, 2)

	var runtime_absolute := ProjectSettings.globalize_path(RUNTIME_PATH)
	DirAccess.make_dir_recursive_absolute(runtime_absolute.get_base_dir())
	if runtime_atlas.save_png(runtime_absolute) != OK:
		push_error("Could not save independent weapon runtime preview: " + RUNTIME_PATH)
		quit(1)
		return
	var preview_absolute := ProjectSettings.globalize_path(PREVIEW_PATH)
	DirAccess.make_dir_recursive_absolute(preview_absolute.get_base_dir())
	if preview.save_png(preview_absolute) != OK:
		push_error("Could not save weapon attachment review board: " + PREVIEW_PATH)
		quit(1)
		return
	viewport.queue_free()
	await process_frame
	print("RENDER PASS: PlayerWeaponModelPreview independent weapon plus depth attachment at exact 45-degree pitch")
	quit(0)

func _capture(viewport: SubViewport, frame_index: int) -> Image:
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	await RenderingServer.frame_post_draw
	var source := viewport.get_texture().get_image()
	if source.is_empty():
		push_error("Weapon preview returned an empty image at frame %d" % frame_index)
		quit(1)
		return Image.new()
	source.convert(Image.FORMAT_RGBA8)
	return source

func _blend_preview_frame(preview: Image, source: Image, frame_index: int, row_offset: int) -> void:
	var preview_frame := source.duplicate()
	preview_frame.resize(PREVIEW_FRAME_SIZE.x, PREVIEW_FRAME_SIZE.y, Image.INTERPOLATE_LANCZOS)
	var cell := Vector2i(frame_index % 6, row_offset + frame_index / 6)
	preview.blend_rect(
		preview_frame,
		Rect2i(Vector2i.ZERO, PREVIEW_FRAME_SIZE),
		cell * PREVIEW_FRAME_SIZE
	)

func _load_body() -> Node3D:
	var body := _instantiate_model(BODY_MODEL_PATH, "approved body")
	if body == null:
		return null
	var meshes: Array[MeshInstance3D] = []
	_collect_meshes(body, meshes)
	var bounds := _combined_bounds(body, meshes)
	var body_scale := BODY_HEIGHT / bounds.size.y
	body.scale = Vector3.ONE * body_scale
	body.position = Vector3(-bounds.get_center().x, -bounds.position.y, -bounds.get_center().z) * body_scale
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("aab4be")
	material.metallic = 0.06
	material.roughness = 0.58
	_apply_material(meshes, material)
	return body

func _load_weapon() -> Node3D:
	var source := _instantiate_model(WEAPON_MODEL_PATH, "independent weapon")
	if source == null:
		return null
	var meshes: Array[MeshInstance3D] = []
	_collect_meshes(source, meshes)
	var bounds := _combined_bounds(source, meshes)
	var weapon_scale := WEAPON_LENGTH / bounds.size.x
	var pivot := Node3D.new()
	pivot.name = "IndependentWeaponPivot"
	pivot.add_child(source)
	source.scale = Vector3.ONE * weapon_scale
	source.position = -bounds.get_center() * weapon_scale
	var material := StandardMaterial3D.new()
	# Orange is a technical separation color for this review gate, not final texturing.
	material.albedo_color = Color("c66a32")
	material.metallic = 0.18
	material.roughness = 0.46
	_apply_material(meshes, material)
	return pivot

func _instantiate_model(path: String, label: String) -> Node3D:
	var resource := ResourceLoader.load(path)
	if not resource is PackedScene:
		push_error("Could not load %s GLB: %s" % [label, path])
		return null
	var model := (resource as PackedScene).instantiate() as Node3D
	if model == null:
		push_error("%s GLB did not instantiate as Node3D" % label)
		return null
	var meshes: Array[MeshInstance3D] = []
	_collect_meshes(model, meshes)
	if meshes.is_empty():
		push_error("%s GLB contains no mesh instances" % label)
		return null
	return model

func _apply_material(meshes: Array[MeshInstance3D], material: Material) -> void:
	for mesh_instance in meshes:
		mesh_instance.material_override = material
		mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON

func _build_viewport() -> SubViewport:
	var viewport := SubViewport.new()
	viewport.name = "PlayerWeaponModelPreviewViewport"
	viewport.size = SOURCE_SIZE
	viewport.transparent_bg = true
	viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.msaa_3d = Viewport.MSAA_2X
	viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
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

	var target := Vector3(0, BODY_HEIGHT * 0.5, 0)
	var pitch_radians := deg_to_rad(CAMERA_PITCH_DEGREES)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 5.8
	camera.position = target + Vector3(0, sin(pitch_radians) * CAMERA_DISTANCE, cos(pitch_radians) * CAMERA_DISTANCE)
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
