extends SceneTree

const RefinementRig = preload("res://scripts/art/PlayerMotionRefinementRig.gd")
const PreviewSupport = preload("res://scripts/art/PlayerMotionPreviewRenderSupport.gd")
const BakeMaterials = preload("res://scripts/art/PlayerM2BakeMaterials.gd")
const CANDIDATE_MESH_PATH := "res://assets/art/source/player/player_production_lod_topology_candidate_v1.res"
const COMPOSITE_ATLAS_PATH := "res://assets/art/actors/player/technical_previews/player_m2_ready_120yaw_composite.png"
const BODY_ATLAS_PATH := "res://assets/art/actors/player/technical_previews/player_m2_ready_120yaw_body.png"
const WEAPON_ATLAS_PATH := "res://assets/art/actors/player/technical_previews/player_m2_ready_120yaw_weapon.png"
const BOARD_PATH := "res://docs/art/previews/characters-combat/player-m2-ready-120yaw-review-v1.png"
const REPORT_PATH := "res://docs/art/reviews/characters-combat-player-m2-ready-120yaw-metrics-v1.json"
const PARTIAL_ATLAS_PATTERN := "res://.godot/player_m2_ready_120yaw_%s_batch_%02d.png"
const PARTIAL_REPORT_PATTERN := "res://.godot/player_m2_ready_120yaw_batch_%02d.json"
const KEY_FRAME_PATTERN := "res://.godot/player_m2_ready_120yaw_key_%03d.png"
const SOURCE_SIZE := Vector2i(192, 192)
const RUNTIME_FRAME_SIZE := Vector2i(64, 64)
const BOARD_FRAME_SIZE := Vector2i(192, 192)
const ATLAS_COLUMNS := 20
const ATLAS_ROWS := 6
const BOARD_COLUMNS := 6
const BOARD_ROWS := 2
const YAW_FRAME_COUNT := 120
const YAW_STEP_DEGREES := 3.0
const KEY_ANGLE_INTERVAL := 10
const BATCH_SIZE := 12
const BATCH_COUNT := 10
const BATCH_SCHEMA_VERSION := 1
const CAMERA_PITCH_DEGREES := 45.0
const CAMERA_DISTANCE := 8.5
const BODY_HEIGHT := 4.65
const NORMALIZED_BODY_HEIGHT := 1.988064
const SELECTED_MATERIAL := "M2"
const SELECTED_POSE := "READY"
const SELECTED_REFINEMENT := "A2"
const LAYER_IDS := ["composite", "body", "weapon"]
const PREVIEW_BACKGROUND := Color("061019")
const M2_ACCENT := Color("3da7ff")
const WEAPON_ACCENT := Color("c66a32")

func _initialize() -> void:
	var arguments := OS.get_cmdline_user_args()
	if arguments.has("--assemble"):
		_assemble_batches()
		return
	var batch_index := _batch_index_from_arguments(arguments)
	if batch_index < 0 or batch_index >= BATCH_COUNT:
		_fail("Use -- --batch-index=0..9 to render one recoverable batch, then -- --assemble")
		return
	if DisplayServer.get_name().to_lower() == "headless":
		_fail("M2 120-yaw 3D batches require Windows/OpenGL3; use headless only for --assemble")
		return
	await _render_batch(batch_index)

func _batch_index_from_arguments(arguments: PackedStringArray) -> int:
	for argument in arguments:
		if argument.begins_with("--batch-index="):
			return argument.trim_prefix("--batch-index=").to_int()
	return -1

