extends Node3D
class_name PlayerGripRig

const BODY_MODEL_PATH := "res://assets/art/source/player/player_turnaround_model_mv_a_alpha_v3.glb"
const WEAPON_MODEL_PATH := "res://assets/art/source/player/player_weapon_model_mv_v1.glb"
const ACTIONS := ["READY", "MOVE", "FIRE"]
const CONTACT_TOLERANCE := 0.006
const WEAPON_LENGTH := 1.10

const ROOT_BONE := 0
const TORSO_BONE := 1
const FIRING_UPPER_BONE := 2
const FIRING_FORE_BONE := 3
const FIRING_HAND_BONE := 4
const SUPPORT_UPPER_BONE := 5
const SUPPORT_FORE_BONE := 6
const SUPPORT_HAND_BONE := 7

const FIRING_SHOULDER := Vector3(-0.285, 1.50, 0.04)
const FIRING_ELBOW_REST := Vector3(-0.42, 1.23, 0.05)
const FIRING_HAND_REST := Vector3(-0.48, 0.98, 0.04)
const SUPPORT_SHOULDER := Vector3(0.285, 1.50, 0.04)
const SUPPORT_ELBOW_REST := Vector3(0.42, 1.23, 0.05)
const SUPPORT_HAND_REST := Vector3(0.48, 0.98, 0.04)

const STOCK_ANCHOR := Vector3(-0.50, 0.07, 0.0)
const PISTOL_GRIP_ANCHOR := Vector3(-0.16, -0.12, 0.0)
const HANDGUARD_ANCHOR := Vector3(0.16, -0.04, 0.0)

var skeleton: Skeleton3D
var body_mesh: MeshInstance3D
var weapon_attachment: BoneAttachment3D
var weapon_model: Node3D
var arm_weighted_vertex_count := 0
var blended_vertex_count := 0
var arm_region_vertex_count := 0
var underweighted_arm_vertex_count := 0
var _weapon_transform := Transform3D.IDENTITY
var _stock_contact := Vector3.ZERO
var _current_weapon_angle_degrees := 0.0

func initialize() -> bool:
	if skeleton != null:
		return true
	skeleton = _build_skeleton()
	add_child(skeleton)
	body_mesh = _build_skinned_body()
	if body_mesh == null:
		return false
	skeleton.add_child(body_mesh)
	body_mesh.skeleton = NodePath("..")
	body_mesh.skin = skeleton.create_skin_from_rest_transforms()

	weapon_attachment = BoneAttachment3D.new()
	weapon_attachment.name = "FiringHandWeaponAttachment"
	weapon_attachment.bone_name = "firing_hand"
	skeleton.add_child(weapon_attachment)
	weapon_model = _build_weapon()
	if weapon_model == null:
		return false
	weapon_attachment.add_child(weapon_model)
	apply_action(ACTIONS[0])
	return true

func apply_action(action: String) -> void:
	if action not in ACTIONS:
		push_error("Unknown player grip action: " + action)
		return
	var weapon_angle := 0.0
	var shoulder_offset := Vector3.ZERO
	if action == "MOVE":
		weapon_angle = -1.5
		shoulder_offset = Vector3(0.0, -0.025, 0.0)
	elif action == "FIRE":
		weapon_angle = 4.0
		shoulder_offset = Vector3(0.0, -0.005, 0.0)
	_apply_weapon_pose(weapon_angle, shoulder_offset)

func _apply_weapon_pose(weapon_angle: float, shoulder_offset: Vector3) -> void:
	_apply_weapon_pose_transformed(weapon_angle, shoulder_offset, Transform3D.IDENTITY)

func _apply_weapon_pose_transformed(
	weapon_angle: float,
	shoulder_offset: Vector3,
	body_transform: Transform3D
) -> void:
	_current_weapon_angle_degrees = weapon_angle
	_stock_contact = body_transform * (Vector3(-0.285, 1.50, 0.235) + shoulder_offset)
	var weapon_basis := body_transform.basis * Basis(Vector3.FORWARD, deg_to_rad(weapon_angle))
	_weapon_transform = Transform3D(
		weapon_basis,
		_stock_contact - weapon_basis * STOCK_ANCHOR
	)
	var firing_target := _weapon_transform * PISTOL_GRIP_ANCHOR
	var support_target := _weapon_transform * HANDGUARD_ANCHOR
	_pose_arm(
		FIRING_UPPER_BONE,
		FIRING_FORE_BONE,
		FIRING_HAND_BONE,
		body_transform * FIRING_SHOULDER,
		body_transform * FIRING_ELBOW_REST,
		body_transform * FIRING_HAND_REST,
		firing_target,
		body_transform * Vector3(-0.62, 1.26, 0.30),
		weapon_basis
	)
	_pose_arm(
		SUPPORT_UPPER_BONE,
		SUPPORT_FORE_BONE,
		SUPPORT_HAND_BONE,
		body_transform * SUPPORT_SHOULDER,
		body_transform * SUPPORT_ELBOW_REST,
		body_transform * SUPPORT_HAND_REST,
		support_target,
		body_transform * Vector3(0.64, 1.28, 0.31),
		weapon_basis
	)
	var firing_hand_pose := Transform3D(weapon_basis, firing_target)
	weapon_model.transform = firing_hand_pose.affine_inverse() * _weapon_transform

