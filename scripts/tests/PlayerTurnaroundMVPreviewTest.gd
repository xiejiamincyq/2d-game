extends SceneTree

const MODEL_PATH := "res://assets/art/source/player/player_turnaround_model_mv_preview_v1.glb"
const RENDERER_PATH := "res://scripts/art/RenderPlayerTurnaroundMVPreview.gd"

var assertions := 0

func _assert_true(condition: bool, message: String) -> bool:
	assertions += 1
	if condition:
		return true
	push_error("TEST FAIL: PlayerTurnaroundMVPreviewTest: " + message)
	quit(1)
	return false

func _initialize() -> void:
	if not _assert_true(FileAccess.file_exists(MODEL_PATH), "multi-view GLB is missing"):
		return
	if not _assert_true(FileAccess.file_exists(RENDERER_PATH), "review renderer is missing"):
		return
	var renderer_source := FileAccess.get_file_as_string(RENDERER_PATH)
	if not _assert_true(renderer_source.contains("CAMERA_PITCH_DEGREES := 45.0"), "camera pitch is not exactly 45 degrees"):
		return
	if not _assert_true(renderer_source.contains("FRAME_COUNT := 12"), "review gate must render twelve frames"):
		return
	if not _assert_true(renderer_source.contains("FRAME_STEP_DEGREES := 30"), "review gate must use thirty-degree steps"):
		return
	if not _assert_true(not renderer_source.contains("PlayerTurnaroundModelScript"), "review renderer must not use the rejected projection shader"):
		return
	if not _assert_true(renderer_source.contains("PLAYER_MV_MODEL_PATH"), "renderer must accept a non-destructive model revision path"):
		return
	if not _assert_true(renderer_source.contains("PLAYER_MV_PREVIEW_PATH"), "renderer must accept a non-destructive preview revision path"):
		return

	var resource := ResourceLoader.load(MODEL_PATH)
	if not _assert_true(resource is PackedScene, "multi-view GLB does not import as PackedScene"):
		return
	var model := (resource as PackedScene).instantiate()
	root.add_child(model)
	await process_frame
	var meshes: Array[MeshInstance3D] = []
	_collect_meshes(model, meshes)
	if not _assert_true(not meshes.is_empty(), "multi-view GLB contains no mesh instances"):
		return
	var vertices := 0
	var faces := 0
	for mesh_instance in meshes:
		for surface_index in range(mesh_instance.mesh.get_surface_count()):
			var arrays := mesh_instance.mesh.surface_get_arrays(surface_index)
			vertices += (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
			faces += (arrays[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
	if not _assert_true(vertices >= 100000, "multi-view GLB lacks review geometry detail"):
		return
	if not _assert_true(faces >= 200000, "multi-view GLB lacks review face detail"):
		return
	model.queue_free()
	await process_frame
	print("TEST PASS: PlayerTurnaroundMVPreviewTest %d vertices=%d faces=%d" % [assertions, vertices, faces])
	quit(0)

func _collect_meshes(node: Node, output: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D:
		output.append(node as MeshInstance3D)
	for child in node.get_children():
		_collect_meshes(child, output)
