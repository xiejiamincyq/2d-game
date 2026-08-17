extends SceneTree

const RefinementRig = preload("res://scripts/art/PlayerMotionRefinementRig.gd")
const PreviewSupport = preload("res://scripts/art/PlayerMotionPreviewRenderSupport.gd")
const RUNTIME_PATH := "res://assets/art/actors/player/technical_previews/player_motion_refinement_a_candidates.png"
const COMPARISON_PATH := "res://docs/art/previews/characters-combat/player-motion-refinement-a-comparison-v1.png"
const REPORT_PATH := "res://docs/art/reviews/characters-combat-player-motion-refinement-a-metrics-v1.json"
const CANDIDATE_PATHS := [
	"res://docs/art/previews/characters-combat/player-motion-refinement-a1-v1.png",
	"res://docs/art/previews/characters-combat/player-motion-refinement-a2-v1.png",
	"res://docs/art/previews/characters-combat/player-motion-refinement-a3-v1.png",
]
const SOURCE_SIZE := Vector2i(384, 384)
const RUNTIME_FRAME_SIZE := Vector2i(64, 64)
const CANDIDATE_FRAME_SIZE := Vector2i(128, 128)
const GAIT_FRAME_COUNT := 6
const RECOIL_FRAME_COUNT := 6
const RECOIL_PHASES := [0.0, 0.18, 0.35, 0.55, 0.75, 1.0]
const CAMERA_PITCH_DEGREES := 45.0
const PREVIEW_YAW_DEGREES := 45.0
const CAMERA_DISTANCE := 8.5
const BODY_HEIGHT := 4.65
const NORMALIZED_BODY_HEIGHT := 1.988064
const PREVIEW_BACKGROUND := Color("061019")
const REFINEMENT_COLORS := [Color("33fff2"), Color("f559bf"), Color("ff571f")]
const ACTION_COLORS := [Color("33fff2"), Color("ff571f")]

func _initialize() -> void:
	print("RENDER START: PlayerMotionRefinementCandidates")
	await _render_candidates()

