extends SceneTree

const PlayerTurnaroundModelScript = preload("res://scripts/art/PlayerTurnaroundModel.gd")
const MODEL_PATH := "res://assets/art/source/player/player_turnaround_model_v1.glb"

var assertions := 0

func _assert_true(condition: bool, message: String) -> bool:
	assertions += 1
	if condition:
		return true
	push_error("TEST FAIL: PlayerTurnaroundModelTest: " + message)
	quit(1)
	return false

func _initialize() -> void:
	if not _assert_true(FileAccess.file_exists(MODEL_PATH), "generated GLB is missing"):
		return
	var model: Node3D = PlayerTurnaroundModelScript.build()
	root.add_child(model)
	await process_frame
	var meshes: Array[MeshInstance3D] = []
	_collect_meshes(model, meshes)
	if not _assert_true(not meshes.is_empty(), "generated GLB contains no mesh instances"):
		return
	var vertices := 0
	var faces := 0
	for mesh_instance in meshes:
		for surface_index in range(mesh_instance.mesh.get_surface_count()):
			var arrays := mesh_instance.mesh.surface_get_arrays(surface_index)
			vertices += (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
			faces += (arrays[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
	if not _assert_true(vertices >= 100000, "generated GLB lacks production geometry detail"):
		return
	if not _assert_true(faces >= 200000, "generated GLB lacks production face detail"):
		return
	model.queue_free()
	await process_frame
	print("TEST PASS: PlayerTurnaroundModelTest %d vertices=%d faces=%d" % [assertions, vertices, faces])
	quit(0)

func _collect_meshes(node: Node, output: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D:
		output.append(node as MeshInstance3D)
	for child in node.get_children():
		_collect_meshes(child, output)