func firing_hand_error() -> float:
	return skeleton.get_bone_global_pose(FIRING_HAND_BONE).origin.distance_to(
		_weapon_transform * PISTOL_GRIP_ANCHOR
	)

func support_hand_error() -> float:
	return skeleton.get_bone_global_pose(SUPPORT_HAND_BONE).origin.distance_to(
		_weapon_transform * HANDGUARD_ANCHOR
	)

func stock_contact_error() -> float:
	return (_weapon_transform * STOCK_ANCHOR).distance_to(_stock_contact)

func firing_hand_position() -> Vector3:
	return skeleton.get_bone_global_pose(FIRING_HAND_BONE).origin

func support_hand_position() -> Vector3:
	return skeleton.get_bone_global_pose(SUPPORT_HAND_BONE).origin

func stock_contact_position() -> Vector3:
	return _stock_contact

func current_weapon_angle_degrees() -> float:
	return _current_weapon_angle_degrees

func _build_skeleton() -> Skeleton3D:
	var result := Skeleton3D.new()
	result.name = "PlayerGripReviewSkeleton"
	_add_bone(result, "root", -1, Transform3D.IDENTITY)
	_add_bone(result, "torso", ROOT_BONE, Transform3D.IDENTITY)
	_add_bone(result, "firing_upper_arm", TORSO_BONE, Transform3D(Basis.IDENTITY, FIRING_SHOULDER))
	_add_bone(result, "firing_forearm", FIRING_UPPER_BONE, Transform3D(Basis.IDENTITY, FIRING_ELBOW_REST - FIRING_SHOULDER))
	_add_bone(result, "firing_hand", FIRING_FORE_BONE, Transform3D(Basis.IDENTITY, FIRING_HAND_REST - FIRING_ELBOW_REST))
	_add_bone(result, "support_upper_arm", TORSO_BONE, Transform3D(Basis.IDENTITY, SUPPORT_SHOULDER))
	_add_bone(result, "support_forearm", SUPPORT_UPPER_BONE, Transform3D(Basis.IDENTITY, SUPPORT_ELBOW_REST - SUPPORT_SHOULDER))
	_add_bone(result, "support_hand", SUPPORT_FORE_BONE, Transform3D(Basis.IDENTITY, SUPPORT_HAND_REST - SUPPORT_ELBOW_REST))
	return result

func _add_bone(target: Skeleton3D, bone_name: String, parent: int, rest: Transform3D) -> void:
	target.add_bone(bone_name)
	var index := target.get_bone_count() - 1
	target.set_bone_parent(index, parent)
	target.set_bone_rest(index, rest)
	target.set_bone_pose(index, rest)

