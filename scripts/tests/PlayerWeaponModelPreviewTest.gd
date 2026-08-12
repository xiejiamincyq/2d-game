extends SceneTree

const WEAPON_MODEL_PATH := "res://assets/art/source/player/player_weapon_model_mv_v1.glb"
const BODY_MODEL_PATH := "res://assets/art/source/player/player_turnaround_model_mv_a_alpha_v3.glb"
const RENDERER_PATH := "res://scripts/art/RenderPlayerWeaponModelPreview.gd"

var assertions := 0

func _assert_true(condition: bool, message: String) -> bool:
	assertions += 1
	if condition:
		return true
	push_error("TEST FAIL: PlayerWeaponModelPreviewTest: " + message)
	quit(1)
	return false

func _initialize() -> void:
	if not _assert_true(FileAccess.file_exists(WEAPON_MODEL_PATH), "independent weapon GLB is missing"):
		return
	if not _assert_true(FileAccess.file_exists(BODY_MODEL_PATH), "approved body GLB is missing"):
		return
	if not _assert_true(FileAccess.file_exists(RENDERER_PATH), "weapon review renderer is missing"):
		return
	var renderer_source := FileAccess.get_file_as_string(RENDERER_PATH)
	if not _assert_true(renderer_source.contains("CAMERA_PITCH_DEGREES := 45.0"), "camera pitch is not exactly 45 degrees"):
		return
	if not _assert_true(renderer_source.contains("FRAME_COUNT := 12"), "review must use twelve true-yaw frames"):
		return
	if not _assert_true(renderer_source.contains("WEAPON_MODEL_PATH"), "renderer does not load an independent weapon model"):
		return
	if not _assert_true(renderer_source.contains("BODY_MODEL_PATH"), "renderer does not load the approved body separately"):
		return
	if not _assert_true(not renderer_source.contains("Sprite2D"), "renderer must not rotate a 2D weapon billboard"):
		return

	var resource := ResourceLoader.load(WEAPON_MODEL_PATH)
	if not _assert_true(resource is PackedScene, "weapon GLB does not import as PackedScene"):
		return
	var weapon := (resource as PackedScene).instantiate() as Node3D
	root.add_child(weapon)
	await process_frame
	var meshes: Array[MeshInstance3D] = []
	_collect_meshes(weapon, meshes)
	if not _assert_true(not meshes.is_empty(), "weapon GLB contains no mesh instances"):
		return
	var vertices := 0
	var faces := 0
	for mesh_instance in meshes:
		for surface_index in range(mesh_instance.mesh.get_surface_count()):
			var arrays := mesh_instance.mesh.surface_get_arrays(surface_index)
			vertices += (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
			faces += (arrays[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
	if not _assert_true(vertices >= 40000, "weapon GLB lacks review geometry detail"):
		return
	if not _assert_true(faces >= 80000, "weapon GLB lacks review face detail"):
		return
	var bounds := _combined_bounds(weapon, meshes)
	if not _assert_true(bounds.size.x / bounds.size.y > 2.0, "weapon silhouette is not rifle-length"):
		return
	if not _assert_true(bounds.size.z / bounds.size.x > 0.08, "weapon GLB is still effectively flat"):
		return
	if not _assert_true(bounds.size.z / bounds.size.x < 0.25, "weapon GLB is implausibly thick"):
		return
	weapon.queue_free()
	await process_frame
	print("TEST PASS: PlayerWeaponModelPreviewTest %d vertices=%d faces=%d" % [assertions, vertices, faces])
	quit(0)

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
		var relative := root_node.global_transform.affine_inverse() * mesh_instance.global_transform
		for x in [0.0, 1.0]:
			for y in [0.0, 1.0]:
				for z in [0.0, 1.0]:
					var corner := local_bounds.position + local_bounds.size * Vector3(x, y, z)
					var point := relative * corner
					minimum = minimum.min(point)
					maximum = maximum.max(point)
	return AABB(minimum, maximum - minimum)
