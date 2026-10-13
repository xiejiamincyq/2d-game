extends RefCounted
## Metadata validation is not proof of a victory by itself. The serial launcher
## must also verify actual process exit, canonical sources, parent report/file
## SHA and real Main restore. This module never records defeats or writes saves.
const Progress = preload("res://scripts/systems/CampaignProgress.gd")
const Store = preload("res://scripts/systems/CampaignProgressStore.gd")
const EVIDENCE_ROOT := "res://build/diagnostics/campaign-goal/"
const MARKERS := ["VerifyNurseryChapterFlow", "VerifyFoundryChapterFlow", "VerifySaltChapterFlow", "VerifyArchiveChapterFlow", "VerifyEchoChapterFlow", "VerifyRiftChapterFlow"]
const FORBIDDEN := "SCRIPT ERROR|ERROR:|TEST FAIL:|ObjectDB instances were leaked|RID.+leaked|resources still in use"

static func safe_id(value: String) -> bool:
	return RegEx.create_from_string("^[A-Za-z_][A-Za-z0-9_]{0,79}$").search(value) != null

static func parse_arguments(args: PackedStringArray, chapter: int) -> Dictionary:
	var result := {"valid": true, "enabled": false, "args": args.duplicate(), "parent_report": ""}
	if args.is_empty() or not args[-1].begins_with("chain="):
		return result
	result.enabled = true
	var parent := args[-1].trim_prefix("chain=")
	result.args.remove_at(result.args.size() - 1)
	if chapter < 1 or chapter > 6 or result.args.is_empty() or not safe_id(result.args[0]):
		result.valid = false
		return result
	for value in result.args:
		if value.begins_with("chain="): result.valid = false
	if chapter == 1:
		result.valid = result.valid and parent == "FRESH"
	else:
		result.valid = result.valid and safe_id(parent) and parent != "FRESH" and parent != result.args[0]
		if result.valid: result.parent_report = EVIDENCE_ROOT + parent + "/report.json"
	return result

static func is_sha(value: Variant) -> bool:
	return value is String and RegEx.create_from_string("^[a-f0-9]{64}$").search(value) != null