func _build_skinned_body() -> MeshInstance3D:
	var source := _instantiate_model(BODY_MODEL_PATH, "approved body")
	if source == null:
		return null
	var source_meshes: Array[MeshInstance3D] = []
	_collect_meshes(source, source_meshes)
	if source_meshes.size() != 1:
		push_error("Approved body review rig expects exactly one mesh instance")
		source.queue_free()
		return null
	var source_instance := source_meshes[0]
	var source_mesh := source_instance.mesh
	var source_transform := _transform_relative_to(source_instance, source)
	var source_bounds := _transformed_bounds(source_mesh.get_aabb(), source_transform)
	var center := source_bounds.get_center()
	var offset := Vector3(-center.x, -source_bounds.position.y, -center.z)
	var skinned_mesh := ArrayMesh.new()
	arm_weighted_vertex_count = 0
	blended_vertex_count = 0
	arm_region_vertex_count = 0
	underweighted_arm_vertex_count = 0
	for surface_index in range(source_mesh.get_surface_count()):
		var arrays := source_mesh.surface_get_arrays(surface_index)
		var vertices := arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
		var transformed_vertices := PackedVector3Array()
		transformed_vertices.resize(vertices.size())
		var bone_indices := PackedInt32Array()
		bone_indices.resize(vertices.size() * 4)
		var bone_weights := PackedFloat32Array()
		bone_weights.resize(vertices.size() * 4)
		for vertex_index in range(vertices.size()):
			var point := source_transform * vertices[vertex_index] + offset
			transformed_vertices[vertex_index] = point
			var influences := _bone_influences(point)
			_record_influence_metrics(point, influences)
			var base := vertex_index * 4
			var side_bones := _influence_bones(point)
			bone_indices[base] = TORSO_BONE
			bone_weights[base] = influences[0]
			for influence_index in range(3):
				bone_indices[base + influence_index + 1] = side_bones[influence_index]
				bone_weights[base + influence_index + 1] = influences[influence_index + 1]
		arrays[Mesh.ARRAY_VERTEX] = transformed_vertices
		arrays[Mesh.ARRAY_BONES] = bone_indices
		arrays[Mesh.ARRAY_WEIGHTS] = bone_weights
		if arrays[Mesh.ARRAY_NORMAL] is PackedVector3Array and not (arrays[Mesh.ARRAY_NORMAL] as PackedVector3Array).is_empty():
			var normals := arrays[Mesh.ARRAY_NORMAL] as PackedVector3Array
			for normal_index in range(normals.size()):
				normals[normal_index] = (source_transform.basis * normals[normal_index]).normalized()
			arrays[Mesh.ARRAY_NORMAL] = normals
		skinned_mesh.add_surface_from_arrays(source_mesh.surface_get_primitive_type(surface_index), arrays)
	source.queue_free()
	var result := MeshInstance3D.new()
	result.name = "ApprovedBodySkinnedReviewMesh"
	result.mesh = skinned_mesh
	result.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("aab4be")
	material.metallic = 0.06
	material.roughness = 0.58
	result.material_override = material
	return result

func _influence_bones(point: Vector3) -> PackedInt32Array:
	if point.x < 0.0:
		return PackedInt32Array([FIRING_UPPER_BONE, FIRING_FORE_BONE, FIRING_HAND_BONE])
	return PackedInt32Array([SUPPORT_UPPER_BONE, SUPPORT_FORE_BONE, SUPPORT_HAND_BONE])

func _record_influence_metrics(point: Vector3, influences: PackedFloat32Array) -> void:
	if influences[1] + influences[2] + influences[3] > 0.25:
		arm_weighted_vertex_count += 1
	if absf(point.x) > 0.30 and point.y > 0.78 and point.y < 1.66:
		arm_region_vertex_count += 1
		if influences[1] + influences[2] + influences[3] < 0.80:
			underweighted_arm_vertex_count += 1
	if influences[0] > 0.001 and influences[0] < 0.999:
		blended_vertex_count += 1

func _bone_influences(point: Vector3) -> PackedFloat32Array:
	var shoulder := FIRING_SHOULDER if point.x < 0.0 else SUPPORT_SHOULDER
	var elbow := FIRING_ELBOW_REST if point.x < 0.0 else SUPPORT_ELBOW_REST
	var hand := FIRING_HAND_REST if point.x < 0.0 else SUPPORT_HAND_REST
	var upper := _segment_distance(point, shoulder, elbow)
	var fore := _segment_distance(point, elbow, hand)
	var upper_raw := _radial_falloff(upper.x, 0.075, 0.34)
	var fore_raw := _radial_falloff(fore.x, 0.065, 0.30) * smoothstep(0.0, 0.28, fore.y)
	var hand_raw := _radial_falloff(point.distance_to(hand), 0.055, 0.22) * smoothstep(0.58, 0.94, fore.y)
	var shoulder_blend := smoothstep(0.0, 0.34, upper.y)
	var coordinate_gate := smoothstep(0.20, 0.34, absf(point.x))
	var arm_presence := maxf(
		coordinate_gate,
		maxf(upper_raw, maxf(fore_raw, hand_raw)) * shoulder_blend
	)
	if point.y < 0.78 or point.y > 1.72:
		arm_presence = 0.0
	var raw_total := upper_raw + fore_raw + hand_raw
	if raw_total <= 0.000001 or arm_presence <= 0.000001:
		return PackedFloat32Array([1.0, 0.0, 0.0, 0.0])
	return PackedFloat32Array([
		1.0 - arm_presence,
		arm_presence * upper_raw / raw_total,
		arm_presence * fore_raw / raw_total,
		arm_presence * hand_raw / raw_total,
	])

