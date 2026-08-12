extends SceneTree

const RefinementRig = preload("res://scripts/art/PlayerMotionRefinementRig.gd")
const PreviewSupport = preload("res://scripts/art/PlayerMotionPreviewRenderSupport.gd")
const SOURCE_MESH_PATH := "res://assets/art/source/player/player_motion_review_skinned_mesh_v1.res"
const CANDIDATE_MESH_PATH := "res://assets/art/source/player/player_production_lod_topology_candidate_v1.res"
const BUILD_REPORT_PATH := "res://.godot/player_production_lod_topology_candidate_v1.json"
const RUNTIME_PATH := "res://assets/art/actors/player/technical_previews/player_production_material_candidates.png"
const MATERIAL_BOARD_PATH := "res://docs/art/previews/characters-combat/player-production-material-comparison-v1.png"
const TOPOLOGY_BOARD_PATH := "res://docs/art/previews/characters-combat/player-production-topology-comparison-v1.png"
const MATERIAL_SHEET_PATTERN := "res://docs/art/previews/characters-combat/player-production-material-%s-v1.png"
const REPORT_PATH := "res://docs/art/reviews/characters-combat-player-production-topology-material-metrics-v1.json"
const PARTIAL_TOPOLOGY_REPORT_PATH := "res://.godot/player_production_topology_preview_v1.json"
const PARTIAL_TOPOLOGY_BOARD_PATH := "res://.godot/player_production_topology_preview_v1.png"
const PARTIAL_MATERIAL_RUNTIME_PATTERN := "res://.godot/player_production_material_%s_runtime_v1.png"
const PARTIAL_MATERIAL_BOARD_PATTERN := "res://.godot/player_production_material_%s_board_v1.png"
const PARTIAL_MATERIAL_REPORT_PATTERN := "res://.godot/player_production_material_%s_v1.json"
const SOURCE_SIZE := Vector2i(192, 192)
const RUNTIME_FRAME_SIZE := Vector2i(64, 64)
const BOARD_FRAME_SIZE := Vector2i(192, 192)
const CAMERA_PITCH_DEGREES := 45.0
const CAMERA_DISTANCE := 8.5
const BODY_HEIGHT := 4.65
const NORMALIZED_BODY_HEIGHT := 1.988064
const TOPOLOGY_YAW_COUNT := 12
const TOPOLOGY_YAW_STEP_DEGREES := 30.0
const MATERIAL_YAWS := [0.0, 90.0, 180.0, 270.0]
const MATERIAL_IDS := ["M1", "M2", "M3"]
const MINIMUM_SILHOUETTE_IOU := 0.97
const PREVIEW_BACKGROUND := Color("061019")
const SOURCE_COLOR := Color("aab4be")
const CANDIDATE_COLOR := Color("33fff2")
const MATERIAL_COLORS := {
	"M1": Color("33fff2"),
	"M2": Color("aeb8bc"),
	"M3": Color("f559bf"),
}

const MATERIAL_SHADER := """
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec4 base_color : source_color;
uniform vec4 secondary_color : source_color;
uniform vec4 accent_color : source_color;
uniform vec4 micro_color : source_color;
uniform float metallic_level = 0.1;
uniform float roughness_level = 0.55;
uniform float wear_strength = 0.1;
uniform float pattern_scale = 90.0;
uniform float emission_strength = 1.0;
uniform float secondary_emission_strength = 0.0;

varying vec3 object_position;

float line_mask(float value, float center, float half_width) {
	return 1.0 - smoothstep(half_width, half_width + 0.012, abs(value - center));
}

float hash31(vec3 p) {
	return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453123);
}

void vertex() {
	object_position = VERTEX;
}

void fragment() {
	float vertical_panel = smoothstep(0.15, 0.55, abs(object_position.x));
	float torso_panel = smoothstep(0.78, 1.12, object_position.y) * (1.0 - smoothstep(1.40, 1.72, object_position.y));
	float lower_panel = 1.0 - smoothstep(0.58, 0.90, object_position.y);
	float panel_mix = clamp(0.28 * vertical_panel + 0.38 * torso_panel + 0.22 * lower_panel, 0.0, 0.72);
	float visor = line_mask(object_position.y, 1.68, 0.018) * (1.0 - smoothstep(0.12, 0.48, abs(object_position.x)));
	float chest = line_mask(object_position.y, 1.17, 0.016) * (1.0 - smoothstep(0.18, 0.52, abs(object_position.x)));
	float calf = line_mask(object_position.y, 0.38, 0.012) * smoothstep(0.10, 0.24, abs(object_position.x));
	float energy_mask = clamp(max(visor, max(chest * 0.82, calf * 0.52)), 0.0, 1.0);
	float secondary_energy_mask = line_mask(object_position.y, 0.86, 0.014) * (1.0 - smoothstep(0.16, 0.52, abs(object_position.x)));
	float weave = 0.5 + 0.5 * sin((object_position.x + object_position.z) * pattern_scale) * sin((object_position.x - object_position.z) * pattern_scale * 0.73);
	float wear = hash31(floor(object_position * 42.0));
	vec3 color = mix(base_color.rgb, secondary_color.rgb, panel_mix);
	color = mix(color, micro_color.rgb, weave * 0.075);
	color = mix(color, vec3(0.58), step(0.965 - wear_strength * 0.18, wear) * wear_strength * 0.22);
	color = mix(color, accent_color.rgb, energy_mask);
	color = mix(color, micro_color.rgb, secondary_energy_mask);
	ALBEDO = color;
	METALLIC = clamp(metallic_level + panel_mix * 0.16, 0.0, 1.0);
	ROUGHNESS = clamp(roughness_level + weave * 0.08 - energy_mask * 0.30, 0.18, 0.92);
	EMISSION = accent_color.rgb * energy_mask * emission_strength + micro_color.rgb * secondary_energy_mask * secondary_emission_strength;
}
"""

