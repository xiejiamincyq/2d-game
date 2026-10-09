extends SceneTree

# Separate writer/reader processes exercise only the permanent store, not Main.
const Progress = preload("res://scripts/systems/CampaignProgress.gd")
const Store = preload("res://scripts/systems/CampaignProgressStore.gd")

func _initialize() -> void:
	var path := OS.get_environment("CAMPAIGN_STORE_PROBE_PATH")
	var args := OS.get_cmdline_user_args()
	if not path.is_absolute_path() or args.size() != 1 or args[0] not in ["write", "read"]:
		push_error("TEST FAIL: CampaignStoreProcessProbe explicit isolated path/mode required")
		quit(1)
		return
	var progress := Progress.new()
	var store := Store.new(path)
	var valid := false
	if args[0] == "write":
		if FileAccess.file_exists(path) or FileAccess.file_exists(path + ".bak"):
			push_error("TEST FAIL: CampaignStoreProcessProbe fresh writer path required")
			quit(1)
			return
		progress.record_boss_defeat(1)
		valid = store.save_progress(progress)
		progress.record_boss_defeat(2)
		valid = store.save_progress(progress) and valid
	else:
		valid = store.load_progress(progress) == Store.LoadResult.LOADED and progress.has_cleared(1) and progress.has_cleared(2) and progress.is_unlocked(3) and not progress.is_unlocked(4)
	print("CAMPAIGN_STORE_PROCESS mode=%s valid=%s state=%s" % [args[0], valid, JSON.stringify(progress.to_state())])
	quit(0 if valid else 1)