func _render_batch(batch_index: int) -> void:
	var started_msec := Time.get_ticks_msec()
	var candidate_mesh := ResourceLoader.load(CANDIDATE_MESH_PATH, "ArrayMesh") as ArrayMesh
	if candidate_mesh == null:
		_fail("M2 120-yaw bake candidate mesh is missing")
		return
	var viewport := PreviewSupport.build_viewport(
		"PlayerM2Ready120YawViewport",
		SOURCE_SIZE,
		BODY_HEIGHT,
		CAMERA_PITCH_DEGREES,
		CAMERA_DISTANCE,
		true,
		false
	)
	var world_environment := viewport.get_node_or_null("WorldEnvironment") as WorldEnvironment
	if world_environment != null and world_environment.environment != null:
		world_environment.environment.ssao_enabled = false
	root.add_child(viewport)
	var rig := RefinementRig.new()
	viewport.add_child(rig)
	if not rig.initialize():
		_fail("Could not initialize the approved A2 review rig")
		return
	if not rig.weapon_attachment is BoneAttachment3D:
		_fail("Independent rifle is not driven by BoneAttachment3D")
		return
	if rig.body_mesh == rig.weapon_attachment or rig.body_mesh.is_ancestor_of(rig.weapon_attachment):
		_fail("Body and rifle are not separate 3D source objects")
		return
	rig.body_mesh.mesh = candidate_mesh
	rig.body_mesh.material_override = BakeMaterials.body_material()
	_set_weapon_material(rig.weapon_attachment, BakeMaterials.weapon_material())
	rig.scale = Vector3.ONE * (BODY_HEIGHT / NORMALIZED_BODY_HEIGHT)
	rig.apply_refinement(SELECTED_REFINEMENT, 0.0, -1.0)

	var partial_atlases := {}
	var minimum_opaque_ratios := {}
	var minimum_mean_visible_alphas := {}
	var minimum_maximum_alphas := {}
	for layer_id in LAYER_IDS:
		var partial := Image.create_empty(BATCH_SIZE * RUNTIME_FRAME_SIZE.x, RUNTIME_FRAME_SIZE.y, false, Image.FORMAT_RGBA8)
		partial.fill(Color(0, 0, 0, 0))
		partial_atlases[layer_id] = partial
		minimum_opaque_ratios[layer_id] = 1.0
		minimum_mean_visible_alphas[layer_id] = 1.0
		minimum_maximum_alphas[layer_id] = 1.0
	var sample_metrics: Array[Dictionary] = []
	var batch_start := batch_index * BATCH_SIZE
	for local_index in range(BATCH_SIZE):
		var yaw_index := batch_start + local_index
		var yaw_degrees := float(yaw_index) * YAW_STEP_DEGREES
		rig.rotation_degrees.y = yaw_degrees
		var layer_opaque_ratios := {}
		var layer_mean_visible_alphas := {}
		var layer_maximum_alphas := {}
		for layer_id in LAYER_IDS:
			_set_layer_visibility(rig, layer_id)
			var source := await _capture(viewport, layer_id, yaw_index)
			if source.is_empty():
				return
			var opaque_ratio := PreviewSupport.opaque_visible_ratio(source)
			var alpha_metrics := _visible_alpha_metrics(source)
			var required_opaque_ratio := 0.75 if layer_id == "weapon" else 0.85
			var required_mean_alpha := 0.85 if layer_id == "weapon" else 0.70
			if opaque_ratio <= required_opaque_ratio or float(alpha_metrics["mean_visible_alpha"]) <= required_mean_alpha or float(alpha_metrics["maximum_alpha"]) < 0.99:
				_fail("Alpha gate failed in %s layer at yaw %.1f: opaque_ratio=%.4f mean=%.4f max=%.4f" % [layer_id, yaw_degrees, opaque_ratio, alpha_metrics["mean_visible_alpha"], alpha_metrics["maximum_alpha"]])
				return
			minimum_opaque_ratios[layer_id] = minf(float(minimum_opaque_ratios[layer_id]), opaque_ratio)
			minimum_mean_visible_alphas[layer_id] = minf(float(minimum_mean_visible_alphas[layer_id]), float(alpha_metrics["mean_visible_alpha"]))
			minimum_maximum_alphas[layer_id] = minf(float(minimum_maximum_alphas[layer_id]), float(alpha_metrics["maximum_alpha"]))
			layer_opaque_ratios[layer_id] = opaque_ratio
			layer_mean_visible_alphas[layer_id] = alpha_metrics["mean_visible_alpha"]
			layer_maximum_alphas[layer_id] = alpha_metrics["maximum_alpha"]
			var runtime_frame := source.duplicate()
			runtime_frame.resize(RUNTIME_FRAME_SIZE.x, RUNTIME_FRAME_SIZE.y, Image.INTERPOLATE_LANCZOS)
			var partial_atlas: Image = partial_atlases[layer_id]
			partial_atlas.blit_rect(runtime_frame, Rect2i(Vector2i.ZERO, RUNTIME_FRAME_SIZE), Vector2i(local_index * RUNTIME_FRAME_SIZE.x, 0))
			if layer_id == "composite" and yaw_index % KEY_ANGLE_INTERVAL == 0:
				if not PreviewSupport.save_png(self, source, KEY_FRAME_PATTERN % yaw_index, "M2 key-angle frame"):
					return
		sample_metrics.append({
			"yaw_index": yaw_index,
			"yaw_degrees": yaw_degrees,
			"layer_opaque_visible_ratios": layer_opaque_ratios,
			"layer_mean_visible_alphas": layer_mean_visible_alphas,
			"layer_maximum_alphas": layer_maximum_alphas,
			"firing_hand_error": rig.firing_hand_error(),
			"support_hand_error": rig.support_hand_error(),
			"stock_contact_error": rig.stock_contact_error(),
		})

	for layer_id in LAYER_IDS:
		if not PreviewSupport.save_png(self, partial_atlases[layer_id], PARTIAL_ATLAS_PATTERN % [layer_id, batch_index], "%s batch atlas" % layer_id):
			return
	var elapsed_msec := Time.get_ticks_msec() - started_msec
	var partial_report := {
		"batch_schema_version": BATCH_SCHEMA_VERSION,
		"batch_index": batch_index,
		"batch_start_yaw_index": batch_start,
		"batch_size": BATCH_SIZE,
		"camera_pitch_degrees": CAMERA_PITCH_DEGREES,
		"yaw_step_degrees": YAW_STEP_DEGREES,
		"selected_material": SELECTED_MATERIAL,
		"selected_pose": SELECTED_POSE,
		"selected_refinement": SELECTED_REFINEMENT,
		"layer_ids": LAYER_IDS,
		"candidate_vertices": candidate_mesh.surface_get_array_len(0),
		"candidate_indices": candidate_mesh.surface_get_array_index_len(0),
		"sample_metrics": sample_metrics,
		"minimum_opaque_visible_ratios": minimum_opaque_ratios,
		"minimum_mean_visible_alphas": minimum_mean_visible_alphas,
		"minimum_maximum_alphas": minimum_maximum_alphas,
		"max_firing_hand_error": rig.firing_hand_error(),
		"max_support_hand_error": rig.support_hand_error(),
		"max_stock_contact_error": rig.stock_contact_error(),
		"body_weapon_source_objects_separate": true,
		"weapon_attachment": "BoneAttachment3D:firing_hand",
		"elapsed_msec": elapsed_msec,
	}
	if not _write_json(PARTIAL_REPORT_PATTERN % batch_index, partial_report):
		return
	viewport.queue_free()
	await process_frame
	print("RENDER PASS: PlayerM2Ready120YawBake batch=%d angles=%d elapsed_msec=%d" % [batch_index, BATCH_SIZE, elapsed_msec])
	quit(0)

