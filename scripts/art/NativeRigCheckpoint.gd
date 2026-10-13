extends RefCounted
## Author-only gate. Frozen baseline resources remain available as history;
## later Actor migrations do not invalidate an already-reviewed rig checkpoint.
const PROOF := "res://docs/art/native-checkpoints/all_character_rigs_v1.json"
const REQUESTS := [PROOF,"res://docs/art/native-checkpoints/root_commander_attack_v1.json","res://docs/art/native-checkpoints/vine_guard_attack_v1.json","res://docs/art/native-checkpoints/furnace_foreman_attack_v1.json","res://docs/art/native-checkpoints/tide_shell_attack_v1.json","res://docs/art/native-checkpoints/spore_archivist_attack_v1.json","res://docs/art/native-checkpoints/bell_priest_attack_v1.json","res://docs/art/native-checkpoints/rift_observer_attack_v1.json","res://docs/art/native-checkpoints/legacy_overseer_attack_v1.json"]
const COVERAGE := "res://docs/art/previews/campaign/native-character-coverage-v1.json"
const REVIEW := "res://docs/art/native-character-roster-review-v1.md"
const FIELDS := ["schema_version","review_state","scope","coverage_report","coverage_sha256","review_document","review_sha256","authorized_assets"]

func validate_entry(entry: Dictionary) -> PackedStringArray:
	if not entry.get("rig_checkpoint") is String or entry.rig_checkpoint not in REQUESTS or not FileAccess.file_exists(entry.rig_checkpoint):
		return PackedStringArray(["post-rig attack lacks the reviewed resource checkpoint"])
	var proof = JSON.parse_string(FileAccess.get_file_as_string(entry.rig_checkpoint))
	if not proof is Dictionary:
		return PackedStringArray(["invalid rig checkpoint JSON"])
	return validate_checkpoint(proof,entry)

func validate_checkpoint(proof: Dictionary,entry: Dictionary) -> PackedStringArray:
	if not proof.has_all(FIELDS) or not (proof.schema_version is int or proof.schema_version is float) or proof.schema_version != 1 or not proof.review_state is String or proof.review_state != "author-approved" or not proof.scope is String or proof.scope != "character-rig-resources-only":
		return PackedStringArray(["invalid rig checkpoint scope/state"])
	if not proof.coverage_report is String or proof.coverage_report != COVERAGE or not proof.review_document is String or proof.review_document != REVIEW or not _matches(COVERAGE,proof.coverage_sha256) or not _matches(REVIEW,proof.review_sha256):
		return PackedStringArray(["rig coverage/review evidence changed or missing"])
	if not entry.has_all(["asset_id","role","bone_count","runtime_scene","motion_library"]):
		return PackedStringArray(["attack migration request has missing fields"])
	for field in ["asset_id","role","runtime_scene","motion_library"]:
		if not entry[field] is String:
			return PackedStringArray(["invalid attack migration string"])
	if not (entry.bone_count is int or entry.bone_count is float) or not is_finite(entry.bone_count):
		return PackedStringArray(["invalid attack migration joint count"])
	if not proof.authorized_assets is Dictionary or not entry.get("asset_id") is String or not proof.authorized_assets.has(entry.asset_id):
		return PackedStringArray(["attack asset has no reviewed migration request"])
	var baseline_id = proof.authorized_assets[entry.asset_id]
	if not baseline_id is String or baseline_id.is_empty():
		return PackedStringArray(["attack request has invalid baseline identifier"])
	var report = JSON.parse_string(FileAccess.get_file_as_string(COVERAGE))
	if not report is Dictionary or report.get("passed") != true or report.get("current_bodies") != 23 or not report.get("characters") is Array or report.characters.size() != 23:
		return PackedStringArray(["incomplete baseline character coverage"])
	var errors := PackedStringArray()
	var seen: Array[String] = []
	var baseline: Dictionary = {}
	for character in report.characters:
		if not character is Dictionary or not character.has_all(["asset_id","runtime_scene","scene_sha256","manifest","manifest_sha256","motion_sha256"]) or not character.asset_id is String or character.asset_id in seen or not character.motion_sha256 is Dictionary:
			return PackedStringArray(["invalid/duplicate baseline character declaration"])
		seen.append(character.asset_id)
		if character.asset_id == baseline_id:
			baseline = character
		for pair in [[character.runtime_scene,character.scene_sha256],[character.manifest,character.manifest_sha256]]:
			if not _matches(pair[0],pair[1]):
				errors.append("reviewed baseline resource changed: "+str(pair[0]))
		for path in character.motion_sha256:
			if not _matches(path,character.motion_sha256[path]):
				errors.append("reviewed baseline motion changed: "+str(path))
	if baseline.is_empty() or baseline.get("role") not in ["large","boss"] or entry.get("role") != baseline.get("role") or entry.get("bone_count") != baseline.get("bone_count"):
		errors.append("attack candidate disagrees with its covered large rig")
	if entry.get("runtime_scene") != "res://scenes/actors/native/"+entry.asset_id+".tscn" or entry.get("motion_library") != "res://assets/art/actors/native/"+entry.asset_id.replace("_paper_","_motion_")+".tres":
		errors.append("attack migration is not a separately versioned resource")
	return errors

func _matches(path: Variant,expected: Variant) -> bool:
	return path is String and expected is String and expected.length()==64 and path.begins_with("res://") and ".." not in path and "\\" not in path and FileAccess.file_exists(path) and FileAccess.get_sha256(path)==expected
