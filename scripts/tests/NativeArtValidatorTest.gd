extends SceneTree

const SOURCE := "res://scripts/art/NativeArtValidator.gd"
const SCENE := "res://scenes/actors/native/rootling_paper_v3.tscn"
var assertions := 0
var failures := 0

func check(ok: bool, label: String) -> void:
	assertions += 1
	if not ok:
		failures += 1
		push_error("TEST FAIL: NativeArtValidatorTest " + label)

func _initialize() -> void:
	check(FileAccess.file_exists(SOURCE), "native resource validator missing")
	if failures:
		quit(1)
		return
	var validator = load(SOURCE).new()
	var entry := {"asset_id": "enemy_root_pursuer_paper_v1", "runtime_scene": SCENE, "motion_library": "res://assets/art/actors/native/rootling_motion_v3.tres", "role": "ordinary", "review_state": "draft", "bone_count": 12, "license_origin": "project-original", "required_clips": ["idle", "walk", "warning", "attack", "hit", "death"]}
	check(validator.validate_entry(entry).is_empty(), "valid editable native scene rejected")
	var from_json: Dictionary = JSON.parse_string(JSON.stringify(entry))
	check(validator.validate_entry(from_json).is_empty(), "JSON numeric joint count cannot round-trip")
	for count in [true, "12", 12.5, NAN, INF, -1]:
		var wrong := entry.duplicate(true)
		wrong.bone_count = count
		check(not validator.validate_entry(wrong).is_empty(), "malformed numeric joint count accepted")
	for field in ["asset_id", "runtime_scene", "motion_library", "role", "review_state", "bone_count", "license_origin", "required_clips"]:
		var missing := entry.duplicate(true)
		missing.erase(field)
		check(not validator.validate_entry(missing).is_empty(), "missing contract accepted " + field)
	for invalid_path in ["res://scenes/actors/native/../technical/NativeMonsterSample.tscn", "res://scenes/art/technical/NativeMonsterSample.tscn", "user://bad.tscn", "res://scenes/actors/native/absent.tscn"]:
		var bad := entry.duplicate(true)
		bad.runtime_scene = invalid_path
		check(not validator.validate_entry(bad).is_empty(), "unsafe/missing runtime resource accepted")
	var bad := entry.duplicate(true)
	bad.bone_count = 1
	check(not validator.validate_entry(bad).is_empty(), "declared joints disagree with resource")
	bad = entry.duplicate(true)
	bad.required_clips.append("absent")
	check(not validator.validate_entry(bad).is_empty(), "missing native motion accepted")
	bad = entry.duplicate(true)
	bad.role = "large"
	check(not validator.validate_entry(bad).is_empty(), "large attack content slips past deferred gate")
	bad = entry.duplicate(true)
	bad.review_state = "final"
	check(not validator.validate_entry(bad).is_empty(), "final declaration accepted without review evidence")
	bad = entry.duplicate(true)
	bad.license_origin = "unknown"
	check(not validator.validate_entry(bad).is_empty(), "unreviewed origin accepted")
	bad = entry.duplicate(true)
	bad.motion_library = "res://assets/art/actors/native/absent.tres"
	check(not validator.validate_entry(bad).is_empty(), "unused/missing library declared")
	for key in ["gameplay_capture", "opacity_report", "review_document"]:
		bad = entry.duplicate(true)
		bad.review_state = "final"
		bad.runtime_evidence = {"gameplay_capture": SCENE, "opacity_report": SCENE, "review_document": SCENE}
		bad.runtime_evidence[key] = "res://docs/missing-proof.txt"
		check(not validator.validate_entry(bad).is_empty(), "missing evidence file accepted " + key)
	var actor = load(SCENE).instantiate()
	check(validator.has_method("validate_geometry"), "native weight/pose gate missing")
	if validator.has_method("validate_geometry"):
		check(validator.validate_geometry(actor).is_empty(), "valid original geometry rejected")
		var skin: Polygon2D = actor.get_node("Facing/Skin")
		var original_weights := skin.get_bone_weights(0)
		skin.set_bone_weights(0, PackedFloat32Array())
		check(not validator.validate_geometry(actor).is_empty(), "partial weight arrays accepted")
		skin.set_bone_weights(0, original_weights)
		var old_path := skin.skeleton
		skin.skeleton = NodePath("../Missing")
		check(not validator.validate_geometry(actor).is_empty(), "skin bound to missing rig")
		skin.skeleton = old_path
		actor.modulate.a = 0.5
		check(not validator.validate_geometry(actor).is_empty(), "ancestor makes opaque geometry translucent")
		actor.modulate.a = 1
		skin.color.a = 0.5
		check(not validator.validate_geometry(actor).is_empty(), "Polygon2D base color makes the skin translucent")
	actor.free()
	if not failures:
		print("TEST PASS: NativeArtValidatorTest %d" % assertions)
	quit(1 if failures else 0)
