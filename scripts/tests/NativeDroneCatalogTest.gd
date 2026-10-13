extends SceneTree
const Validator = preload("res://scripts/art/NativeArtValidator.gd")
var assertions := 0
var failures := 0
func check(ok: bool,message: String) -> void:
	assertions += 1
	if not ok:
		failures += 1
		push_error("TEST FAIL: NativeDroneCatalogTest "+message)
func _initialize() -> void:
	var entry: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://docs/art/native-manifests/ranger_drone_paper_v1.json"))
	var validator = Validator.new()
	check(validator.validate_entry(entry).is_empty(),"real friendly companion catalog contract rejected")
	for field in ["bone_count","role","motion_library","runtime_scene"]:
		var bad := entry.duplicate(true)
		bad[field] = 9 if field=="bone_count" else "unreviewed"
		check(not validator.validate_entry(bad).is_empty(),"invalid companion declaration accepted "+field)
	var bad := entry.duplicate(true)
	bad.review_state = "final"
	check(not validator.validate_entry(bad).is_empty(),"final claim lacks actual evidence")
	bad = entry.duplicate(true)
	bad.required_clips.append("missing")
	check(not validator.validate_entry(bad).is_empty(),"missing companion clip accepted")
	var actor = load(entry.runtime_scene).instantiate()
	var skin: Polygon2D = actor.get_node("Facing/Skin")
	skin.color.a = 0.5
	check(not validator.validate_geometry(actor).is_empty(),"translucent companion accepted")
	skin.color.a = 1
	check(validator.validate_geometry(actor).is_empty(),"restored companion geometry rejected")
	actor.free()
	if failures==0: print("TEST PASS: NativeDroneCatalogTest %d"%assertions)
	quit(1 if failures else 0)
