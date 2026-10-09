extends Polygon2D

# Each opaque paper patch is local to one real Bone2D. One native mesh contains
# all faces, preserving face order without separate Sprite2D draw objects.
# Build once at rest; Skeleton2D drives the bind pose, not per-frame CPU baking.
func build(rig: Skeleton2D, patches: Array[Dictionary]) -> bool:
	if rig == null or not is_inside_tree() or not rig.is_inside_tree() or patches.is_empty():
		return false
	var points := PackedVector2Array()
	var colors := PackedColorArray()
	var faces: Array[PackedInt32Array] = []
	var bindings: Array[NodePath] = []
	var vertex_bones: Array[int] = []
	for patch in patches:
		if not patch.has_all(["bone", "points", "color"]):
			return false
		if not patch.bone is NodePath or not patch.points is PackedVector2Array or not patch.color is Color:
			return false
		var path: NodePath = patch.bone
		var bone := rig.get_node_or_null(path) as Bone2D
		var local_points: PackedVector2Array = patch.points
		var tint: Color = patch.color
		if bone == null or not _belongs_to(bone, rig) or local_points.size() < 3 or not is_equal_approx(tint.a, 1.0):
			return false
		if not is_finite(tint.r) or not is_finite(tint.g) or not is_finite(tint.b):
			return false
		for point in local_points:
			if not point.is_finite():
				return false
		var twice_area := 0.0
		for index in local_points.size():
			twice_area += local_points[index].cross(local_points[(index + 1) % local_points.size()])
		if absf(twice_area) < 0.001:
			return false
		if Geometry2D.triangulate_polygon(local_points).is_empty():
			return false
		if path not in bindings:
			bindings.append(path)
		var binding := bindings.find(path)
		var face := PackedInt32Array()
		for point in local_points:
			face.append(points.size())
			points.append(bone.get_skeleton_rest() * point)
			colors.append(tint)
			vertex_bones.append(binding)
		faces.append(face)
	# Only commit after all patches pass; invalid rebuild leaves the old mesh.
	polygon = points
	polygons = faces
	vertex_colors = colors
	skeleton = get_path_to(rig)
	clear_bones()
	for binding in bindings.size():
		var weights := PackedFloat32Array()
		weights.resize(points.size())
		for index in points.size():
			weights[index] = 1.0 if vertex_bones[index] == binding else 0.0
		add_bone(bindings[binding], weights)
	return true

func _belongs_to(bone: Bone2D, rig: Skeleton2D) -> bool:
	var ancestor: Node = bone.get_parent()
	while ancestor is Bone2D:
		ancestor = ancestor.get_parent()
	return ancestor == rig
