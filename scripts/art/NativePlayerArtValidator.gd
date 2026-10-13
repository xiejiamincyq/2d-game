extends RefCounted
## Cardinal subtype of the same native catalog. No authoring/gameplay dependency.
const Geometry = preload("res://scripts/art/NativeSkinGeometryValidator.gd")
const CONTROLLER := "res://scripts/components/NativePlayerView.gd"
const VIEWS := ["Front","Back","Left","Right"]
const FIELDS := ["asset_id","runtime_scene","layout","role","review_state","bone_count","skin_bone_count","license_origin","required_clips","motion_libraries"]
const WEAPON := "Skeleton2D/Torso/ArmR/ForearmR/HandR/Weapon"
func validate_entry(entry: Dictionary) -> PackedStringArray:
	if not entry.has_all(FIELDS): return PackedStringArray(["cardinal contract has missing fields"])
	if entry.role!="player" or entry.layout!="cardinal_4" or entry.license_origin!="project-original":
		return PackedStringArray(["invalid cardinal role/layout/origin"])
	if not entry.asset_id is String or entry.asset_id.is_empty() or not _count(entry.bone_count) or not _count(entry.skin_bone_count):
		return PackedStringArray(["invalid cardinal identifier/joint count"])
	if entry.review_state not in ["draft","style-approved","gameplay-approved","final"]:
		return PackedStringArray(["invalid cardinal review state"])
	if not entry.required_clips is Array or entry.required_clips.is_empty() or not entry.motion_libraries is Dictionary:
		return PackedStringArray(["required cardinal clips/libraries missing"])
	if not _path(entry.runtime_scene,"res://scenes/actors/native/",".tscn") or entry.motion_libraries.size()!=4 or not entry.motion_libraries.has_all(VIEWS):
		return PackedStringArray(["unsafe scene or incomplete four libraries"])
	var allowed := [CONTROLLER]
	for direction in VIEWS:
		var library = entry.motion_libraries[direction]
		if not _path(library,"res://assets/art/actors/native/",".tres") or library in allowed:
			return PackedStringArray(["unsafe/duplicate cardinal library"])
		allowed.append(library)
		if not ResourceLoader.get_dependencies(library).is_empty(): return PackedStringArray(["cardinal library has external dependency"])
	for dependency in ResourceLoader.get_dependencies(entry.runtime_scene):
		var path := dependency.get_slice("::",2) if dependency.contains("::") else dependency
		if path not in allowed: return PackedStringArray(["unreviewed cardinal scene dependency"])
	var packed := load(entry.runtime_scene) as PackedScene
	if packed==null: return PackedStringArray(["cardinal scene is not packed"])
	var actor := packed.instantiate()
	var errors := validate_geometry(actor,int(entry.bone_count),int(entry.skin_bone_count))
	if actor.get_script()==null or actor.get_script().resource_path!=CONTROLLER: errors.append("cardinal scene has wrong visual controller")
	for direction in VIEWS:
		var animator := actor.get_node_or_null(direction+"/AnimationPlayer") as AnimationPlayer
		if animator==null:
			errors.append("cardinal animator missing")
			continue
		var library := animator.get_animation_library("") if animator.has_animation_library("") else null
		if library==null or library.resource_path!=entry.motion_libraries[direction]: errors.append("cardinal scene uses undeclared library")
		for clip in entry.required_clips:
			if not clip is String or not animator.has_animation(clip): errors.append("required cardinal motion absent")
		for clip in animator.get_animation_list():
			var animation := animator.get_animation(clip)
			for track in animation.get_track_count():
				var path := animation.track_get_path(track)
				var target := actor.get_node(direction).get_node_or_null(NodePath(path.get_concatenated_names()))
				if animation.track_get_type(track)!=Animation.TYPE_VALUE or not target is Bone2D or path.get_concatenated_subnames() not in ["position","rotation","scale"]:
					errors.append("cardinal motion controls non-joint/gameplay/opacity target")
	if entry.review_state in ["gameplay-approved","final"]:
		var evidence = entry.get("runtime_evidence")
		if not evidence is Dictionary or not evidence.has_all(["gameplay_capture","opacity_report","review_document"]):
			errors.append("cardinal final/gameplay claim lacks evidence")
		else:
			for field in ["gameplay_capture","opacity_report","review_document"]:
				var suffix := str(evidence[field]).get_extension()
				var allowed_suffix: Array = ["png","mp4"] if field=="gameplay_capture" else (["json"] if field=="opacity_report" else ["md"])
				if suffix not in allowed_suffix or not _path(evidence[field],"res://docs/","."+suffix): errors.append("unsafe/missing cardinal evidence")
	actor.free()
	return errors