func _initialize() -> void:
	var arguments := OS.get_cmdline_user_args()
	if arguments.has("--assemble"):
		_assemble()
		return
	if DisplayServer.get_name().to_lower() == "headless":
		_fail("3D topology/material capture requires the Windows display driver; use headless only for --assemble")
		return
	if arguments.has("--topology"):
		await _render_topology_comparison()
		return
	var material_id := _material_id_from_arguments(arguments)
	if material_id.is_empty():
		_fail("Use -- --topology, -- --material=M1|M2|M3, or -- --assemble")
		return
	await _render_material(material_id)

func _material_id_from_arguments(arguments: PackedStringArray) -> String:
	for argument in arguments:
		if argument.begins_with("--material="):
			var material_id := argument.trim_prefix("--material=").to_upper()
			if material_id in MATERIAL_IDS:
				return material_id
	return ""

func _render_topology_comparison() -> void:
	var source_mesh := ResourceLoader.load(SOURCE_MESH_PATH, "ArrayMesh") as ArrayMesh
	var candidate_mesh := ResourceLoader.load(CANDIDATE_MESH_PATH, "ArrayMesh") as ArrayMesh
	if source_mesh == null or candidate_mesh == null:
		_fail("Source or topology-candidate mesh is missing")
		return
	var board := Image.create_empty(6 * BOARD_FRAME_SIZE.x, 4 * BOARD_FRAME_SIZE.y, false, Image.FORMAT_RGBA8)
	board.fill(PREVIEW_BACKGROUND)
	var source_viewports: Array[SubViewport] = []
	var candidate_viewports: Array[SubViewport] = []
	for yaw_index in range(TOPOLOGY_YAW_COUNT):
		var yaw_degrees := float(yaw_index) * TOPOLOGY_YAW_STEP_DEGREES
		var source_viewport_and_rig := _build_rig_viewport_with_rig("TopologySource%d" % yaw_index, source_mesh, yaw_degrees, _neutral_material(SOURCE_COLOR))
		if source_viewport_and_rig.is_empty():
			return
		var candidate_viewport_and_rig := _build_rig_viewport_with_rig("TopologyCandidate%d" % yaw_index, candidate_mesh, yaw_degrees, _neutral_material(SOURCE_COLOR))
		if candidate_viewport_and_rig.is_empty():
			return
		source_viewport_and_rig["rig"].weapon_attachment.visible = false
		candidate_viewport_and_rig["rig"].weapon_attachment.visible = false
		source_viewports.append(source_viewport_and_rig["viewport"])
		candidate_viewports.append(candidate_viewport_and_rig["viewport"])
	await process_frame
	await RenderingServer.frame_post_draw
	var yaw_metrics: Array[Dictionary] = []
	var minimum_iou := 1.0
	for yaw_index in range(TOPOLOGY_YAW_COUNT):
		var source_image := _capture_ready_viewport(source_viewports[yaw_index], "source topology", yaw_index)
		var candidate_image := _capture_ready_viewport(candidate_viewports[yaw_index], "candidate topology", yaw_index)
		if source_image.is_empty() or candidate_image.is_empty():
			return
		var iou := _silhouette_iou(source_image, candidate_image)
		minimum_iou = minf(minimum_iou, iou)
		var cell := Vector2i(yaw_index % 6, yaw_index / 6)
		var source_position := cell * BOARD_FRAME_SIZE
		var candidate_position := source_position + Vector2i(0, 2 * BOARD_FRAME_SIZE.y)
		board.blend_rect(source_image, Rect2i(Vector2i.ZERO, BOARD_FRAME_SIZE), source_position)
		board.blend_rect(candidate_image, Rect2i(Vector2i.ZERO, BOARD_FRAME_SIZE), candidate_position)
		board.fill_rect(Rect2i(source_position, Vector2i(BOARD_FRAME_SIZE.x, 4)), SOURCE_COLOR)
		board.fill_rect(Rect2i(candidate_position, Vector2i(BOARD_FRAME_SIZE.x, 4)), CANDIDATE_COLOR)
		yaw_metrics.append({"yaw_degrees": float(yaw_index) * TOPOLOGY_YAW_STEP_DEGREES, "silhouette_iou": iou})
	if minimum_iou < MINIMUM_SILHOUETTE_IOU:
		_fail("Automatic LOD topology candidate failed silhouette IoU: %.6f" % minimum_iou)
		return
	if not PreviewSupport.save_png(self, board, PARTIAL_TOPOLOGY_BOARD_PATH, "topology comparison board"):
		return
	var report := {
		"camera_pitch_degrees": CAMERA_PITCH_DEGREES,
		"yaw_count": TOPOLOGY_YAW_COUNT,
		"yaw_step_degrees": TOPOLOGY_YAW_STEP_DEGREES,
		"minimum_required_silhouette_iou": MINIMUM_SILHOUETTE_IOU,
		"minimum_silhouette_iou": minimum_iou,
		"yaw_metrics": yaw_metrics,
	}
	if not _write_json(PARTIAL_TOPOLOGY_REPORT_PATH, report):
		return
	print("RENDER PASS: PlayerProductionTopologyComparison minimum_iou=%.6f" % minimum_iou)
	quit(0)

