extends SceneTree

const ACTOR_PATH := "res://scenes/art/technical/PaperStyleActor.gd"
const EFFECT_PATH := "res://scenes/art/technical/PaperImpactDraft.gd"
const Validator = preload("res://scripts/art/NativeArtValidator.gd")
var assertions := 0
var failures := 0

func check(ok: bool, label: String) -> void:
	assertions += 1
	if not ok:
		failures += 1
		push_error("TEST FAIL: PaperStyleGroupTest " + label)

func _initialize() -> void:
	await process_frame
	check(FileAccess.file_exists(ACTOR_PATH), "original native style actors absent")
	check(FileAccess.file_exists(EFFECT_PATH), "compact original effect absent")
	if failures:
		quit(1)
		return
	var manifest_path := "res://docs/art/style-manifests/paper_style_group_v1.json"
	var manifest = JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
	check(manifest is Dictionary and manifest.get("contract") == "native-style-group-preview-v1", "style preview contract absent")
	if not manifest is Dictionary:
		quit(1)
		return
	check(manifest.get("review_state") == "style-approved" and manifest.get("license_origin") == "project-original", "wrong style-only approval/source claim")
	check(manifest.get("assets") is Array and manifest.assets.size() == 4, "style group incomplete")
	for entry in manifest.get("assets", []):
		check(FileAccess.file_exists(entry.get("authoring_source", "")), "original authoring source missing")
	for field in ["preview", "opacity_report", "review_document"]:
		check(FileAccess.file_exists(manifest.get(field, "")), "style evidence missing " + field)
	check(manifest.get("external_raster_dependencies") == [] and manifest.get("limitations", []).size() >= 6, "preview hides provenance or scope limitations")
	var script = load(ACTOR_PATH)
	var effect_script = load(EFFECT_PATH)
	check(script != null and script.can_instantiate(), "actor script parse failure")
	check(effect_script != null and effect_script.can_instantiate(), "effect script parse failure")
	if failures:
		quit(1)
		return
	var bounds: Array[Rect2] = []
	for kind in ["player", "large"]:
		var actor = script.new()
		actor.kind = kind
		root.add_child(actor)
		var rig: Skeleton2D = actor.get_node("Facing/Skeleton2D")
		var skin: Polygon2D = actor.get_node("Facing/Skin")
		check(Validator.new().validate_geometry(actor).is_empty(), kind + " native weights/rest invalid")
		check(rig.get_bone_count() == 12 and skin.get_bone_count() == 12, kind + " incomplete native bone hierarchy")
		check(skin.texture == null and skin.vertex_colors.size() == skin.polygon.size(), kind + " uses raster source")
		var opaque := true
		for color in skin.vertex_colors:
			opaque = opaque and is_equal_approx(color.a, 1)
		check(opaque, kind + " translucent body")
		check(actor.find_children("*", "CollisionObject2D", true, false).is_empty(), kind + " owns gameplay collision")
		check(actor.find_children("*", "AnimationPlayer", true, false).is_empty(), kind + " premature motion/large attack")
		var bounds_here := Rect2(skin.polygon[0], Vector2.ZERO)
		for point in skin.polygon:
			bounds_here = bounds_here.expand(point)
		bounds.append(bounds_here)
		if kind == "player":
			var grip: Node2D = actor.get_node("Facing/Skeleton2D/Torso/ArmR/ForearmR/HandR/WeaponGrip")
			var weapon: Polygon2D = grip.get_node("Weapon")
			check(weapon.texture == null and grip.get_parent() is Bone2D, "weapon is not held by native hand")
			check(grip.position.length() <= 4 and grip.rotation == 0, "weapon orbit offset")
			var before := grip.global_position
			actor.get_node("Facing/Skeleton2D/Torso/ArmR").rotation = 0.4
			check(before.distance_to(grip.global_position) > 3, "shoulder does not move weapon through hand chain")
			check(actor.position == Vector2.ZERO and actor.rotation == 0, "pose moves gameplay root")
			check(weapon.polygon.size() >= 4 and weapon.color.a == 1, "weapon geometry/opacity missing")
		else:
			check(actor.find_children("WeaponGrip", "Node2D", true, false).is_empty(), "large placeholder reuses player weapon")
		actor.free()
	check(bounds[1].size.x > bounds[0].size.x * 1.4, "large silhouette is not differentiated")
	check(bounds[1].size.y > bounds[0].size.y * 1.2, "large silhouette too small")
	var effect = effect_script.new()
	root.add_child(effect)
	check(effect.find_children("*", "CollisionObject2D", true, false).is_empty(), "effect deals gameplay damage")
	effect.set_phase(-2)
	check(effect.phase == 0, "negative visual time")
	effect.set_phase(2)
	check(effect.phase == 1, "visual time exceeds duration")
	check(is_equal_approx(effect.duration, 0.14) and effect.radius <= 15, "impact too long or expansive")
	effect.set_phase(0.5)
	effect.set_phase(NAN)
	effect.set_phase(INF)
	check(effect.phase == 0.5, "nonfinite phase corrupts visual state")
	check(effect.modulate.a == 1 and effect.self_modulate.a == 1, "effect fades entire body")
	effect.free()
	if not failures:
		print("TEST PASS: PaperStyleGroupTest %d" % assertions)
	quit(0 if not failures else 1)
