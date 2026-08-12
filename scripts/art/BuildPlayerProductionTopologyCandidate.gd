extends SceneTree

const SOURCE_MESH_PATH := "res://assets/art/source/player/player_motion_review_skinned_mesh_v1.res"
const CANDIDATE_MESH_PATH := "res://assets/art/source/player/player_production_lod_topology_candidate_v1.res"
const BUILD_REPORT_PATH := "res://.godot/player_production_lod_topology_candidate_v1.json"
const TARGET_INDEX_RATIO := 0.42
const MIN_INDEX_RATIO := 0.20
const MAX_INDEX_RATIO := 0.65
const NORMAL_MERGE_ANGLE_DEGREES := 60.0

func _initialize() -> void:
	var source_mesh := ResourceLoader.load(SOURCE_MESH_PATH, "ArrayMesh") as ArrayMesh
	if source_mesh == null or source_mesh.get_surface_count() != 1:
		_fail("Approved source skinned mesh is missing or does not have one surface")
		return
	var source_vertex_count := source_mesh.surface_get_array_len(0)
	var source_index_count := source_mesh.surface_get_array_index_len(0)
	if source_vertex_count != 94652 or source_index_count != 567888:
		_fail("Approved source topology drifted")
		return
	var importer := ImporterMesh.from_mesh(source_mesh)
	if importer == null:
		_fail("Could not create ImporterMesh from approved source")
		return
	importer.generate_lods(NORMAL_MERGE_ANGLE_DEGREES, 0.0, [])
	var lod_count := importer.get_surface_lod_count(0)
	if lod_count <= 0:
		_fail("Godot meshoptimizer did not generate any LOD levels")
		return
	var selected_lod := -1
	var selected_indices := PackedInt32Array()
	var selected_ratio_error := INF
	var lod_summaries: Array[Dictionary] = []
	for lod_index in range(lod_count):
		var lod_indices := importer.get_surface_lod_indices(0, lod_index)
		var ratio := float(lod_indices.size()) / float(source_index_count)
		lod_summaries.append({
			"lod_index": lod_index,
			"index_count": lod_indices.size(),
			"index_ratio": ratio,
			"activation_size": importer.get_surface_lod_size(0, lod_index),
		})
		if ratio < MIN_INDEX_RATIO or ratio > MAX_INDEX_RATIO:
			continue
		var ratio_error := absf(ratio - TARGET_INDEX_RATIO)
		if ratio_error < selected_ratio_error:
			selected_ratio_error = ratio_error
			selected_lod = lod_index
			selected_indices = lod_indices
	if selected_lod < 0 or selected_indices.is_empty():
		_fail("No generated LOD lies inside the bounded index-ratio gate")
		return
	var compact_result := _compact_surface(source_mesh.surface_get_arrays(0), selected_indices, source_vertex_count)
	if compact_result.is_empty():
		return
	var compact_arrays: Array = compact_result["arrays"]
	var candidate := ArrayMesh.new()
	candidate.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, compact_arrays)
	candidate.surface_set_name(0, "AutomaticLodTopologyCandidate")
	candidate.custom_aabb = source_mesh.get_aabb()
	var save_error := ResourceSaver.save(candidate, CANDIDATE_MESH_PATH)
	if save_error != OK:
		_fail("Could not save compact topology candidate: %s" % error_string(save_error))
		return
	var candidate_vertex_count := candidate.surface_get_array_len(0)
	var candidate_index_count := candidate.surface_get_array_index_len(0)
	var report := {
		"schema_version": 1,
		"asset_id": "player_production_lod_topology_candidate_v1",
		"method": "Godot ImporterMesh.generate_lods backed by meshoptimizer, followed by deterministic referenced-vertex compaction",
		"classification": "automatic LOD topology candidate; not hand-authored production retopology",
		"normal_merge_angle_degrees": NORMAL_MERGE_ANGLE_DEGREES,
		"source_vertices": source_vertex_count,
		"source_indices": source_index_count,
		"source_triangles": source_index_count / 3,
		"generated_lods": lod_summaries,
		"selected_lod_index": selected_lod,
		"candidate_vertices": candidate_vertex_count,
		"candidate_indices": candidate_index_count,
		"candidate_triangles": candidate_index_count / 3,
		"vertex_ratio": float(candidate_vertex_count) / float(source_vertex_count),
		"index_ratio": float(candidate_index_count) / float(source_index_count),
		"four_slot_bones": (compact_arrays[Mesh.ARRAY_BONES] as PackedInt32Array).size() == candidate_vertex_count * 4,
		"four_slot_weights": (compact_arrays[Mesh.ARRAY_WEIGHTS] as PackedFloat32Array).size() == candidate_vertex_count * 4,
	}
	if not _write_json(BUILD_REPORT_PATH, report):
		return
	print("BUILD PASS: PlayerProductionTopologyCandidate source=%d/%d candidate=%d/%d lod=%d" % [
		source_vertex_count,
		source_index_count,
		candidate_vertex_count,
		candidate_index_count,
		selected_lod,
	])
	quit(0)

func _compact_surface(source_arrays: Array, selected_indices: PackedInt32Array, source_vertex_count: int) -> Dictionary:
	var old_to_new := PackedInt32Array()
	old_to_new.resize(source_vertex_count)
	old_to_new.fill(-1)
	var used_source_indices := PackedInt32Array()
	var compact_indices := PackedInt32Array()
	compact_indices.resize(selected_indices.size())
	for index_position in range(selected_indices.size()):
		var source_index := selected_indices[index_position]
		if source_index < 0 or source_index >= source_vertex_count:
			_fail("Generated LOD contains an out-of-range source index")
			return {}
		var compact_index := old_to_new[source_index]
		if compact_index < 0:
			compact_index = used_source_indices.size()
			old_to_new[source_index] = compact_index
			used_source_indices.append(source_index)
		compact_indices[index_position] = compact_index
	var compact_arrays: Array = []
	compact_arrays.resize(Mesh.ARRAY_MAX)
	for array_type in range(Mesh.ARRAY_MAX):
		if array_type == Mesh.ARRAY_INDEX:
			compact_arrays[array_type] = compact_indices
			continue
		var source_values: Variant = source_arrays[array_type]
		if source_values == null or source_values.size() == 0:
			continue
		if source_values.size() % source_vertex_count != 0:
			_fail("Source array %d cannot be compacted by vertex stride" % array_type)
			return {}
		var stride: int = source_values.size() / source_vertex_count
		var compact_values: Variant = source_values.slice(0, 0)
		for source_index in used_source_indices:
			var start: int = source_index * stride
			compact_values.append_array(source_values.slice(start, start + stride))
		compact_arrays[array_type] = compact_values
	return {
		"arrays": compact_arrays,
		"used_source_indices": used_source_indices,
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

func _fail(message: String) -> void:
	push_error(message)
	quit(1)
