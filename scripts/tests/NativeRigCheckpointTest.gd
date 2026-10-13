extends SceneTree
const SOURCE := "res://scripts/art/NativeRigCheckpoint.gd"
const PROOF := "res://docs/art/native-checkpoints/all_character_rigs_v1.json"
var checks := 0
var failures := 0
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("TEST FAIL: NativeRigCheckpointTest "+label)
func _initialize() -> void:
	check(FileAccess.file_exists(SOURCE),"explicit post-rig checkpoint validator missing")
	if failures:
		quit(1)
		return
	var gate = load(SOURCE).new()
	var entry := {"asset_id":"stone_carrier_paper_v2","role":"large","bone_count":17,"runtime_scene":"res://scenes/actors/native/stone_carrier_paper_v2.tscn","motion_library":"res://assets/art/actors/native/stone_carrier_motion_v2.tres","rig_checkpoint":PROOF}
	check(gate.validate_entry(entry).is_empty(),"reviewed carrier request rejected")
	var proof: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PROOF))
	for field in ["schema_version","review_state","scope","coverage_report","coverage_sha256","review_document","review_sha256","authorized_assets"]:
		var bad := proof.duplicate(true)
		bad.erase(field)
		check(not gate.validate_checkpoint(bad,entry).is_empty(),"missing field accepted "+field)
	for field in ["coverage_sha256","review_sha256"]:
		var bad := proof.duplicate(true)
		bad[field] = "0".repeat(64)
		check(not gate.validate_checkpoint(bad,entry).is_empty(),"changed review evidence accepted "+field)
	for state in [true,"draft","final","independent-approved"]:
		var bad := proof.duplicate(true)
		bad.review_state = state
		check(not gate.validate_checkpoint(bad,entry).is_empty(),"invalid review state accepted")
	for path in [true,"res://docs/missing.json","res://docs/../project.godot","user://proof.json"]:
		var bad := entry.duplicate(true)
		bad.rig_checkpoint = path
		check(not gate.validate_entry(bad).is_empty(),"unsafe/unknown proof accepted")
	for field in ["asset_id","role","bone_count","runtime_scene","motion_library"]:
		var bad := entry.duplicate(true)
		bad[field] = "unreviewed"
		check(not gate.validate_entry(bad).is_empty(),"unreviewed candidate accepted "+field)
	for value in [true,[],{},17.5,NAN,INF]:
		var invalid := entry.duplicate(true)
		invalid.bone_count = value
		check(not gate.validate_entry(invalid).is_empty(),"invalid joint-count type/value accepted")
	for value in [true,[],{},null]:
		var invalid := proof.duplicate(true)
		invalid.authorized_assets = {"stone_carrier_paper_v2":value}
		check(not gate.validate_checkpoint(invalid,entry).is_empty(),"malformed authorized baseline accepted")
	var bad := proof.duplicate(true)
	bad.authorized_assets = {"stone_carrier_paper_v2":"missing_baseline"}
	check(not gate.validate_checkpoint(bad,entry).is_empty(),"uncovered baseline accepted")
	bad = proof.duplicate(true)
	bad.scope = "six-chapters-complete"
	check(not gate.validate_checkpoint(bad,entry).is_empty(),"resource gate promoted to campaign gate")
	bad = entry.duplicate(true)
	bad.erase("rig_checkpoint")
	check(not gate.validate_entry(bad).is_empty(),"large attacks enabled by default")
	var commander := {"asset_id":"root_commander_paper_v2","role":"large","bone_count":23,"runtime_scene":"res://scenes/actors/native/root_commander_paper_v2.tscn","motion_library":"res://assets/art/actors/native/root_commander_motion_v2.tres","rig_checkpoint":"res://docs/art/native-checkpoints/root_commander_attack_v1.json"}
	check(gate.validate_entry(commander).is_empty(),"separately reviewed commander request rejected")
	commander.rig_checkpoint = PROOF
	check(not gate.validate_entry(commander).is_empty(),"carrier approval silently authorizes commander")
	var vine := {"asset_id":"vine_guard_paper_v2","role":"boss","bone_count":22,"runtime_scene":"res://scenes/actors/native/vine_guard_paper_v2.tscn","motion_library":"res://assets/art/actors/native/vine_guard_motion_v2.tres","rig_checkpoint":"res://docs/art/native-checkpoints/vine_guard_attack_v1.json"}
	check(gate.validate_entry(vine).is_empty(),"separately reviewed first-chapter Boss request rejected")
	vine.rig_checkpoint = "res://docs/art/native-checkpoints/root_commander_attack_v1.json"
	check(not gate.validate_entry(vine).is_empty(),"commander approval silently authorizes another Boss")
	var furnace := {"asset_id":"furnace_foreman_paper_v2","role":"boss","bone_count":23,"runtime_scene":"res://scenes/actors/native/furnace_foreman_paper_v2.tscn","motion_library":"res://assets/art/actors/native/furnace_foreman_motion_v2.tres","rig_checkpoint":"res://docs/art/native-checkpoints/furnace_foreman_attack_v1.json"}
	check(gate.validate_entry(furnace).is_empty(),"explicit covered furnace request rejected")
	furnace.rig_checkpoint = "res://docs/art/native-checkpoints/vine_guard_attack_v1.json"
	check(not gate.validate_entry(furnace).is_empty(),"vine proof silently approves furnace")
	if not failures:
		print("TEST PASS: NativeRigCheckpointTest %d" % checks)
	quit(1 if failures else 0)
