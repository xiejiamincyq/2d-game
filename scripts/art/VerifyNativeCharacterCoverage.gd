extends SceneTree
## Author-only coverage/provenance record. Never opens the attack gate itself.
const Roster = preload("res://scripts/tests/NativeCharacterRosterTest.gd")
const Validator = preload("res://scripts/art/NativeArtValidator.gd")
const ACTORS := ["CapsulePlanterEnemy.gd","CirclingShadeEnemy.gd","DroneVisual.gd","EchoSentinelEnemy.gd","EmberSparkEnemy.gd","Enemy.gd","FlankingCrabEnemy.gd","FoundryFurnaceBoss.gd","NurseryVineBoss.gd","OverseerBoss.gd","Player.gd","RiftEliteEnemy.gd","SpaceCutterEnemy.gd","SplittingMoteEnemy.gd"]
func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size()!=1 or not args[0].is_valid_identifier():
		push_error("CHARACTER COVERAGE FAIL: unused output identifier required")
		quit(1)
		return
	var output := "res://build/diagnostics/campaign-goal/"+args[0]+".json"
	if FileAccess.file_exists(output):
		push_error("CHARACTER COVERAGE FAIL: output already exists")
		quit(1)
		return
	var errors := PackedStringArray()
	var expected: Array[String] = []
	for entry in Roster.NPCS: expected.append("res://scenes/actors/native/"+entry[0]+".tscn")
	expected.append_array(["res://scenes/actors/native/player_paper_v1.tscn","res://scenes/actors/native/ranger_drone_paper_v1.tscn"])
	var rows: Array[Dictionary] = []
	var seen: Array[String] = []
	var sources := {}
	for filename in DirAccess.get_files_at("res://scripts/actors"):
		if not filename.ends_with(".gd"): continue
		if filename not in ACTORS: errors.append("unreviewed production actor script "+filename)
		else: sources["scripts/actors/"+filename] = FileAccess.get_sha256("res://scripts/actors/"+filename)
	for filename in ACTORS:
		if not FileAccess.file_exists("res://scripts/actors/"+filename): errors.append("actor script missing "+filename)
	for filename in DirAccess.get_files_at("res://docs/art/native-manifests"):
		if not filename.ends_with(".json"): continue
		var manifest := "res://docs/art/native-manifests/"+filename
		var entry: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(manifest))
		if entry.runtime_scene not in expected: continue # Historical resource versions are not current bodies.
		errors.append_array(Validator.new().validate_entry(entry))
		if entry.runtime_scene in seen: errors.append("duplicate current body declaration")
		seen.append(entry.runtime_scene)
		if entry.review_state not in ["style-approved","gameplay-approved","final"]: errors.append("unreviewed current character style")
		var libraries: Array = entry.motion_libraries.values() if entry.role=="player" else [entry.motion_library]
		var hashes := {}
		for library in libraries: hashes[str(library)] = FileAccess.get_sha256(library)
		rows.append({"asset_id":entry.asset_id,"runtime_scene":entry.runtime_scene,"scene_sha256":FileAccess.get_sha256(entry.runtime_scene),"manifest":manifest,"manifest_sha256":FileAccess.get_sha256(manifest),"bone_count":entry.bone_count,"role":entry.role,"required_clips":entry.required_clips,"review_state":entry.review_state,"license_origin":entry.license_origin,"motion_sha256":hashes,"chapter_combat_ready":entry.runtime_scene in ["res://scenes/actors/native/vine_guard_paper_v2.tscn","res://scenes/actors/native/furnace_foreman_paper_v2.tscn"] if entry.role=="boss" else null})
	for scene in expected:
		if scene not in seen: errors.append("missing current character declaration "+scene)
	var report := {"passed":errors.is_empty(),"current_bodies":expected.size(),"production_actor_scripts":ACTORS.size(),"historical_excluded":["cinder_runner_paper_v1","stone_carrier_paper_v1","furnace_foreman_paper_v1"],"scope":"rig/resource/production-entry coverage only; two chapter Boss combat Actors, not final art, all large attacks or six chapter completion","characters":rows,"sources":sources,"errors":errors}
	var file := FileAccess.open(output,FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(report,"\t"))
		file.close()
	else: errors.append("report cannot be written")
	for error in errors: push_error("CHARACTER COVERAGE FAIL: "+error)
	if errors.is_empty(): print("CHARACTER COVERAGE PASS: %d current body resources/%d production actor scripts; six chapter Boss resources, two actual combat Actors"%[expected.size(),ACTORS.size()])
	quit(0 if errors.is_empty() else 1)
