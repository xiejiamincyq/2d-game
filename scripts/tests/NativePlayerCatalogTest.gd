extends SceneTree
const Validator = preload("res://scripts/art/NativeArtValidator.gd")
const MANIFEST := "res://docs/art/native-manifests/player_paper_v1.json"
var checks := 0
var failures := 0
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("TEST FAIL: NativePlayerCatalogTest "+label)
func _initialize() -> void:
	var entry = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
	check(entry is Dictionary,"four-view manifest absent")
	if failures:
		quit(1)
		return
	var validator := Validator.new()
	check(validator.validate_entry(entry).is_empty(),"unified catalog rejects actual four-view player")
	check(validator.has_method("validate_player_geometry"),"cardinal geometry gate absent")
	if failures:
		quit(1)
		return
	for field in ["layout","runtime_scene","bone_count","skin_bone_count","motion_libraries","license_origin","required_clips"]:
		var wrong: Dictionary = entry.duplicate(true)
		wrong.erase(field)
		check(not validator.validate_entry(wrong).is_empty(),"missing field accepted "+field)
	for count in [true,"13",13.5,NAN,INF,-1]:
		var wrong: Dictionary = entry.duplicate(true)
		wrong.bone_count = count
		check(not validator.validate_entry(wrong).is_empty(),"malformed per-view bone count accepted")
	for direction in ["Front","Back","Left","Right"]:
		var wrong: Dictionary = entry.duplicate(true)
		wrong.motion_libraries.erase(direction)
		check(not validator.validate_entry(wrong).is_empty(),"missing cardinal library accepted")
		wrong = entry.duplicate(true)
		wrong.motion_libraries[direction] = "res://assets/art/actors/native/rootling_motion_v3.tres"
		check(not validator.validate_entry(wrong).is_empty(),"unused/wrong directional library accepted")
	for change in [{"role":"ordinary"},{"layout":"single"},{"review_state":"final"},{"skin_bone_count":13},{"required_clips":["absent"]}]:
		var wrong: Dictionary = entry.duplicate(true)
		wrong.merge(change,true)
		check(not validator.validate_entry(wrong).is_empty(),"invalid cardinal contract accepted "+str(change))
	var actor = load(entry.runtime_scene).instantiate()
	check(validator.validate_player_geometry(actor).is_empty(),"actual opaque body and hand weapon rejected")
	var bare := Node.new()
	check(not validator.validate_player_geometry(bare).is_empty(),"nonvisual root crashes or is accepted")
	bare.free()
	actor.modulate.a = 0.5
	check(not validator.validate_player_geometry(actor).is_empty(),"parent opacity accepted")
	actor.modulate.a = 1
	for direction in ["Front","Back","Left","Right"]:
		var view: Node2D = actor.get_node(direction)
		var skin: Polygon2D = view.get_node("Skin")
		var rig: Skeleton2D = view.get_node("Skeleton2D")
		var weapon: Bone2D = rig.get_node("Torso/ArmR/ForearmR/HandR/Weapon")
		skin.color.a = 0.5
		check(not validator.validate_player_geometry(actor).is_empty(),"translucent directional body accepted")
		skin.color.a = 1
		var weights := skin.get_bone_weights(0)
		skin.set_bone_weights(0,PackedFloat32Array())
		check(not validator.validate_player_geometry(actor).is_empty(),"partial weights accepted")
		skin.set_bone_weights(0,weights)
		view.scale = Vector2(-1,1)
		check(not validator.validate_player_geometry(actor).is_empty(),"cardinal view replaced by root mirror")
		view.scale = Vector2.ONE
		weapon.position = Vector2(80,0)
		check(not validator.validate_player_geometry(actor).is_empty(),"detached/orbiting weapon accepted")
		weapon.apply_rest()
		var pistol: Polygon2D = weapon.get_node("Pistol")
		pistol.color.a = 0.5
		check(not validator.validate_player_geometry(actor).is_empty(),"translucent rigid gun accepted")
		pistol.color.a = 1
		var tints := PackedColorArray()
		tints.resize(pistol.polygon.size())
		tints.fill(Color(1,1,1,0.5))
		pistol.vertex_colors = tints
		check(not validator.validate_player_geometry(actor).is_empty(),"per-vertex translucent gun accepted")
		pistol.vertex_colors = PackedColorArray()
	var front: Polygon2D = actor.get_node("Front/Skin")
	var back: Polygon2D = actor.get_node("Back/Skin")
	var original_points := back.polygon
	var original_colors := back.vertex_colors
	back.polygon = front.polygon
	back.vertex_colors = front.vertex_colors
	check(not validator.validate_player_geometry(actor).is_empty(),"front/back duplicate geometry accepted")
	back.polygon = original_points
	back.vertex_colors = original_colors
	check(validator.validate_player_geometry(actor).is_empty(),"restored player remains invalid")
	actor.free()
	if not failures: print("TEST PASS: NativePlayerCatalogTest %d" % checks)
	quit(1 if failures else 0)