func _assemble_batches() -> void:
	var atlas_size := Vector2i(ATLAS_COLUMNS * RUNTIME_FRAME_SIZE.x, ATLAS_ROWS * RUNTIME_FRAME_SIZE.y)
	var atlases := {}
	for layer_id in LAYER_IDS:
		var atlas := Image.create_empty(atlas_size.x, atlas_size.y, false, Image.FORMAT_RGBA8)
		atlas.fill(Color(0, 0, 0, 0))
		atlases[layer_id] = atlas
	var minimum_opaque_ratios := {"composite": 1.0, "body": 1.0, "weapon": 1.0}
	var minimum_mean_visible_alphas := {"composite": 1.0, "body": 1.0, "weapon": 1.0}
	var minimum_maximum_alphas := {"composite": 1.0, "body": 1.0, "weapon": 1.0}
	var max_firing_error := 0.0
	var max_support_error := 0.0
	var max_stock_error := 0.0
	var total_batch_render_msec := 0
	var sample_count := 0
	for batch_index in range(BATCH_COUNT):
		var report := _read_json_dictionary(PARTIAL_REPORT_PATTERN % batch_index)
		if not _valid_partial_report(report, batch_index):
			_fail("Missing, invalid, or stale M2 120-yaw batch report: %d" % batch_index)
			return
		for layer_id in LAYER_IDS:
			var partial := Image.load_from_file(ProjectSettings.globalize_path(PARTIAL_ATLAS_PATTERN % [layer_id, batch_index]))
			if partial.is_empty() or partial.get_size() != Vector2i(BATCH_SIZE * RUNTIME_FRAME_SIZE.x, RUNTIME_FRAME_SIZE.y):
				_fail("Missing or invalid %s partial atlas for batch %d" % [layer_id, batch_index])
				return
			var atlas: Image = atlases[layer_id]
			for local_index in range(BATCH_SIZE):
				var yaw_index := batch_index * BATCH_SIZE + local_index
				var destination_cell := Vector2i(yaw_index % ATLAS_COLUMNS, yaw_index / ATLAS_COLUMNS)
				atlas.blit_rect(
					partial,
					Rect2i(Vector2i(local_index * RUNTIME_FRAME_SIZE.x, 0), RUNTIME_FRAME_SIZE),
					destination_cell * RUNTIME_FRAME_SIZE
				)
			var batch_ratios: Dictionary = report["minimum_opaque_visible_ratios"] as Dictionary
			var batch_means: Dictionary = report["minimum_mean_visible_alphas"] as Dictionary
			var batch_maximums: Dictionary = report["minimum_maximum_alphas"] as Dictionary
			minimum_opaque_ratios[layer_id] = minf(float(minimum_opaque_ratios[layer_id]), float(batch_ratios[layer_id]))
			minimum_mean_visible_alphas[layer_id] = minf(float(minimum_mean_visible_alphas[layer_id]), float(batch_means[layer_id]))
			minimum_maximum_alphas[layer_id] = minf(float(minimum_maximum_alphas[layer_id]), float(batch_maximums[layer_id]))
		sample_count += (report["sample_metrics"] as Array).size()
		max_firing_error = maxf(max_firing_error, float(report["max_firing_hand_error"]))
		max_support_error = maxf(max_support_error, float(report["max_support_hand_error"]))
		max_stock_error = maxf(max_stock_error, float(report["max_stock_contact_error"]))
		total_batch_render_msec += int(report["elapsed_msec"])
	if sample_count != YAW_FRAME_COUNT:
		_fail("Assembled M2 120-yaw sample count is incorrect")
		return

	var board := Image.create_empty(BOARD_COLUMNS * BOARD_FRAME_SIZE.x, BOARD_ROWS * BOARD_FRAME_SIZE.y, false, Image.FORMAT_RGBA8)
	board.fill(PREVIEW_BACKGROUND)
	for key_index in range(12):
		var yaw_index := key_index * KEY_ANGLE_INTERVAL
		var key_frame := Image.load_from_file(ProjectSettings.globalize_path(KEY_FRAME_PATTERN % yaw_index))
		if key_frame.is_empty() or key_frame.get_size() != BOARD_FRAME_SIZE:
			_fail("Missing M2 key-angle review frame: %d" % yaw_index)
			return
		var cell := Vector2i(key_index % BOARD_COLUMNS, key_index / BOARD_COLUMNS)
		var position := cell * BOARD_FRAME_SIZE
		board.blend_rect(key_frame, Rect2i(Vector2i.ZERO, BOARD_FRAME_SIZE), position)
		board.fill_rect(Rect2i(position, Vector2i(BOARD_FRAME_SIZE.x, 4)), M2_ACCENT)
		board.fill_rect(Rect2i(position + Vector2i(0, 4), Vector2i(12 + key_index * 6, 3)), WEAPON_ACCENT)

	if not PreviewSupport.save_png(self, atlases["composite"], COMPOSITE_ATLAS_PATH, "M2 composite 120-yaw atlas"):
		return
	if not PreviewSupport.save_png(self, atlases["body"], BODY_ATLAS_PATH, "M2 body-only 120-yaw atlas"):
		return
	if not PreviewSupport.save_png(self, atlases["weapon"], WEAPON_ATLAS_PATH, "M2 weapon-only 120-yaw atlas"):
		return
	if not PreviewSupport.save_png(self, board, BOARD_PATH, "M2 120-yaw key-angle board"):
		return
	var file_sizes := {
		"composite_atlas": _file_size(COMPOSITE_ATLAS_PATH),
		"body_atlas": _file_size(BODY_ATLAS_PATH),
		"weapon_atlas": _file_size(WEAPON_ATLAS_PATH),
		"review_board": _file_size(BOARD_PATH),
	}
	var total_atlas_bytes := int(file_sizes["composite_atlas"]) + int(file_sizes["body_atlas"]) + int(file_sizes["weapon_atlas"])
	var report := {
		"schema_version": 1,
		"asset_id": "player_m2_ready_120yaw_bake",
		"selected_material": SELECTED_MATERIAL,
		"selected_pose": SELECTED_POSE,
		"selected_refinement": SELECTED_REFINEMENT,
		"camera_pitch_degrees": CAMERA_PITCH_DEGREES,
		"yaw_frame_count": YAW_FRAME_COUNT,
		"yaw_step_degrees": YAW_STEP_DEGREES,
		"yaw_range_degrees": {"start": 0.0, "end": float(YAW_FRAME_COUNT - 1) * YAW_STEP_DEGREES, "step": YAW_STEP_DEGREES},
		"sample_count": sample_count,
		"atlas_columns": ATLAS_COLUMNS,
		"atlas_rows": ATLAS_ROWS,
		"runtime_frame_size": {"width": RUNTIME_FRAME_SIZE.x, "height": RUNTIME_FRAME_SIZE.y},
		"layer_ids": LAYER_IDS,
		"minimum_composite_opaque_visible_ratio": minimum_opaque_ratios["composite"],
		"minimum_body_opaque_visible_ratio": minimum_opaque_ratios["body"],
		"minimum_weapon_opaque_visible_ratio": minimum_opaque_ratios["weapon"],
		"minimum_composite_mean_visible_alpha": minimum_mean_visible_alphas["composite"],
		"minimum_body_mean_visible_alpha": minimum_mean_visible_alphas["body"],
		"minimum_weapon_mean_visible_alpha": minimum_mean_visible_alphas["weapon"],
		"minimum_composite_maximum_alpha": minimum_maximum_alphas["composite"],
		"minimum_body_maximum_alpha": minimum_maximum_alphas["body"],
		"minimum_weapon_maximum_alpha": minimum_maximum_alphas["weapon"],
		"composite_corner_alpha_max": PreviewSupport.corner_alpha_max(atlases["composite"]),
		"body_corner_alpha_max": PreviewSupport.corner_alpha_max(atlases["body"]),
		"weapon_corner_alpha_max": PreviewSupport.corner_alpha_max(atlases["weapon"]),
		"contact_tolerance": RefinementRig.CONTACT_TOLERANCE,
		"max_firing_hand_error": max_firing_error,
		"max_support_hand_error": max_support_error,
		"max_stock_contact_error": max_stock_error,
		"candidate_vertices": 47326,
		"candidate_indices": 283944,
		"topology_classification": "automatic LOD topology candidate for offline sprite baking; not hand-authored production retopology",
		"body_weapon_source_objects_separate": true,
		"weapon_attachment": "BoneAttachment3D:firing_hand",
		"composite_depth_source": "single 3D SubViewport depth buffer",
		"runtime_recommendation": "use composite atlas for correct per-pixel body/weapon depth",
		"diagnostic_layer_limit": "body-only and weapon-only captures preserve transforms but simple alpha recomposition cannot reconstruct per-pixel 3D occlusion",
		"batch_count": BATCH_COUNT,
		"batch_size": BATCH_SIZE,
		"total_batch_render_msec": total_batch_render_msec,
		"file_sizes_bytes": file_sizes,
		"total_atlas_bytes": total_atlas_bytes,
		"production_integration": false,
	}
	if not _write_json(REPORT_PATH, report):
		return
	print("ASSEMBLE PASS: PlayerM2Ready120YawBake 120 angles, three_atlas_bytes=%d, batch_render_msec=%d" % [total_atlas_bytes, total_batch_render_msec])
	quit(0)