static func count_at_least(value: Variant, minimum: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == floorf(float(value)) and float(value) >= minimum

static func flag(data: Dictionary, key: String, expected: bool) -> bool:
	return data.get(key) is bool and data[key] == expected

static func normalized_state(value: Variant, count: int) -> Dictionary:
	if not value is Dictionary: return {}
	var progress := Progress.new()
	if not progress.restore_state(value) or progress.to_state().cleared_chapters.size() != count:
		return {}
	return progress.to_state()

static func valid_parent(report: Dictionary, chapter: int, source_bank: Dictionary, saved_state: Dictionary, saved_sha: String, current_process: int) -> bool:
	if chapter < 2 or chapter > 6 or current_process <= 0 or source_bank.is_empty() or not is_sha(saved_sha): return false
	if not flag(report, "valid", true) or not count_at_least(report.get("chapter"), 1) or report.chapter != chapter - 1: return false
	if not count_at_least(report.get("moves"), 501) or not count_at_least(report.get("shots"), 51): return false
	if not report.get("prerequisite_fixture") is Array or not report.prerequisite_fixture.is_empty(): return false
	if not report.get("samples") is Array or report.samples.is_empty() or not report.samples[-1] is Dictionary: return false
	if not report.get("chain") is Dictionary: return false
	var chain: Dictionary = report.chain
	if not count_at_least(chain.get("schema"), 1) or chain.schema != 1 or not flag(chain, "enabled", true) or not flag(chain, "used_preseed", false): return false
	if not flag(chain, "returned_to_main", true) or not count_at_least(chain.get("defeated_boss_instance"), 1): return false
	if not count_at_least(chain.get("process_id"), 1) or chain.process_id == current_process: return false
	if not count_at_least(chain.get("expected_kills"), 1) or report.samples[-1].get("state") != "CLEARED": return false
	if not count_at_least(report.samples[-1].get("kills"), int(chain.expected_kills)): return false
	if chain.get("source_bank") != source_bank or chain.get("saved_sha256") != saved_sha: return false
	for source in source_bank:
		if not source is String or not is_sha(source_bank[source]): return false
	var actual := normalized_state(saved_state, chapter - 1)
	if actual.is_empty() or normalized_state(chain.get("saved_state"), chapter - 1) != actual: return false
	if normalized_state(chain.get("before_state"), chapter - 2).is_empty(): return false
	return chain.get("parent_report_sha256") == "" if chapter == 2 else is_sha(chain.get("parent_report_sha256"))

static func evidence_path(path: String, filename: String) -> bool:
	if not path.begins_with(EVIDENCE_ROOT) or path.get_file() != filename: return false
	var identifier := path.get_base_dir().trim_prefix(EVIDENCE_ROOT)
	return safe_id(identifier) and path == EVIDENCE_ROOT + identifier + "/" + filename

static func read_dictionary(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() > 4 * 1024 * 1024: return {}
	var parser := JSON.new()
	var text := file.get_as_text()
	file.close()
	if parser.parse(text) != OK or not parser.data is Dictionary: return {}
	return parser.data

static func source_bank_matches(bank: Dictionary) -> bool:
	if bank.is_empty(): return false
	for path in bank:
		if not path is String or path.contains("..") or path.contains(":") or path.begins_with("/") or not is_sha(bank[path]): return false
		var code: bool = (path.begins_with("scripts/") or path.begins_with("scenes/") or path.begins_with("assets/art/actors/native/") or path.begins_with("assets/art/shaders/")) and path.get_extension() in ["gd", "gdshader", "tscn", "tres", "uid"]
		if not code and path not in ["project.godot", "export_presets.cfg", "assets/audio/overdrive_bone_breaking.mp3", "scripts/tests/run_campaign_chain.ps1", "scripts/tests/run_tests.ps1", "scripts/tests/check_campaign_chain_report.py"]: return false
		if not FileAccess.file_exists("res://" + path) or FileAccess.get_sha256("res://" + path) != bank[path]: return false
	return true

static func build_source_bank() -> Dictionary:
	# Fixed project roots only: never traverse user://, .godot, build or secrets.
	var bank := {}
	for folder in ["scripts", "scenes", "assets/art/actors/native", "assets/art/shaders"]:
		if not collect_sources(folder, bank): return {}
	for path in ["project.godot", "export_presets.cfg", "assets/audio/overdrive_bone_breaking.mp3", "scripts/tests/run_tests.ps1", "scripts/tests/run_campaign_chain.ps1", "scripts/tests/check_campaign_chain_report.py"]:
		if FileAccess.file_exists("res://" + path): bank[path] = FileAccess.get_sha256("res://" + path)
	return bank if source_bank_matches(bank) else {}

static func collect_sources(folder: String, bank: Dictionary) -> bool:
	var directory := DirAccess.open("res://" + folder)
	if directory == null: return false
	for name in directory.get_files():
		if name.get_extension() in ["gd", "gdshader", "tscn", "tres", "uid"]:
			var path := folder + "/" + name
			bank[path] = FileAccess.get_sha256("res://" + path)
	for name in directory.get_directories():
		if name.begins_with("."): continue
		if not collect_sources(folder + "/" + name, bank): return false
	return true

static func prepare_campaign(destination: String, parent_report: String, chapter: int, bank: Dictionary) -> Dictionary:
	var rejected := {"valid": false}
	if chapter < 1 or chapter > 6 or not evidence_path(destination, "campaign.json") or not DirAccess.dir_exists_absolute(destination.get_base_dir()): return rejected
	for suffix in ["", ".tmp", ".bak"]:
		if FileAccess.file_exists(destination + suffix) or DirAccess.dir_exists_absolute(destination + suffix): return rejected
	if not source_bank_matches(bank): return rejected
	if chapter == 1:
		if not parent_report.is_empty(): return rejected
		return {"valid": true, "before_state": Progress.new().to_state(), "parent_report_sha256": "", "parent_saved_sha256": "", "previous_process_id": 0}
	if not evidence_path(parent_report, "report.json") or parent_report.get_base_dir() == destination.get_base_dir(): return rejected
	var parent_folder := parent_report.get_base_dir() + "/"
	var parent_save := parent_folder + "campaign.json"
	var log := parent_folder + "driver.log"
	if FileAccess.file_exists(parent_save + ".tmp") or DirAccess.dir_exists_absolute(parent_save + ".tmp") or DirAccess.dir_exists_absolute(parent_save + ".bak"): return rejected
	if not FileAccess.file_exists(parent_report) or not FileAccess.file_exists(parent_save) or not FileAccess.file_exists(log) or not FileAccess.file_exists(parent_folder + "exit-report.json"): return rejected
	var report := read_dictionary(parent_report)
	var receipt := read_dictionary(parent_folder + "exit-report.json")
	var save_sha := FileAccess.get_sha256(parent_save)
	var report_sha := FileAccess.get_sha256(parent_report)
	var progress := Progress.new()
	if Store.new(parent_save).load_progress(progress) != Store.LoadResult.LOADED: return rejected
	if not valid_parent(report, chapter, bank, progress.to_state(), save_sha, OS.get_process_id()): return rejected
	if chapter == 2:
		if FileAccess.file_exists(parent_save + ".bak"): return rejected
	else:
		var prior := Progress.new()
		if Store.new(parent_save + ".bak").load_progress(prior) != Store.LoadResult.LOADED: return rejected
		if prior.to_state() != normalized_state(report.chain.before_state, chapter - 2) or FileAccess.get_sha256(parent_save + ".bak") != report.chain.get("parent_saved_sha256"): return rejected
	if not count_at_least(receipt.get("schema"), 1) or receipt.schema != 1 or not count_at_least(receipt.get("actual_exit"), 0) or receipt.actual_exit != 0: return rejected
	if receipt.get("report_sha256") != report_sha or receipt.get("log_sha256") != FileAccess.get_sha256(log): return rejected
	var log_file := FileAccess.open(log, FileAccess.READ)
	if log_file == null or log_file.get_length() > 4 * 1024 * 1024: return rejected
	var text := log_file.get_as_text()
	log_file.close()
	if RegEx.create_from_string(FORBIDDEN).search(text) != null: return rejected
	var matches := RegEx.create_from_string("(?m)^TEST PASS: " + MARKERS[chapter - 2] + " ([1-9][0-9]*)\\r?$").search_all(text)
	if matches.size() != 1 or int(matches[0].get_string(1)) != report.get("assertions"): return rejected
	if DirAccess.copy_absolute(ProjectSettings.globalize_path(parent_save), ProjectSettings.globalize_path(destination)) != OK: return rejected
	if FileAccess.get_sha256(destination) != save_sha or FileAccess.get_sha256(parent_save) != save_sha or FileAccess.get_sha256(parent_report) != report_sha: return rejected
	return {"valid": true, "before_state": progress.to_state(), "parent_report_sha256": report_sha, "parent_saved_sha256": save_sha, "previous_process_id": int(report.chain.process_id)}
