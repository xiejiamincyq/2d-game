extends SceneTree
## Explicit resource migration only, not fifth-chapter victory/readiness.
const Gate = preload("res://scripts/art/NativeRigCheckpoint.gd")
const PROOF := "res://docs/art/native-checkpoints/bell_priest_attack_v1.json"
var checks := 0
var failures := 0
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error("TEST FAIL: BellPriestAttackGateTest "+label)
func _initialize() -> void:
	var gate := Gate.new()
	var entry := {"asset_id":"bell_priest_paper_v2","role":"boss","bone_count":26,"runtime_scene":"res://scenes/actors/native/bell_priest_paper_v2.tscn","motion_library":"res://assets/art/actors/native/bell_priest_motion_v2.tres","rig_checkpoint":PROOF}
	check(gate.validate_entry(entry).is_empty(),"explicit covered bell-priest request missing")
	for path in Gate.REQUESTS:
		if path==PROOF: continue
		var wrong := entry.duplicate(true); wrong.rig_checkpoint = path
		check(not gate.validate_entry(wrong).is_empty(),"another rig approval authorizes priest")
	for pair in [["asset_id","bell_priest_paper_v1"],["role","large"],["bone_count",25],["runtime_scene","res://scenes/actors/native/bell_priest_paper_v1.tscn"],["motion_library","res://assets/art/actors/native/bell_priest_motion_v1.tres"]]:
		var wrong := entry.duplicate(true); wrong[pair[0]] = pair[1]
		check(not gate.validate_entry(wrong).is_empty(),"unreviewed anatomy/version accepted")
	if FileAccess.file_exists(PROOF):
		var proof: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PROOF))
		for field in ["coverage_sha256","review_sha256"]:
			var wrong := proof.duplicate(true); wrong[field] = "0".repeat(64)
			check(not gate.validate_checkpoint(wrong,entry).is_empty(),"changed frozen evidence accepted")
		var wrong := proof.duplicate(true); wrong.scope = "chapter-five-complete"
		check(not gate.validate_checkpoint(wrong,entry).is_empty(),"resource scope becomes chapter completion")
		wrong = proof.duplicate(true); wrong.authorized_assets = {"bell_priest_paper_v2":"spore_archivist_paper_v1"}
		check(not gate.validate_checkpoint(wrong,entry).is_empty(),"foreign rig silently substitutes")
	if not failures: print("TEST PASS: BellPriestAttackGateTest %d"%checks)
	quit(1 if failures else 0)