func _radial_falloff(distance: float, full_radius: float, zero_radius: float) -> float:
	return 1.0 - smoothstep(full_radius, zero_radius, distance)

func _segment_distance(point: Vector3, start: Vector3, finish: Vector3) -> Vector2:
	var segment := finish - start
	var t := clampf((point - start).dot(segment) / segment.length_squared(), 0.0, 1.0)
	return Vector2(point.distance_to(start + segment * t), t)

func _pose_arm(
	upper_bone: int,
	fore_bone: int,
	hand_bone: int,
	shoulder: Vector3,
	rest_elbow: Vector3,
	rest_hand: Vector3,
	target_hand: Vector3,
	hint: Vector3,
	hand_basis: Basis
) -> void:
	var upper_length := shoulder.distance_to(rest_elbow)
	var fore_length := rest_elbow.distance_to(rest_hand)
	var shoulder_to_target := target_hand - shoulder
	var distance := clampf(
		shoulder_to_target.length(),
		absf(upper_length - fore_length) + 0.0001,
		upper_length + fore_length - 0.0001
	)
	var direction := shoulder_to_target.normalized()
	var along := (upper_length * upper_length - fore_length * fore_length + distance * distance) / (2.0 * distance)
	var height := sqrt(maxf(upper_length * upper_length - along * along, 0.0))
	var hint_vector := hint - shoulder
	var perpendicular := hint_vector - direction * hint_vector.dot(direction)
	if perpendicular.length_squared() < 0.000001:
		perpendicular = Vector3.UP.cross(direction)
	perpendicular = perpendicular.normalized()
	var elbow := shoulder + direction * along + perpendicular * height

	var upper_basis := Basis(Quaternion((rest_elbow - shoulder).normalized(), (elbow - shoulder).normalized()))
	var fore_global_basis := Basis(Quaternion((rest_hand - rest_elbow).normalized(), (target_hand - elbow).normalized()))
	skeleton.set_bone_global_pose(upper_bone, Transform3D(upper_basis, shoulder))
	skeleton.set_bone_global_pose(fore_bone, Transform3D(fore_global_basis, elbow))
	skeleton.set_bone_global_pose(hand_bone, Transform3D(hand_basis, target_hand))

func _build_weapon() -> Node3D:
	var source := _instantiate_model(WEAPON_MODEL_PATH, "independent rifle")
	if source == null:
		return null
	var meshes: Array[MeshInstance3D] = []
	_collect_meshes(source, meshes)
	var bounds := _combined_bounds(source, meshes)
	var weapon_scale := WEAPON_LENGTH / bounds.size.x
	source.scale = Vector3.ONE * weapon_scale
	source.position = -bounds.get_center() * weapon_scale
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("c66a32")
	material.metallic = 0.18
	material.roughness = 0.46
	for mesh_instance in meshes:
		mesh_instance.material_override = material
		mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	var pivot := Node3D.new()
	pivot.name = "IndependentRifle"
	pivot.add_child(source)
	return pivot

func _instantiate_model(path: String, label: String) -> Node3D:
	var resource := ResourceLoader.load(path)
	if not resource is PackedScene:
		push_error("Could not load %s GLB: %s" % [label, path])
		return null
	var model := (resource as PackedScene).instantiate() as Node3D
	if model == null:
		push_error(label + " GLB did not instantiate as Node3D")
		return null
	return model

func _collect_meshes(node: Node, output: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D:
		output.append(node as MeshInstance3D)
	for child in node.get_children():
		_collect_meshes(child, output)

func _combined_bounds(root_node: Node3D, meshes: Array[MeshInstance3D]) -> AABB:
	var minimum := Vector3(INF, INF, INF)
	var maximum := Vector3(-INF, -INF, -INF)
	for mesh_instance in meshes:
		var transformed := _transformed_bounds(
			mesh_instance.get_aabb(),
			_transform_relative_to(mesh_instance, root_node)
		)
		minimum = minimum.min(transformed.position)
		maximum = maximum.max(transformed.end)
	return AABB(minimum, maximum - minimum)

func _transformed_bounds(bounds: AABB, transform: Transform3D) -> AABB:
	var minimum := Vector3(INF, INF, INF)
	var maximum := Vector3(-INF, -INF, -INF)
	for x in [0.0, 1.0]:
		for y in [0.0, 1.0]:
			for z in [0.0, 1.0]:
				var corner := bounds.position + bounds.size * Vector3(x, y, z)
				var point := transform * corner
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