func validate_geometry(actor: Node,bone_count: int = 13,skin_bones: int = 12) -> PackedStringArray:
	var errors := PackedStringArray()
	if not is_instance_valid(actor) or not actor is Node2D: return PackedStringArray(["cardinal root is not a visual Node2D"])
	if not actor.transform.is_equal_approx(Transform2D.IDENTITY) or actor.get_child_count()!=4:
		errors.append("cardinal root/structure is not four stationary views")
	if not actor.find_children("*","CollisionObject2D",true,false).is_empty(): errors.append("cardinal art owns gameplay collision")
	for item in [actor]+actor.find_children("*","CanvasItem",true,false):
		if not is_equal_approx(item.modulate.a,1) or not is_equal_approx(item.self_modulate.a,1): errors.append("cardinal ancestor tint is translucent")
	var meshes := {}
	for direction in VIEWS:
		var view := actor.get_node_or_null(direction) as Node2D
		if view==null:
			errors.append("cardinal view absent")
			continue
		var rig := view.get_node_or_null("Skeleton2D") as Skeleton2D
		var skin := view.get_node_or_null("Skin") as Polygon2D
		if rig==null or skin==null:
			errors.append("cardinal rig/skin absent")
			continue
		if not view.transform.is_equal_approx(Transform2D.IDENTITY) or rig.find_children("*","Bone2D",true,false).size()!=bone_count or skin.get_bone_count()!=skin_bones:
			errors.append("cardinal joints/body binding/root mirror disagreement")
		if skin.texture!=null or skin.get_script()!=null or skin.vertex_colors.size()!=skin.polygon.size(): errors.append("cardinal body depends on raster/builder or lacks colors")
		for color in skin.vertex_colors:
			if not _opaque(color): errors.append("cardinal body color is nonfinite/translucent")
		errors.append_array(Geometry.new().validate(rig,skin,[actor,view,skin]))
		meshes[direction] = [skin.polygon,skin.vertex_colors]
		var weapon := view.get_node_or_null(WEAPON) as Bone2D
		if weapon==null or not weapon.get_parent() is Bone2D or weapon.position!=Vector2.ZERO or weapon.get_node_or_null("Muzzle")==null:
			errors.append("cardinal weapon detached/missing hand mount")
			continue
		for part in ["Pistol","CopperSlide"]:
			var surface := weapon.get_node_or_null(part) as Polygon2D
			if not _rigid_surface_valid(surface): errors.append("rigid hand weapon invalid/translucent/raster")
	if meshes.has_all(VIEWS) and (meshes.Front==meshes.Back or meshes.Left==meshes.Right): errors.append("cardinal front/back or left/right geometry duplicated")
	return errors
func _rigid_surface_valid(surface: Polygon2D) -> bool:
	if surface==null or surface.texture!=null or surface.get_script()!=null or not _opaque(surface.color): return false
	if not surface.vertex_colors.is_empty() and surface.vertex_colors.size()!=surface.polygon.size(): return false
	for color in surface.vertex_colors:
		if not _opaque(color): return false
	for point in surface.polygon:
		if not point.is_finite(): return false
	return not Geometry2D.triangulate_polygon(surface.polygon).is_empty()
func _count(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(value) and value>=1 and value<=128 and float(value)==floorf(value)
func _opaque(color: Color) -> bool:
	return is_equal_approx(color.a,1) and is_finite(color.r) and is_finite(color.g) and is_finite(color.b)
func _path(value: Variant,prefix: String,extension: String) -> bool:
	return value is String and value.begins_with(prefix) and value.ends_with(extension) and ".." not in value and "\\" not in value and FileAccess.file_exists(value)
