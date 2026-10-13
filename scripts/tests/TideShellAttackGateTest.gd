extends SceneTree
const Gate = preload("res://scripts/art/NativeRigCheckpoint.gd")
const PROOF := "res://docs/art/native-checkpoints/tide_shell_attack_v1.json"
var checks := 0
var failures := 0
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("TEST FAIL: TideShellAttackGateTest "+label)
func _initialize() -> void:
	var gate := Gate.new()
	var entry := {"asset_id":"tide_shell_paper_v2","role":"boss","bone_count":25,"runtime_scene":"res://scenes/actors/native/tide_shell_paper_v2.tscn","motion_library":"res://assets/art/actors/native/tide_shell_motion_v2.tres","rig_checkpoint":PROOF}
	check(gate.validate_entry(entry).is_empty(),"explicit covered tide-shell migration absent")
	for proof in ["res://docs/art/native-checkpoints/all_character_rigs_v1.json","res://docs/art/native-checkpoints/furnace_foreman_attack_v1.json","res://docs/art/native-checkpoints/vine_guard_attack_v1.json"]:
		var wrong := entry.duplicate(true)
		wrong.rig_checkpoint = proof
		check(not gate.validate_entry(wrong).is_empty(),"unrelated approval authorizes tide-shell")
	for pair in [["asset_id","tide_shell_paper_v1"],["role","large"],["bone_count",24],["runtime_scene","res://scenes/actors/native/tide_shell_paper_v1.tscn"],["motion_library","res://assets/art/actors/native/tide_shell_motion_v1.tres"]]:
		var wrong := entry.duplicate(true)
		wrong[pair[0]] = pair[1]
		check(not gate.validate_entry(wrong).is_empty(),"unreviewed anatomy/version accepted")
	if FileAccess.file_exists(PROOF):
		var proof: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PROOF))
		for field in ["coverage_sha256","review_sha256"]:
			var wrong := proof.duplicate(true)
			wrong[field] = "0".repeat(64)
			check(not gate.validate_checkpoint(wrong,entry).is_empty(),"mutated frozen evidence accepted")
		var wrong := proof.duplicate(true)
		wrong.scope = "chapter-three-complete"
		check(not gate.validate_checkpoint(wrong,entry).is_empty(),"rig gate used as gameplay completion")
	if not failures: print("TEST PASS: TideShellAttackGateTest %d" % checks)
	quit(1 if failures else 0)
