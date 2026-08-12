extends SceneTree

const MotionRig = preload("res://scripts/art/PlayerMotionRig.gd")
const RUNTIME_PATH := "res://assets/art/actors/player/technical_previews/player_motion_recoil_candidates.png"
const COMPARISON_PATH := "res://docs/art/previews/characters-combat/player-motion-recoil-candidates-comparison-v1.png"
const REPORT_PATH := "res://docs/art/reviews/characters-combat-player-motion-recoil-metrics-v1.json"
const CANDIDATE_PATHS := [
	"res://docs/art/previews/characters-combat/player-motion-recoil-candidate-a-v1.png",
	"res://docs/art/previews/characters-combat/player-motion-recoil-candidate-b-v1.png",
	"res://docs/art/previews/characters-combat/player-motion-recoil-candidate-c-v1.png",
]
const SOURCE_SIZE := Vector2i(384, 384)
const RUNTIME_FRAME_SIZE := Vector2i(64, 64)
const CANDIDATE_FRAME_SIZE := Vector2i(128, 128)
const GAIT_FRAME_COUNT := 6
const RECOIL_FRAME_COUNT := 6
const CAMERA_PITCH_DEGREES := 45.0
const PREVIEW_YAW_DEGREES := 45.0
const CAMERA_DISTANCE := 8.5
const BODY_HEIGHT := 4.65
const NORMALIZED_BODY_HEIGHT := 1.988064
const PREVIEW_BACKGROUND := Color("061019")
const CANDIDATE_COLORS := [Color("33fff2"), Color("f559bf"), Color("ff571f")]
const ACTION_COLORS := [Color("33fff2"), Color("ff571f")]

func _initialize() -> void:
	print("RENDER START: PlayerMotionRecoilCandidates")
	await _render_candidates()

