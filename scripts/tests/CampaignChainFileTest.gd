extends SceneTree
## Real bounded file operations on synthetic metadata, NOT actual gameplay.
var Evidence: Variant = load("res://scripts/art/CampaignChainEvidence.gd")
const Progress = preload("res://scripts/systems/CampaignProgress.gd")
const Store = preload("res://scripts/systems/CampaignProgressStore.gd")
var assertions := 0
var failures := 0
var folders: Array[String] = []
var files: Array[String] = []

func check(ok: bool, label: String) -> void:
	assertions += 1
	if not ok: failures += 1; push_error("TEST FAIL: CampaignChainFileTest " + label)

func write(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	check(file != null, "owned fixture file could not open")
	if file != null: file.store_string(text); file.close()
	if path not in files: files.append(path)

func fresh(name: String) -> String:
	var path: String = Evidence.EVIDENCE_ROOT + "chain_file_test_%d_%s/" % [OS.get_process_id(), name]
	check(not DirAccess.dir_exists_absolute(path), "refuse old unit fixture")
	check(DirAccess.make_dir_recursive_absolute(path) == OK, "new unit folder")
	folders.append(path)
	return path

func _initialize() -> void:
	check(Evidence.get_script_method_list().any(func(item: Dictionary) -> bool: return item.name == "prepare_campaign"), "bounded byte-copy/save provenance boundary missing")
	if failures: quit(1); return
	var parent := fresh("parent")
	var first := fresh("first")
	var target := fresh("target")
	var bank := {"scripts/Main.gd": FileAccess.get_sha256("res://scripts/Main.gd")}
	check(not Evidence.source_bank_matches({".env": "a".repeat(64)}), "bank reads unrelated sensitive file")
	var initial: Dictionary = Evidence.prepare_campaign(first + "campaign.json", "", 1, bank)
	check(initial.valid and initial.before_state.cleared_chapters.is_empty() and not FileAccess.file_exists(first + "campaign.json"), "first stage created synthetic progress")
	check(not Evidence.prepare_campaign(first + "campaign.json", "", 2, bank).valid, "later chapter used empty predecessor")
	check(not Evidence.prepare_campaign(Store.DEFAULT_PATH, "", 1, bank).valid, "boundary writes real campaign path")
	var model := Progress.new()
	check(model.restore_state({"version": 1, "cleared_chapters": [1]}), "unit model fixture")
	check(Store.new(parent + "campaign.json").save_progress(model), "owned synthetic parent save")
	files.append(parent + "campaign.json")
	var sha := FileAccess.get_sha256(parent + "campaign.json")
	var report := {"valid": true, "chapter": 1, "assertions": 600, "moves": 600, "shots": 80,
		"prerequisite_fixture": [], "samples": [{"state": "CLEARED", "kills": 30}],
		"chain": {"schema": 1, "enabled": true, "used_preseed": false, "process_id": OS.get_process_id() + 1,
			"returned_to_main": true, "defeated_boss_instance": 777, "expected_kills": 30,
			"saved_sha256": sha, "saved_state": model.to_state(), "before_state": {"version": 1, "cleared_chapters": []},
			"source_bank": bank, "parent_report_sha256": ""}}
	write(parent + "report.json", JSON.stringify(report))
	write(parent + "driver.log", "TEST PASS: VerifyNurseryChapterFlow 600\n")
	check(not Evidence.prepare_campaign(target + "campaign.json", parent + "report.json", 2, bank).valid, "missing actual-exit ledger accepted")
	var receipt := {"schema": 1, "actual_exit": 0, "report_sha256": FileAccess.get_sha256(parent + "report.json"), "log_sha256": FileAccess.get_sha256(parent + "driver.log")}
	write(parent + "exit-report.json", JSON.stringify(receipt))
	var accepted: Dictionary = Evidence.prepare_campaign(target + "campaign.json", parent + "report.json", 2, bank)
	check(accepted.valid and accepted.before_state == model.to_state(), "byte-identical parent file contract rejected")
	check(FileAccess.get_sha256(target + "campaign.json") == sha and FileAccess.get_sha256(parent + "campaign.json") == sha, "copy changes source or save bytes")
	files.append(target + "campaign.json")
	check(not Evidence.prepare_campaign(target + "campaign.json", parent + "report.json", 2, bank).valid, "existing destination overwritten")
	var blocked := fresh("blocked")
	write(blocked + "campaign.json.tmp", "preserve blocked transaction")
	check(not Evidence.prepare_campaign(blocked + "campaign.json", parent + "report.json", 2, bank).valid, "unfinished output transaction overwritten")
	var rejection := fresh("reject")
	check(not Evidence.prepare_campaign(rejection + "campaign.json", parent + "report.json", 3, bank).valid, "chapter skip accepted")
	var drift := bank.duplicate()
	drift["scripts/Main.gd"] = "d".repeat(64)
	check(not Evidence.prepare_campaign(rejection + "campaign.json", parent + "report.json", 2, drift).valid, "current source drift accepted")
	receipt.actual_exit = 1
	write(parent + "exit-report.json", JSON.stringify(receipt))
	check(not Evidence.prepare_campaign(rejection + "campaign.json", parent + "report.json", 2, bank).valid, "failed parent process accepted")
	receipt.actual_exit = 0
	write(parent + "driver.log", "TEST PASS: VerifyNurseryChapterFlow 600\nERROR: fixture error\n")
	receipt.log_sha256 = FileAccess.get_sha256(parent + "driver.log")
	write(parent + "exit-report.json", JSON.stringify(receipt))
	check(not Evidence.prepare_campaign(rejection + "campaign.json", parent + "report.json", 2, bank).valid, "error log accepted despite a PASS")
	check(not FileAccess.file_exists(rejection + "campaign.json"), "rejection creates output save")
	write(parent + "driver.log", "TEST PASS: VerifyNurseryChapterFlow 600\nTEST PASS: VerifyNurseryChapterFlow 600\n")
	receipt.log_sha256 = FileAccess.get_sha256(parent + "driver.log")
	write(parent + "exit-report.json", JSON.stringify(receipt))
	check(not Evidence.prepare_campaign(rejection + "campaign.json", parent + "report.json", 2, bank).valid, "duplicate pass markers accepted")
	# A real later win retains the prior committed save as .bak. That is not an
	# unfinished transaction: require its exact inherited SHA and prior state.
	var before := model.to_state()
	check(model.restore_state({"version": 1, "cleared_chapters": [1, 2]}) and Store.new(parent + "campaign.json").save_progress(model), "later synthetic Store commit")
	files.append(parent + "campaign.json.bak")
	report.chapter = 2
	report.chain.before_state = before
	report.chain.saved_state = model.to_state()
	report.chain.saved_sha256 = FileAccess.get_sha256(parent + "campaign.json")
	report.chain.parent_report_sha256 = "a".repeat(64)
	report.chain.parent_saved_sha256 = sha
	write(parent + "report.json", JSON.stringify(report))
	write(parent + "driver.log", "TEST PASS: VerifyFoundryChapterFlow 600\n")
	receipt.report_sha256 = FileAccess.get_sha256(parent + "report.json")
	receipt.log_sha256 = FileAccess.get_sha256(parent + "driver.log")
	write(parent + "exit-report.json", JSON.stringify(receipt))
	var next := fresh("next")
	var backup_model := Progress.new()
	check(Store.new(parent + "campaign.json.bak").load_progress(backup_model) == Store.LoadResult.LOADED and backup_model.to_state() == before, "retained backup differs from pre-win state")
	check(FileAccess.get_sha256(parent + "campaign.json.bak") == sha, "retained backup differs from inherited exact bytes")
	check(Evidence.valid_parent(report, 3, bank, model.to_state(), FileAccess.get_sha256(parent + "campaign.json"), OS.get_process_id()), "later metadata contract rejected")
	var disk_report: Dictionary = Evidence.read_dictionary(parent + "report.json")
	check(Evidence.valid_parent(disk_report, 3, bank, model.to_state(), FileAccess.get_sha256(parent + "campaign.json"), OS.get_process_id()), "later parsed metadata contract rejected")
	check(backup_model.to_state() == Evidence.normalized_state(disk_report.chain.before_state, 1), "parsed backup state normalization mismatch")
	check(FileAccess.get_sha256(parent + "campaign.json.bak") == disk_report.chain.parent_saved_sha256, "parsed backup hash mismatch")
	check(Evidence.prepare_campaign(next + "campaign.json", parent + "report.json", 3, bank).valid, "legitimate committed backup blocks consecutive chapter")
	if FileAccess.file_exists(next + "campaign.json"): files.append(next + "campaign.json")
	write(parent + "campaign.json.bak", "unexpected backup")
	check(not Evidence.prepare_campaign(rejection + "campaign.json", parent + "report.json", 3, bank).valid, "unrelated recovery backup accepted")
	# Remove only the exact synthetic files/folders created by this PID here.
	for path in files:
		if FileAccess.file_exists(path): check(DirAccess.remove_absolute(path) == OK, "owned fixture file cleanup")
	folders.reverse()
	for path in folders: check(DirAccess.remove_absolute(path) == OK, "owned empty fixture directory cleanup")
	if not failures: print("TEST PASS: CampaignChainFileTest %d" % assertions)
	quit(1 if failures else 0)
