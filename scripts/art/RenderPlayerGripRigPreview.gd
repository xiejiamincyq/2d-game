extends SceneTree

const GripRig = preload("res://scripts/art/PlayerGripRig.gd")
const RUNTIME_PATH := "res://assets/art/actors/player/technical_previews/player_grip_rig_a_preview_v7.png"
const PREVIEW_PATH := "res://docs/art/previews/characters-combat/player-grip-rig-a-36-frame-v7.png"
const REPORT_PATH := "res://docs/art/reviews/characters-combat-player-grip-rig-a-metrics-v7.json"
const SOURCE_SIZE := Vector2i(384, 384)
const FRAME_SIZE := Vector2i(64, 64)
const PREVIEW_FRAME_SIZE := Vector2i(192, 192)
const FRAME_COUNT := 12
const FRAME_STEP_DEGREES := 30
const CAMERA_PITCH_DEGREES := 45.0
const CAMERA_DISTANCE := 8.5
const BODY_HEIGHT := 4.65
const NORMALIZED_BODY_HEIGHT := 1.988064
const PREVIEW_BACKGROUND := Color("061019")
const ACTION_COLORS := [Color("33fff2"), Color("f559bf"), Color("ff571f")]

func _initialize() -> void:
	print("RENDER START: PlayerGripRigPreview")
	await _render_preview()

func _render_preview() -> void:
	var viewport := _build_viewport()
	root.add_child(viewport)
	var rig := GripRig.new()
	viewport.add_child(rig)
	print("RENDER STAGE: rig node attached")
	if not rig.initialize():
		quit(1)
		return
	print("RENDER STAGE: rig initialized")
	rig.scale = Vector3.ONE * (BODY_HEIGHT / NORMALIZED_BODY_HEIGHT)
	if not rig.weapon_attachment is BoneAttachment3D:
		push_error("Grip rig rifle is not driven by BoneAttachment3D")
		quit(1)
		return
	var markers := _build_contact_markers(rig)
	print("RENDER STAGE: contact markers attached")
	await process_frame
	print("RENDER STAGE: first process frame")
	await RenderingServer.frame_post_draw

	var runtime_atlas := Image.create_empty(
		FRAME_COUNT * FRAME_SIZE.x,
		GripRig.ACTIONS.size() * FRAME_SIZE.y,
		false,
		Image.FORMAT_RGBA8
	)
	runtime_atlas.fill(Color(0, 0, 0, 0))
	var preview := Image.create_empty(
		6 * PREVIEW_FRAME_SIZE.x,
		6 * PREVIEW_FRAME_SIZE.y,
		false,
		Image.FORMAT_RGBA8
	)
	preview.fill(PREVIEW_BACKGROUND)

	var max_firing_error := 0.0
	var max_support_error := 0.0
	var max_stock_error := 0.0
	for action_index in range(GripRig.ACTIONS.size()):
		var action: String = GripRig.ACTIONS[action_index]
		print("RENDER PROGRESS: action=" + action)
		rig.apply_action(action)
		await process_frame
		_update_contact_markers(rig, markers)
		max_firing_error = maxf(max_firing_error, rig.firing_hand_error())
		max_support_error = maxf(max_support_error, rig.support_hand_error())
		max_stock_error = maxf(max_stock_error, rig.stock_contact_error())
		for frame_index in range(FRAME_COUNT):
			rig.rotation_degrees.y = float(frame_index * FRAME_STEP_DEGREES)
			var source := await _capture(viewport, action, frame_index)
			if source.is_empty():
				return
			var runtime_frame := source.duplicate()
			runtime_frame.resize(FRAME_SIZE.x, FRAME_SIZE.y, Image.INTERPOLATE_LANCZOS)
			runtime_atlas.blit_rect(
				runtime_frame,
				Rect2i(Vector2i.ZERO, FRAME_SIZE),
				Vector2i(frame_index * FRAME_SIZE.x, action_index * FRAME_SIZE.y)
			)
			var preview_frame := source.duplicate()
			preview_frame.resize(
				PREVIEW_FRAME_SIZE.x,
				PREVIEW_FRAME_SIZE.y,
				Image.INTERPOLATE_LANCZOS
			)
			var cell := Vector2i(frame_index % 6, action_index * 2 + frame_index / 6)
			var cell_position := cell * PREVIEW_FRAME_SIZE
			preview.blend_rect(
				preview_frame,
				Rect2i(Vector2i.ZERO, PREVIEW_FRAME_SIZE),
				cell_position
			)
			preview.fill_rect(
				Rect2i(cell_position, Vector2i(PREVIEW_FRAME_SIZE.x, 4)),
				ACTION_COLORS[action_index]
			)

	if max_firing_error > GripRig.CONTACT_TOLERANCE or max_support_error > GripRig.CONTACT_TOLERANCE or max_stock_error > GripRig.CONTACT_TOLERANCE:
		push_error("Grip contact tolerance failed during render")
		quit(1)
		return
	if not _save_png(runtime_atlas, RUNTIME_PATH, "36-frame review atlas"):
		return
	if not _save_png(preview, PREVIEW_PATH, "grip rig review board"):
		return
	var report := {
		"schema_version": 1,
		"asset_id": "player_grip_rig_a",
		"camera_pitch_degrees": CAMERA_PITCH_DEGREES,
		"yaw_step_degrees": FRAME_STEP_DEGREES,
		"actions": GripRig.ACTIONS,
		"sample_count": FRAME_COUNT * GripRig.ACTIONS.size(),
		"contact_tolerance": GripRig.CONTACT_TOLERANCE,
		"max_firing_hand_error": max_firing_error,
		"max_support_hand_error": max_support_error,
		"max_stock_contact_error": max_stock_error,
		"arm_region_vertex_count": rig.arm_region_vertex_count,
		"underweighted_arm_vertex_count": rig.underweighted_arm_vertex_count,
		"underweighted_arm_ratio": float(rig.underweighted_arm_vertex_count) / rig.arm_region_vertex_count,
		"weapon_attachment": "BoneAttachment3D:firing_hand",
		"production_integration": false,
	}
	var report_absolute := ProjectSettings.globalize_path(REPORT_PATH)
	DirAccess.make_dir_recursive_absolute(report_absolute.get_base_dir())
	var report_file := FileAccess.open(report_absolute, FileAccess.WRITE)
	if report_file == null:
		push_error("Could not write grip rig metrics: " + REPORT_PATH)
		quit(1)
		return
	report_file.store_string(JSON.stringify(report, "  ") + "\n")
	report_file.close()
	viewport.queue_free()
	await process_frame
	print("RENDER PASS: PlayerGripRigPreview 36 samples, exact 45-degree camera, constrained independent rifle")
	quit(0)

