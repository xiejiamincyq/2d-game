extends RefCounted
## Shared weighted mesh/rest acceptance for single and cardinal native layouts.
func validate(rig: Skeleton2D,skin: Polygon2D,ancestors: Array) -> PackedStringArray:
	var errors := PackedStringArray()
	if rig == null or skin == null:
		return PackedStringArray(["native skin/rig absent"])
	if skin.get_node_or_null(skin.skeleton) != rig or skin.polygon.size() < 3 or skin.polygons.is_empty():
		errors.append("skin is empty or not bound to its native rig")
	if not is_equal_approx(skin.color.a, 1):
		errors.append("Polygon2D base color makes the body translucent")
	for item in ancestors:
		if not is_equal_approx(item.modulate.a, 1) or not is_equal_approx(item.self_modulate.a, 1):
			errors.append("skin ancestor tint makes the body translucent")
	for bone in rig.find_children("*", "Bone2D", true, false):
		if not bone.rest.is_finite() or is_zero_approx(bone.rest.determinant()) or not bone.transform.is_equal_approx(bone.rest):
			errors.append("native rest pose is invalid or scene contains a baked moving pose")
	for point in skin.polygon:
		if not point.is_finite():
			errors.append("skin vertex is nonfinite")
	var all_weights: Array[PackedFloat32Array] = []
	var seen: Array[NodePath] = []
	for index in skin.get_bone_count():
		var path := skin.get_bone_path(index)
		if path in seen or not rig.get_node_or_null(path) is Bone2D:
			errors.append("skin binding is duplicate or missing")
		seen.append(path)
		var weights := skin.get_bone_weights(index)
		if weights.size() != skin.polygon.size():
			errors.append("bone weights do not cover the whole native mesh")
			return errors
		all_weights.append(weights)
	for vertex in skin.polygon.size():
		var total := 0.0
		var influences := 0
		for weights in all_weights:
			var weight := weights[vertex]
			if not is_finite(weight) or weight < 0:
				errors.append("invalid bone weight")
			total += weight
			influences += 1 if weight > 0 else 0
		if not is_equal_approx(total, 1) or influences < 1 or influences > 4:
			errors.append("unbound or non-normalized vertex")
	for face in skin.polygons:
		var points := PackedVector2Array()
		for index in face:
			if index < 0 or index >= skin.polygon.size():
				errors.append("native face index outside mesh")
				return errors
			points.append(skin.polygon[index])
		if points.size() < 3 or Geometry2D.triangulate_polygon(points).is_empty():
			errors.append("native face is not drawable")
	return errors