func _render_candidates() -> void:
	var viewport := _build_viewport()
	root.add_child(viewport)
	var rig := MotionRig.new()
	viewport.add_child(rig)
	if not rig.initialize():
		quit(1)
		return
	rig.scale = Vector3.ONE * (BODY_HEIGHT / NORMALIZED_BODY_HEIGHT)
	rig.rotation_degrees.y = PREVIEW_YAW_DEGREES
	if not rig.weapon_attachment is BoneAttachment3D:
		push_error("Motion rig rifle is not driven by BoneAttachment3D")
		quit(1)
		return
	await process_frame
	await RenderingServer.frame_post_draw

	var runtime_atlas := Image.create_empty(384, 384, false, Image.FORMAT_RGBA8)
	runtime_atlas.fill(Color(0, 0, 0, 0))
	var comparison := Image.create_empty(1152, 512, false, Image.FORMAT_RGBA8)
	comparison.fill(PREVIEW_BACKGROUND)
	var candidate_sheets: Array[Image] = []
	for candidate_index in range(MotionRig.CANDIDATES.size()):
		var sheet := Image.create_empty(768, 256, false, Image.FORMAT_RGBA8)
		sheet.fill(Color(0, 0, 0, 0))
		candidate_sheets.append(sheet)

	var max_firing_error := 0.0
	var max_support_error := 0.0
	var max_stock_error := 0.0
	var minimum_foot_height := INF
	var minimum_opaque_visible_ratio := 1.0
	var candidate_profiles := {}
	for candidate_index in range(MotionRig.CANDIDATES.size()):
		var candidate: String = MotionRig.CANDIDATES[candidate_index]
		candidate_profiles[candidate] = rig.candidate_profile(candidate)
		print("RENDER PROGRESS: candidate=" + candidate + " action=GAIT")
		for frame_index in range(GAIT_FRAME_COUNT):
			var gait_phase := float(frame_index) / float(GAIT_FRAME_COUNT)
			rig.apply_motion(candidate, gait_phase, -1.0)
			await process_frame
			var source := await _capture(viewport, candidate, "GAIT", frame_index)
			if source.is_empty():
				return
			minimum_opaque_visible_ratio = minf(minimum_opaque_visible_ratio, _opaque_visible_ratio(source))
			_record_frame(source, candidate_index, 0, frame_index, runtime_atlas, candidate_sheets[candidate_index], comparison)
			max_firing_error = maxf(max_firing_error, rig.firing_hand_error())
			max_support_error = maxf(max_support_error, rig.support_hand_error())
			max_stock_error = maxf(max_stock_error, rig.stock_contact_error())
			minimum_foot_height = minf(minimum_foot_height, minf(rig.left_foot_position().y, rig.right_foot_position().y))

		print("RENDER PROGRESS: candidate=" + candidate + " action=RECOIL")
		for frame_index in range(RECOIL_FRAME_COUNT):
			var recoil_phase := float(frame_index) / float(RECOIL_FRAME_COUNT - 1)
			rig.apply_motion(candidate, 0.0, recoil_phase)
			await process_frame
			var source := await _capture(viewport, candidate, "RECOIL", frame_index)
			if source.is_empty():
				return
			minimum_opaque_visible_ratio = minf(minimum_opaque_visible_ratio, _opaque_visible_ratio(source))
			_record_frame(source, candidate_index, 1, frame_index, runtime_atlas, candidate_sheets[candidate_index], comparison)
			max_firing_error = maxf(max_firing_error, rig.firing_hand_error())
			max_support_error = maxf(max_support_error, rig.support_hand_error())
			max_stock_error = maxf(max_stock_error, rig.stock_contact_error())
			minimum_foot_height = minf(minimum_foot_height, minf(rig.left_foot_position().y, rig.right_foot_position().y))

	if max_firing_error > MotionRig.CONTACT_TOLERANCE or max_support_error > MotionRig.CONTACT_TOLERANCE or max_stock_error > MotionRig.CONTACT_TOLERANCE:
		push_error("Motion preview grip contact tolerance failed during render")
		quit(1)
		return
	if minimum_foot_height < rig.floor_height() - 0.0001:
		push_error("Motion preview foot penetrated the declared floor")
		quit(1)
		return

	if not _save_png(runtime_atlas, RUNTIME_PATH, "36-frame motion review atlas"):
		return
	var candidate_corner_alpha_max := {}
	for candidate_index in range(candidate_sheets.size()):
		candidate_corner_alpha_max[MotionRig.CANDIDATES[candidate_index]] = _corner_alpha_max(candidate_sheets[candidate_index])
		if not _save_png(candidate_sheets[candidate_index], CANDIDATE_PATHS[candidate_index], "motion candidate %s" % MotionRig.CANDIDATES[candidate_index]):
			return
	if not _save_png(comparison, COMPARISON_PATH, "motion comparison board"):
		return

	var report := {
		"schema_version": 1,
		"asset_id": "player_motion_recoil_candidates",
		"camera_pitch_degrees": CAMERA_PITCH_DEGREES,
		"preview_yaw_degrees": PREVIEW_YAW_DEGREES,
		"candidate_ids": MotionRig.CANDIDATES,
		"candidate_profiles": candidate_profiles,
		"gait_frames_per_candidate": GAIT_FRAME_COUNT,
		"recoil_frames_per_candidate": RECOIL_FRAME_COUNT,
		"sample_count": MotionRig.CANDIDATES.size() * (GAIT_FRAME_COUNT + RECOIL_FRAME_COUNT),
		"contact_tolerance": MotionRig.CONTACT_TOLERANCE,
		"max_firing_hand_error": max_firing_error,
		"max_support_hand_error": max_support_error,
		"max_stock_contact_error": max_stock_error,
		"minimum_foot_height": minimum_foot_height,
		"declared_floor_height": rig.floor_height(),
		"leg_weighted_vertex_count": rig.leg_weighted_vertex_count,
		"blended_leg_vertex_count": rig.blended_leg_vertex_count,
		"leg_region_vertex_count": rig.leg_region_vertex_count,
		"underweighted_leg_vertex_count": rig.underweighted_leg_vertex_count,
		"underweighted_leg_ratio": float(rig.underweighted_leg_vertex_count) / rig.leg_region_vertex_count,
		"minimum_opaque_visible_ratio": minimum_opaque_visible_ratio,
		"runtime_corner_alpha_max": _corner_alpha_max(runtime_atlas),
		"candidate_corner_alpha_max": candidate_corner_alpha_max,
		"source_vertices_preserved": rig.body_mesh.mesh.surface_get_array_len(0),
		"source_indices_preserved": rig.body_mesh.mesh.surface_get_array_index_len(0),
		"weapon_attachment": "BoneAttachment3D:firing_hand",
		"production_integration": false,
	}
	var report_absolute := ProjectSettings.globalize_path(REPORT_PATH)
	DirAccess.make_dir_recursive_absolute(report_absolute.get_base_dir())
	var report_file := FileAccess.open(report_absolute, FileAccess.WRITE)
	if report_file == null:
		push_error("Could not write motion metrics: " + REPORT_PATH)
		quit(1)
		return
	report_file.store_string(JSON.stringify(report, "  ") + "\n")
	report_file.close()
	viewport.queue_free()
	await process_frame
	print("RENDER PASS: PlayerMotionRecoilCandidates 36 samples, exact 45-degree camera, fixed down-right yaw")
	quit(0)

