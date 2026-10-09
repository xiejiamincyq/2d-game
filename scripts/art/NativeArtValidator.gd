extends RefCounted

# Native-resource gate is separate from the unchanged PNG production validator.
# Structural acceptance never replaces an operator's art/gameplay review.
const CONTROLLER := "res://scripts/components/NativeActorView.gd"
const FIELDS := ["asset_id", "runtime_scene", "motion_library", "role", "review_state", "bone_count", "license_origin", "required_clips"]

func validate_entry(entry: Dictionary) -> PackedStringArray:
	var errors := PackedStringArray()
	if not entry.has_all(FIELDS):
		return PackedStringArray(["native contract has missing fields"])
	var count = entry.bone_count
	if not entry.asset_id is String or entry.asset_id.is_empty() or not (count is int or count is float):
		return PackedStringArray(["invalid native identifier/joint count"])
	if not is_finite(count) or count < 1 or count > 128 or float(count) != floorf(count):
		return PackedStringArray(["invalid native identifier/joint count"])
	if entry.role not in ["player", "ordinary", "large", "boss"] or entry.license_origin != "project-original":
		return PackedStringArray(["role or original-source review is invalid"])
	if entry.review_state not in ["draft", "style-approved", "gameplay-approved", "final"]:
		return PackedStringArray(["unknown native review state"])
	if not entry.required_clips is Array or entry.required_clips.is_empty():
		return PackedStringArray(["required native motions missing"])
	if not _runtime_path(entry.runtime_scene, "res://scenes/actors/native/", ".tscn") or not _runtime_path(entry.motion_library, "res://assets/art/actors/native/", ".tres"):
		return PackedStringArray(["runtime scene/library path is unsafe or missing"])
	for dependency in ResourceLoader.get_dependencies(entry.runtime_scene):
		var path := dependency.get_slice("::", 2) if dependency.contains("::") else dependency
		if path not in [CONTROLLER, entry.motion_library]:
			errors.append("unreviewed/authoring scene dependency: " + path)
	if not ResourceLoader.get_dependencies(entry.motion_library).is_empty():
		errors.append("motion library has unreviewed external dependencies")
	if not errors.is_empty():
		return errors
	var packed := load(entry.runtime_scene) as PackedScene
	if packed == null:
		return PackedStringArray(["resource is not a PackedScene"])
	var actor := packed.instantiate()
	var rig := actor.get_node_or_null("Facing/Skeleton2D") as Skeleton2D
	var skin := actor.get_node_or_null("Facing/Skin") as Polygon2D
	var player := actor.get_node_or_null("AnimationPlayer") as AnimationPlayer
	if rig == null or skin == null or player == null:
		actor.free()
		return PackedStringArray(["native rig/skin/player absent"])
	if rig.find_children("*", "Bone2D", true, false).size() != entry.bone_count or skin.get_bone_count() != entry.bone_count:
		errors.append("native joint count disagrees with declaration")
	if skin.texture != null or skin.get_script() != null or skin.vertex_colors.size() != skin.polygon.size():
		errors.append("weighted skin depends on texture/builder or lacks colors")
	for color in skin.vertex_colors:
		if not is_equal_approx(color.a, 1) or not is_finite(color.r) or not is_finite(color.g) or not is_finite(color.b):
			errors.append("paper body contains translucent/nonfinite color")
			break
	if not actor.find_children("*", "CollisionObject2D", true, false).is_empty():
		errors.append("visual resource owns gameplay collision")
	var library := player.get_animation_library("") if player.has_animation_library("") else null
	if library == null or library.resource_path != entry.motion_library:
		errors.append("scene does not use the declared external motion library")
	for clip in entry.required_clips:
		if not clip is String or not player.has_animation(clip):
			errors.append("required motion absent/invalid")
	for clip in player.get_animation_list():
		if entry.role in ["large", "boss"] and ("attack" in str(clip) or "warning" in str(clip)):
			errors.append("large attack resources are deferred until all rigs are complete")
		var motion := player.get_animation(clip)
		for track in motion.get_track_count():
			if motion.track_get_type(track) != Animation.TYPE_VALUE:
				errors.append("motion contains gameplay/method/event track")
			var path := str(motion.track_get_path(track))
			if not path.begins_with("Facing/Skeleton2D/") and path != "Warning:visible":
				errors.append("motion controls nonvisual target")
	if entry.review_state in ["gameplay-approved", "final"]:
		var evidence = entry.get("runtime_evidence")
		if not evidence is Dictionary or not evidence.has_all(["gameplay_capture", "opacity_report", "review_document"]):
			errors.append("gameplay/final claim lacks actual native review evidence")
		else:
			for field in ["gameplay_capture", "opacity_report", "review_document"]:
				var suffix := str(evidence[field]).get_extension()
				var allowed: Array = ["png", "mp4"] if field == "gameplay_capture" else (["json"] if field == "opacity_report" else ["md"])
				if suffix not in allowed or not _runtime_path(evidence[field], "res://docs/", "." + suffix):
					errors.append("native evidence file is unsafe or missing")
	errors.append_array(validate_geometry(actor))
	actor.free()
	return errors

func validate_geometry(actor: Node) -> PackedStringArray:
	var errors := PackedStringArray()
	var rig := actor.get_node_or_null("Facing/Skeleton2D") as Skeleton2D
	var skin := actor.get_node_or_null("Facing/Skin") as Polygon2D
	if rig == null or skin == null:
		return PackedStringArray(["native skin/rig absent"])
	if skin.get_node_or_null(skin.skeleton) != rig or skin.polygon.size() < 3 or skin.polygons.is_empty():
		errors.append("skin is empty or not bound to its native rig")
	if not is_equal_approx(skin.color.a, 1):
		errors.append("Polygon2D base color makes the body translucent")
	for item in [actor, actor.get_node("Facing"), skin]:
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

func _runtime_path(value: Variant, prefix: String, extension: String) -> bool:
	return value is String and value.begins_with(prefix) and value.ends_with(extension) and ".." not in value and "\\" not in value and FileAccess.file_exists(value)