func _render_material(material_id: String) -> void:
	var candidate_mesh := ResourceLoader.load(CANDIDATE_MESH_PATH, "ArrayMesh") as ArrayMesh
	if candidate_mesh == null:
		_fail("Topology candidate is missing")
		return
	var runtime_row := Image.create_empty(4 * RUNTIME_FRAME_SIZE.x, RUNTIME_FRAME_SIZE.y, false, Image.FORMAT_RGBA8)
	runtime_row.fill(Color(0, 0, 0, 0))
	var board_row := Image.create_empty(4 * BOARD_FRAME_SIZE.x, BOARD_FRAME_SIZE.y, false, Image.FORMAT_RGBA8)
	board_row.fill(PREVIEW_BACKGROUND)
	var viewports: Array[SubViewport] = []
	var rigs: Array[Node] = []
	for yaw_degrees in MATERIAL_YAWS:
		var viewport_and_rig := _build_rig_viewport_with_rig("Material%sYaw%d" % [material_id, int(yaw_degrees)], candidate_mesh, yaw_degrees, _material(material_id))
		if viewport_and_rig.is_empty():
			return
		var rig: Node = viewport_and_rig["rig"]
		_set_weapon_material(rig.weapon_attachment, _weapon_material(material_id))
		viewports.append(viewport_and_rig["viewport"])
		rigs.append(rig)
	await process_frame
	await RenderingServer.frame_post_draw
	var minimum_opaque_ratio := 1.0
	var max_firing_error := 0.0
	var max_support_error := 0.0
	var max_stock_error := 0.0
	var visible_pixel_count := 0
	var visible_luminance_sum := 0.0
	var magenta_pixel_count := 0
	var cyan_pixel_count := 0
	for yaw_index in range(MATERIAL_YAWS.size()):
		var source := _capture_ready_viewport(viewports[yaw_index], material_id, yaw_index)
		if source.is_empty():
			return
		minimum_opaque_ratio = minf(minimum_opaque_ratio, PreviewSupport.opaque_visible_ratio(source))
		max_firing_error = maxf(max_firing_error, rigs[yaw_index].firing_hand_error())
		max_support_error = maxf(max_support_error, rigs[yaw_index].support_hand_error())
		max_stock_error = maxf(max_stock_error, rigs[yaw_index].stock_contact_error())
		var color_metrics := _visible_color_metrics(source)
		visible_pixel_count += int(color_metrics["visible_pixel_count"])
		visible_luminance_sum += float(color_metrics["visible_luminance_sum"])
		magenta_pixel_count += int(color_metrics["magenta_pixel_count"])
		cyan_pixel_count += int(color_metrics["cyan_pixel_count"])
		var runtime_frame := source.duplicate()
		runtime_frame.resize(RUNTIME_FRAME_SIZE.x, RUNTIME_FRAME_SIZE.y, Image.INTERPOLATE_LANCZOS)
		runtime_row.blit_rect(runtime_frame, Rect2i(Vector2i.ZERO, RUNTIME_FRAME_SIZE), Vector2i(yaw_index * RUNTIME_FRAME_SIZE.x, 0))
		board_row.blend_rect(source, Rect2i(Vector2i.ZERO, BOARD_FRAME_SIZE), Vector2i(yaw_index * BOARD_FRAME_SIZE.x, 0))
		board_row.fill_rect(Rect2i(Vector2i(yaw_index * BOARD_FRAME_SIZE.x, 0), Vector2i(BOARD_FRAME_SIZE.x, 4)), MATERIAL_COLORS[material_id])
	if minimum_opaque_ratio <= 0.85:
		_fail("Material %s contains broad translucency" % material_id)
		return
	if maxf(max_firing_error, maxf(max_support_error, max_stock_error)) > RefinementRig.CONTACT_TOLERANCE:
		_fail("Material %s changed approved weapon contact" % material_id)
		return
	if not PreviewSupport.save_png(self, runtime_row, PARTIAL_MATERIAL_RUNTIME_PATTERN % material_id.to_lower(), "%s runtime row" % material_id):
		return
	if not PreviewSupport.save_png(self, board_row, PARTIAL_MATERIAL_BOARD_PATTERN % material_id.to_lower(), "%s board row" % material_id):
		return
	if not PreviewSupport.save_png(self, board_row, MATERIAL_SHEET_PATTERN % material_id.to_lower(), "%s material sheet" % material_id):
		return
	var report := {
		"material_id": material_id,
		"camera_pitch_degrees": CAMERA_PITCH_DEGREES,
		"yaw_degrees": MATERIAL_YAWS,
		"minimum_opaque_visible_ratio": minimum_opaque_ratio,
		"runtime_corner_alpha_max": PreviewSupport.corner_alpha_max(runtime_row),
		"max_firing_hand_error": max_firing_error,
		"max_support_hand_error": max_support_error,
		"max_stock_contact_error": max_stock_error,
		"mean_visible_luminance": visible_luminance_sum / maxf(float(visible_pixel_count), 1.0),
		"magenta_visible_ratio": float(magenta_pixel_count) / maxf(float(visible_pixel_count), 1.0),
		"cyan_visible_ratio": float(cyan_pixel_count) / maxf(float(visible_pixel_count), 1.0),
		"weapon_attachment": "BoneAttachment3D:firing_hand",
	}
	if not _write_json(PARTIAL_MATERIAL_REPORT_PATTERN % material_id.to_lower(), report):
		return
	print("RENDER PASS: PlayerProductionMaterial %s" % material_id)
	quit(0)