func _set_layer_visibility(rig: Node, layer_id: String) -> void:
	match layer_id:
		"composite":
			rig.body_mesh.visible = true
			rig.weapon_attachment.visible = true
		"body":
			rig.body_mesh.visible = true
			rig.weapon_attachment.visible = false
		"weapon":
			rig.body_mesh.visible = false
			rig.weapon_attachment.visible = true

func _visible_alpha_metrics(image: Image) -> Dictionary:
	var visible_pixels := 0
	var visible_alpha_sum := 0.0
	var maximum_alpha := 0.0
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			var alpha := image.get_pixel(x, y).a
			if alpha <= 0.05:
				continue
			visible_pixels += 1
			visible_alpha_sum += alpha
			maximum_alpha = maxf(maximum_alpha, alpha)
	return {
		"mean_visible_alpha": visible_alpha_sum / maxf(float(visible_pixels), 1.0),
		"maximum_alpha": maximum_alpha,
	}

func _capture(viewport: SubViewport, layer_id: String, yaw_index: int) -> Image:
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	await process_frame
	await RenderingServer.frame_post_draw
	var source := viewport.get_texture().get_image()
	if source.is_empty():
		_fail("Empty %s capture at yaw index %d" % [layer_id, yaw_index])
		return Image.new()
	source.convert(Image.FORMAT_RGBA8)
	return source

