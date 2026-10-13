extends RefCounted

# Native-resource gate is separate from the unchanged PNG production validator.
# Structural acceptance never replaces an operator's art/gameplay review.
const CONTROLLER := "res://scripts/components/NativeActorView.gd"
const Cardinal = preload("res://scripts/art/NativePlayerArtValidator.gd")
const SkinGeometry = preload("res://scripts/art/NativeSkinGeometryValidator.gd")
const RigCheckpoint = preload("res://scripts/art/NativeRigCheckpoint.gd")
const FIELDS := ["asset_id", "runtime_scene", "motion_library", "role", "review_state", "bone_count", "license_origin", "required_clips"]

func validate_entry(entry: Dictionary) -> PackedStringArray:
	if entry.get("role")=="player" or entry.get("layout")=="cardinal_4":
		return Cardinal.new().validate_entry(entry)
	var errors := PackedStringArray()
	if not entry.has_all(FIELDS):
		return PackedStringArray(["native contract has missing fields"])
	var count = entry.bone_count
	if not entry.asset_id is String or entry.asset_id.is_empty() or not (count is int or count is float):
		return PackedStringArray(["invalid native identifier/joint count"])
	if not is_finite(count) or count < 1 or count > 128 or float(count) != floorf(count):
		return PackedStringArray(["invalid native identifier/joint count"])
	if entry.role not in ["ordinary", "companion", "large", "boss"] or entry.license_origin != "project-original":
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
	var post_rig := false
	if entry.role in ["large","boss"] and entry.has("rig_checkpoint"):
		var checkpoint_errors := RigCheckpoint.new().validate_entry(entry)
		errors.append_array(checkpoint_errors)
		post_rig = checkpoint_errors.is_empty()
	for clip in player.get_animation_list():
		if entry.role in ["large", "boss"] and ("attack" in str(clip) or "warning" in str(clip)):
			if not post_rig:
				errors.append("large attack resources are deferred until the reviewed rig checkpoint")
			elif str(clip) not in entry.required_clips:
				errors.append("post-rig attack is not declared for review")
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
	return SkinGeometry.new().validate(actor.get_node_or_null("Facing/Skeleton2D"),actor.get_node_or_null("Facing/Skin"),[actor,actor.get_node_or_null("Facing"),actor.get_node_or_null("Facing/Skin")])

func validate_player_geometry(actor: Node) -> PackedStringArray:
	return Cardinal.new().validate_geometry(actor)

func _runtime_path(value: Variant, prefix: String, extension: String) -> bool:
	return value is String and value.begins_with(prefix) and value.ends_with(extension) and ".." not in value and "\\" not in value and FileAccess.file_exists(value)