func _assemble() -> void:
	var build_report := _read_json_dictionary(BUILD_REPORT_PATH)
	var topology_report := _read_json_dictionary(PARTIAL_TOPOLOGY_REPORT_PATH)
	var topology_board := Image.load_from_file(ProjectSettings.globalize_path(PARTIAL_TOPOLOGY_BOARD_PATH))
	if build_report.is_empty() or topology_report.is_empty() or topology_board.is_empty():
		_fail("Topology build or comparison evidence is missing")
		return
	var runtime_atlas := Image.create_empty(4 * RUNTIME_FRAME_SIZE.x, 3 * RUNTIME_FRAME_SIZE.y, false, Image.FORMAT_RGBA8)
	runtime_atlas.fill(Color(0, 0, 0, 0))
	var material_board := Image.create_empty(4 * BOARD_FRAME_SIZE.x, 3 * BOARD_FRAME_SIZE.y, false, Image.FORMAT_RGBA8)
	material_board.fill(PREVIEW_BACKGROUND)
	var material_reports: Array[Dictionary] = []
	var minimum_opaque_ratio := 1.0
	var max_firing_error := 0.0
	var max_support_error := 0.0
	var max_stock_error := 0.0
	for material_index in range(MATERIAL_IDS.size()):
		var material_id: String = MATERIAL_IDS[material_index]
		var partial_runtime := Image.load_from_file(ProjectSettings.globalize_path(PARTIAL_MATERIAL_RUNTIME_PATTERN % material_id.to_lower()))
		var partial_board := Image.load_from_file(ProjectSettings.globalize_path(PARTIAL_MATERIAL_BOARD_PATTERN % material_id.to_lower()))
		var partial_report := _read_json_dictionary(PARTIAL_MATERIAL_REPORT_PATTERN % material_id.to_lower())
		if partial_runtime.is_empty() or partial_board.is_empty() or partial_report.is_empty():
			_fail("Material evidence is missing for " + material_id)
			return
		runtime_atlas.blit_rect(partial_runtime, Rect2i(Vector2i.ZERO, partial_runtime.get_size()), Vector2i(0, material_index * RUNTIME_FRAME_SIZE.y))
		material_board.blit_rect(partial_board, Rect2i(Vector2i.ZERO, partial_board.get_size()), Vector2i(0, material_index * BOARD_FRAME_SIZE.y))
		material_reports.append(partial_report)
		minimum_opaque_ratio = minf(minimum_opaque_ratio, float(partial_report["minimum_opaque_visible_ratio"]))
		max_firing_error = maxf(max_firing_error, float(partial_report["max_firing_hand_error"]))
		max_support_error = maxf(max_support_error, float(partial_report["max_support_hand_error"]))
		max_stock_error = maxf(max_stock_error, float(partial_report["max_stock_contact_error"]))
	if not PreviewSupport.save_png(self, runtime_atlas, RUNTIME_PATH, "material candidate atlas"):
		return
	if not PreviewSupport.save_png(self, material_board, MATERIAL_BOARD_PATH, "material comparison board"):
		return
	if not PreviewSupport.save_png(self, topology_board, TOPOLOGY_BOARD_PATH, "topology comparison board"):
		return
	var report := {
		"schema_version": 1,
		"asset_id": "player_production_topology_material_candidates",
		"camera_pitch_degrees": CAMERA_PITCH_DEGREES,
		"topology_yaw_count": TOPOLOGY_YAW_COUNT,
		"topology_yaw_step_degrees": TOPOLOGY_YAW_STEP_DEGREES,
		"minimum_required_silhouette_iou": MINIMUM_SILHOUETTE_IOU,
		"minimum_silhouette_iou": topology_report["minimum_silhouette_iou"],
		"topology_yaw_metrics": topology_report["yaw_metrics"],
		"topology_build": build_report,
		"material_ids": MATERIAL_IDS,
		"material_yaw_degrees": MATERIAL_YAWS,
		"material_reports": material_reports,
		"minimum_opaque_visible_ratio": minimum_opaque_ratio,
		"runtime_corner_alpha_max": PreviewSupport.corner_alpha_max(runtime_atlas),
		"max_firing_hand_error": max_firing_error,
		"max_support_hand_error": max_support_error,
		"max_stock_contact_error": max_stock_error,
		"weapon_attachment": "BoneAttachment3D:firing_hand",
		"production_integration": false,
		"topology_classification": "automatic LOD topology candidate; not hand-authored production retopology",
		"material_reference_generation": "built-in image generation, preview-only three-panel material language board; deterministic Godot renders are the review outputs",
	}
	if not _write_json(REPORT_PATH, report):
		return
	print("ASSEMBLE PASS: PlayerProductionTopologyMaterialPreview")
	quit(0)