func _set_weapon_material(node: Node, material: Material) -> void:
	if node is MeshInstance3D:
		(node as MeshInstance3D).material_override = material
	for child in node.get_children():
		_set_weapon_material(child, material)

func _valid_partial_report(report: Dictionary, batch_index: int) -> bool:
	var opaque_ratios: Dictionary = report.get("minimum_opaque_visible_ratios", {}) as Dictionary
	var mean_alphas: Dictionary = report.get("minimum_mean_visible_alphas", {}) as Dictionary
	var maximum_alphas: Dictionary = report.get("minimum_maximum_alphas", {}) as Dictionary
	return (
		int(report.get("batch_schema_version", 0)) == BATCH_SCHEMA_VERSION
		and int(report.get("batch_index", -1)) == batch_index
		and int(report.get("batch_start_yaw_index", -1)) == batch_index * BATCH_SIZE
		and int(report.get("batch_size", 0)) == BATCH_SIZE
		and float(report.get("camera_pitch_degrees", 0.0)) == CAMERA_PITCH_DEGREES
		and float(report.get("yaw_step_degrees", 0.0)) == YAW_STEP_DEGREES
		and report.get("selected_material", "") == SELECTED_MATERIAL
		and report.get("selected_pose", "") == SELECTED_POSE
		and report.get("selected_refinement", "") == SELECTED_REFINEMENT
		and report.get("layer_ids", []) == LAYER_IDS
		and int(report.get("candidate_vertices", 0)) == 47326
		and int(report.get("candidate_indices", 0)) == 283944
		and (report.get("sample_metrics", []) as Array).size() == BATCH_SIZE
		and _has_all_layer_ids(opaque_ratios)
		and _has_all_layer_ids(mean_alphas)
		and _has_all_layer_ids(maximum_alphas)
		and report.get("body_weapon_source_objects_separate", false)
		and int(report.get("elapsed_msec", 0)) > 0
	)

func _has_all_layer_ids(value: Dictionary) -> bool:
	if value.size() != LAYER_IDS.size():
		return false
	for layer_id in LAYER_IDS:
		if not value.has(layer_id):
			return false
	return true

func _file_size(path: String) -> int:
	return FileAccess.get_file_as_bytes(path).size()

func _write_json(path: String, value: Dictionary) -> bool:
	var absolute := ProjectSettings.globalize_path(path)
	DirAccess.make_dir_recursive_absolute(absolute.get_base_dir())
	var file := FileAccess.open(absolute, FileAccess.WRITE)
	if file == null:
		_fail("Could not write JSON: " + path)
		return false
	file.store_string(JSON.stringify(value, "  ") + "\n")
	file.close()
	return true

func _read_json_dictionary(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		return {}
	return parsed as Dictionary

func _fail(message: String) -> void:
	push_error(message)
	quit(1)