func _record_frame(
	source: Image,
	candidate_index: int,
	action_index: int,
	frame_index: int,
	runtime_atlas: Image,
	candidate_sheet: Image,
	comparison: Image
) -> void:
	var runtime_frame := source.duplicate()
	runtime_frame.resize(RUNTIME_FRAME_SIZE.x, RUNTIME_FRAME_SIZE.y, Image.INTERPOLATE_LANCZOS)
	var runtime_row := candidate_index * 2 + action_index
	runtime_atlas.blit_rect(
		runtime_frame,
		Rect2i(Vector2i.ZERO, RUNTIME_FRAME_SIZE),
		Vector2i(frame_index * RUNTIME_FRAME_SIZE.x, runtime_row * RUNTIME_FRAME_SIZE.y)
	)
	var candidate_frame := source.duplicate()
	candidate_frame.resize(CANDIDATE_FRAME_SIZE.x, CANDIDATE_FRAME_SIZE.y, Image.INTERPOLATE_LANCZOS)
	var sheet_position := Vector2i(frame_index * CANDIDATE_FRAME_SIZE.x, action_index * CANDIDATE_FRAME_SIZE.y)
	candidate_sheet.blend_rect(candidate_frame, Rect2i(Vector2i.ZERO, CANDIDATE_FRAME_SIZE), sheet_position)

	var comparison_cell := Vector2i(frame_index % 3, action_index * 2 + frame_index / 3)
	var comparison_position := Vector2i(candidate_index * 384, 0) + comparison_cell * CANDIDATE_FRAME_SIZE
	comparison.blend_rect(candidate_frame, Rect2i(Vector2i.ZERO, CANDIDATE_FRAME_SIZE), comparison_position)
	comparison.fill_rect(Rect2i(comparison_position, Vector2i(CANDIDATE_FRAME_SIZE.x, 4)), CANDIDATE_COLORS[candidate_index])
	comparison.fill_rect(Rect2i(comparison_position + Vector2i(0, 4), Vector2i(CANDIDATE_FRAME_SIZE.x, 2)), ACTION_COLORS[action_index])

func _capture(viewport: SubViewport, candidate: String, action: String, frame_index: int) -> Image:
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	await RenderingServer.frame_post_draw
	var source := viewport.get_texture().get_image()
	if source.is_empty():
		push_error("Motion capture empty: %s %s frame %d" % [candidate, action, frame_index])
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

func _opaque_visible_ratio(image: Image) -> float:
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

func _corner_alpha_max(image: Image) -> float:
	return maxf(
		maxf(image.get_pixel(0, 0).a, image.get_pixel(image.get_width() - 1, 0).a),
		maxf(image.get_pixel(0, image.get_height() - 1).a, image.get_pixel(image.get_width() - 1, image.get_height() - 1).a)
	)

func _build_viewport() -> SubViewport:
	var viewport := SubViewport.new()
	viewport.name = "PlayerMotionRecoilPreviewViewport"
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