func _build_rig_viewport_with_rig(viewport_name: String, mesh: ArrayMesh, yaw_degrees: float, material: Material) -> Dictionary:
	var viewport := PreviewSupport.build_viewport(viewport_name, SOURCE_SIZE, BODY_HEIGHT, CAMERA_PITCH_DEGREES, CAMERA_DISTANCE, true, false)
	var world_environment := viewport.get_node_or_null("WorldEnvironment") as WorldEnvironment
	if world_environment != null and world_environment.environment != null:
		world_environment.environment.ssao_enabled = false
	root.add_child(viewport)
	var rig := RefinementRig.new()
	viewport.add_child(rig)
	if not rig.initialize():
		_fail("Could not initialize A2 review rig")
		return {}
	if not rig.weapon_attachment is BoneAttachment3D:
		_fail("Independent rifle is not driven by BoneAttachment3D")
		return {}
	rig.body_mesh.mesh = mesh
	rig.body_mesh.material_override = material
	rig.scale = Vector3.ONE * (BODY_HEIGHT / NORMALIZED_BODY_HEIGHT)
	rig.apply_refinement("A2", 0.0, -1.0)
	rig.rotation_degrees.y = yaw_degrees
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	return {"viewport": viewport, "rig": rig}

func _neutral_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = 0.06
	material.roughness = 0.58
	return material