func _render_candidates() -> void:
	var viewport := PreviewSupport.build_viewport("PlayerMotionRefinementPreviewViewport", SOURCE_SIZE, BODY_HEIGHT, CAMERA_PITCH_DEGREES, CAMERA_DISTANCE)
	root.add_child(viewport)
	var rig := RefinementRig.new()
	viewport.add_child(rig)
	if not rig.initialize():
		quit(1)
		return
	rig.scale = Vector3.ONE * (BODY_HEIGHT / NORMALIZED_BODY_HEIGHT)
	rig.rotation_degrees.y = PREVIEW_YAW_DEGREES
	if not rig.weapon_attachment is BoneAttachment3D:
		push_error("Refinement rig rifle is not driven by BoneAttachment3D")
		quit(1)
		return
	await process_frame
	await RenderingServer.frame_post_draw

	var runtime_atlas := Image.create_empty(384, 384, false, Image.FORMAT_RGBA8)
	runtime_atlas.fill(Color(0, 0, 0, 0))
	var comparison := Image.create_empty(1152, 512, false, Image.FORMAT_RGBA8)
	comparison.fill(PREVIEW_BACKGROUND)
	var candidate_sheets: Array[Image] = []
	for refinement_index in range(RefinementRig.REFINEMENTS.size()):
		var sheet := Image.create_empty(768, 256, false, Image.FORMAT_RGBA8)
		sheet.fill(Color(0, 0, 0, 0))
		candidate_sheets.append(sheet)

	var max_firing_error := 0.0
	var max_support_error := 0.0
	var max_stock_error := 0.0
	var minimum_foot_height := INF
	var minimum_opaque_visible_ratio := 1.0
	var refinement_profiles := {}
	var mechanics_ranges := {}
	for refinement_index in range(RefinementRig.REFINEMENTS.size()):
		var refinement: String = RefinementRig.REFINEMENTS[refinement_index]
		refinement_profiles[refinement] = rig.refinement_profile(refinement)
		mechanics_ranges[refinement] = {
			"max_abs_hip_shift": 0.0,
			"max_abs_pelvis_yaw_degrees": 0.0,
			"max_abs_torso_yaw_degrees": 0.0,
			"max_abs_lateral_lean_degrees": 0.0,
			"min_recoil_curve": 0.0,
			"max_recoil_curve": 0.0,
		}
		print("RENDER PROGRESS: refinement=" + refinement + " action=GAIT")
		for frame_index in range(GAIT_FRAME_COUNT):
			var gait_phase := float(frame_index) / float(GAIT_FRAME_COUNT)
			rig.apply_refinement(refinement, gait_phase, -1.0)
			await process_frame
			var source := await PreviewSupport.capture(self, viewport, refinement + " GAIT", frame_index)
			if source.is_empty():
				return
			minimum_opaque_visible_ratio = minf(minimum_opaque_visible_ratio, PreviewSupport.opaque_visible_ratio(source))
			PreviewSupport.record_frame(source, refinement_index, 0, frame_index, runtime_atlas, candidate_sheets[refinement_index], comparison, RUNTIME_FRAME_SIZE, CANDIDATE_FRAME_SIZE, REFINEMENT_COLORS[refinement_index], ACTION_COLORS[0])
			_accumulate_metrics(rig, mechanics_ranges[refinement])
			max_firing_error = maxf(max_firing_error, rig.firing_hand_error())
			max_support_error = maxf(max_support_error, rig.support_hand_error())
			max_stock_error = maxf(max_stock_error, rig.stock_contact_error())
			minimum_foot_height = minf(minimum_foot_height, minf(rig.left_foot_position().y, rig.right_foot_position().y))

		print("RENDER PROGRESS: refinement=" + refinement + " action=RECOIL")
		for frame_index in range(RECOIL_FRAME_COUNT):
			var recoil_phase: float = RECOIL_PHASES[frame_index]
			rig.apply_refinement(refinement, 0.0, recoil_phase)
			await process_frame
			var source := await PreviewSupport.capture(self, viewport, refinement + " RECOIL", frame_index)
			if source.is_empty():
				return
			minimum_opaque_visible_ratio = minf(minimum_opaque_visible_ratio, PreviewSupport.opaque_visible_ratio(source))
			PreviewSupport.record_frame(source, refinement_index, 1, frame_index, runtime_atlas, candidate_sheets[refinement_index], comparison, RUNTIME_FRAME_SIZE, CANDIDATE_FRAME_SIZE, REFINEMENT_COLORS[refinement_index], ACTION_COLORS[1])
			_accumulate_metrics(rig, mechanics_ranges[refinement])
			max_firing_error = maxf(max_firing_error, rig.firing_hand_error())
			max_support_error = maxf(max_support_error, rig.support_hand_error())
			max_stock_error = maxf(max_stock_error, rig.stock_contact_error())
			minimum_foot_height = minf(minimum_foot_height, minf(rig.left_foot_position().y, rig.right_foot_position().y))

	if max_firing_error > RefinementRig.CONTACT_TOLERANCE or max_support_error > RefinementRig.CONTACT_TOLERANCE or max_stock_error > RefinementRig.CONTACT_TOLERANCE:
		push_error("Refinement grip contact tolerance failed during render")
		quit(1)
		return
	if minimum_foot_height < rig.floor_height() - 0.0001:
		push_error("Refinement foot penetrated the declared floor")
		quit(1)
		return
	if not PreviewSupport.save_png(self, runtime_atlas, RUNTIME_PATH, "36-frame mechanics refinement atlas"):
		return
	var candidate_corner_alpha_max := {}
	for refinement_index in range(candidate_sheets.size()):
		candidate_corner_alpha_max[RefinementRig.REFINEMENTS[refinement_index]] = PreviewSupport.corner_alpha_max(candidate_sheets[refinement_index])
		if not PreviewSupport.save_png(self, candidate_sheets[refinement_index], CANDIDATE_PATHS[refinement_index], "motion refinement %s" % RefinementRig.REFINEMENTS[refinement_index]):
			return
	if not PreviewSupport.save_png(self, comparison, COMPARISON_PATH, "motion refinement comparison board"):
		return

	var locked_base_profile := rig.candidate_profile(RefinementRig.SELECTED_BASE_PROFILE)
	var report := {
		"schema_version": 1,
		"asset_id": "player_motion_refinement_a_candidates",
		"selected_base_profile": RefinementRig.SELECTED_BASE_PROFILE,
		"locked_base_profile": locked_base_profile,
		"camera_pitch_degrees": CAMERA_PITCH_DEGREES,
		"preview_yaw_degrees": PREVIEW_YAW_DEGREES,
		"refinement_ids": RefinementRig.REFINEMENTS,
		"refinement_profiles": refinement_profiles,
		"mechanics_ranges": mechanics_ranges,
		"gait_frames_per_refinement": GAIT_FRAME_COUNT,
		"recoil_frames_per_refinement": RECOIL_FRAME_COUNT,
		"recoil_sample_phases": RECOIL_PHASES,
		"sample_count": RefinementRig.REFINEMENTS.size() * (GAIT_FRAME_COUNT + RECOIL_FRAME_COUNT),
		"contact_tolerance": RefinementRig.CONTACT_TOLERANCE,
		"max_firing_hand_error": max_firing_error,
		"max_support_hand_error": max_support_error,
		"max_stock_contact_error": max_stock_error,
		"minimum_foot_height": minimum_foot_height,
		"declared_floor_height": rig.floor_height(),
		"minimum_opaque_visible_ratio": minimum_opaque_visible_ratio,
		"runtime_corner_alpha_max": PreviewSupport.corner_alpha_max(runtime_atlas),
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
		push_error("Could not write refinement metrics: " + REPORT_PATH)
		quit(1)
		return
	report_file.store_string(JSON.stringify(report, "  ") + "\n")
	report_file.close()
	viewport.queue_free()
	await process_frame
	print("RENDER PASS: PlayerMotionRefinementCandidates 36 samples, exact 45-degree camera, profile A locked")
	quit(0)

func _accumulate_metrics(rig: Node, target: Dictionary) -> void:
	var mechanics: Dictionary = rig.current_mechanics()
	target["max_abs_hip_shift"] = maxf(float(target["max_abs_hip_shift"]), absf(float(mechanics["hip_shift_x"])))
	target["max_abs_pelvis_yaw_degrees"] = maxf(float(target["max_abs_pelvis_yaw_degrees"]), absf(float(mechanics["pelvis_yaw_degrees"])))
	target["max_abs_torso_yaw_degrees"] = maxf(float(target["max_abs_torso_yaw_degrees"]), absf(float(mechanics["torso_yaw_degrees"])))
	target["max_abs_lateral_lean_degrees"] = maxf(float(target["max_abs_lateral_lean_degrees"]), absf(float(mechanics["lateral_lean_degrees"])))
	target["min_recoil_curve"] = minf(float(target["min_recoil_curve"]), float(mechanics["recoil_curve"]))
	target["max_recoil_curve"] = maxf(float(target["max_recoil_curve"]), float(mechanics["recoil_curve"]))