func _capture(viewport: SubViewport, action: String, frame_index: int) -> Image:
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	await RenderingServer.frame_post_draw
	var source := viewport.get_texture().get_image()
	if source.is_empty():
		push_error("Grip rig capture empty: %s frame %d" % [action, frame_index])
		quit(1)
		return Image.new()
	source.convert(Image.FORMAT_RGBA8)
	return source

func _save_png(image: Image, path: String, label: String) -> bool:
	var absolute := ProjectSettings.globalize_path(path)
	DirAccess.make_dir_recursive_absolute(absolute.get_base_dir())
	if image.save_png(absolute) != OK:
		push_error("Could not save %s: %s" % [label, path])
		quit(1)
		return false
	return true

func _build_contact_markers(rig: Node3D) -> Dictionary:
	var markers := {
		"firing": _contact_marker("FiringHandContact", Color("33fff2")),
		"support": _contact_marker("SupportHandContact", Color("f559bf")),
		"stock": _contact_marker("StockShoulderContact", Color("7dff7d")),
	}
	for marker in markers.values():
		rig.add_child(marker)
	_update_contact_markers(rig, markers)
	return markers

func _contact_marker(marker_name: String, color: Color) -> MeshInstance3D:
	var marker := MeshInstance3D.new()
	marker.name = marker_name
	var sphere := SphereMesh.new()
	sphere.radius = 0.035
	sphere.height = 0.07
	sphere.radial_segments = 12
	sphere.rings = 6
	marker.mesh = sphere
	marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 2.0
	marker.material_override = material
	return marker

func _update_contact_markers(rig: Node3D, markers: Dictionary) -> void:
	(markers["firing"] as MeshInstance3D).position = rig.firing_hand_position()
	(markers["support"] as MeshInstance3D).position = rig.support_hand_position()
	(markers["stock"] as MeshInstance3D).position = rig.stock_contact_position()

func _build_viewport() -> SubViewport:
	var viewport := SubViewport.new()
	viewport.name = "PlayerGripRigPreviewViewport"
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