func _material(material_id: String) -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = MATERIAL_SHADER
	var material := ShaderMaterial.new()
	material.shader = shader
	match material_id:
		"M1":
			material.set_shader_parameter("base_color", Color("18232c"))
			material.set_shader_parameter("secondary_color", Color("35434c"))
			material.set_shader_parameter("accent_color", Color("33fff2"))
			material.set_shader_parameter("micro_color", Color("5b493b"))
			material.set_shader_parameter("metallic_level", 0.16)
			material.set_shader_parameter("roughness_level", 0.62)
			material.set_shader_parameter("wear_strength", 0.22)
			material.set_shader_parameter("pattern_scale", 118.0)
			material.set_shader_parameter("emission_strength", 1.35)
			material.set_shader_parameter("secondary_emission_strength", 0.0)
		"M2":
			material.set_shader_parameter("base_color", Color("aeb8bc"))
			material.set_shader_parameter("secondary_color", Color("252d33"))
			material.set_shader_parameter("accent_color", Color("3da7ff"))
			material.set_shader_parameter("micro_color", Color("6e6a61"))
			material.set_shader_parameter("metallic_level", 0.48)
			material.set_shader_parameter("roughness_level", 0.55)
			material.set_shader_parameter("wear_strength", 0.34)
			material.set_shader_parameter("pattern_scale", 74.0)
			material.set_shader_parameter("emission_strength", 0.92)
			material.set_shader_parameter("secondary_emission_strength", 0.0)
		"M3":
			material.set_shader_parameter("base_color", Color("11131b"))
			material.set_shader_parameter("secondary_color", Color("2a223b"))
			material.set_shader_parameter("accent_color", Color("33fff2"))
			material.set_shader_parameter("micro_color", Color("f559bf"))
			material.set_shader_parameter("metallic_level", 0.05)
			material.set_shader_parameter("roughness_level", 0.38)
			material.set_shader_parameter("wear_strength", 0.10)
			material.set_shader_parameter("pattern_scale", 54.0)
			material.set_shader_parameter("emission_strength", 1.72)
			material.set_shader_parameter("secondary_emission_strength", 1.28)
	return material

func _weapon_material(material_id: String) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("c66a32") if material_id != "M3" else Color("ff7a24")
	material.metallic = 0.52
	material.roughness = 0.42
	return material

func _set_weapon_material(node: Node, material: Material) -> void:
	if node is MeshInstance3D:
		(node as MeshInstance3D).material_override = material
	for child in node.get_children():
		_set_weapon_material(child, material)

func _capture_ready_viewport(viewport: SubViewport, label: String, index: int) -> Image:
	var source := viewport.get_texture().get_image()
	if source.is_empty():
		_fail("Empty %s capture at index %d" % [label, index])
		return Image.new()
	source.convert(Image.FORMAT_RGBA8)
	return source

func _silhouette_iou(left: Image, right: Image) -> float:
	var intersection := 0
	var union := 0
	for y in range(left.get_height()):
		for x in range(left.get_width()):
			var left_visible := left.get_pixel(x, y).a > 0.05
			var right_visible := right.get_pixel(x, y).a > 0.05
			if left_visible or right_visible:
				union += 1
				if left_visible and right_visible:
					intersection += 1
	if union == 0:
		return 0.0
	return float(intersection) / float(union)

func _visible_color_metrics(image: Image) -> Dictionary:
	var visible_pixel_count := 0
	var visible_luminance_sum := 0.0
	var magenta_pixel_count := 0
	var cyan_pixel_count := 0
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			var color := image.get_pixel(x, y)
			if color.a <= 0.05:
				continue
			visible_pixel_count += 1
			visible_luminance_sum += color.get_luminance()
			if color.r > 0.28 and color.b > 0.22 and color.r > color.g * 1.25 and color.b > color.g * 1.18:
				magenta_pixel_count += 1
			if color.g > 0.30 and color.b > 0.24 and color.g > color.r * 1.28 and color.b > color.r * 1.10:
				cyan_pixel_count += 1
	return {
		"visible_pixel_count": visible_pixel_count,
		"visible_luminance_sum": visible_luminance_sum,
		"magenta_pixel_count": magenta_pixel_count,
		"cyan_pixel_count": cyan_pixel_count,
	}

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
