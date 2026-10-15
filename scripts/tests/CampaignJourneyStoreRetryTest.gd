extends SceneTree
const Journey = preload("res://scripts/systems/CampaignJourney.gd")
const Store = preload("res://scripts/systems/CampaignJourneyStore.gd")
class CommitBlocker extends Store:
	var block_commit_once := false
	func _read(path: String) -> Dictionary:
		var result := super._read(path)
		if block_commit_once and path == save_path + ".tmp" and result.status == LoadResult.LOADED:
			block_commit_once = false
			DirAccess.make_dir_absolute(save_path)
		return result
var checks := 0
var failures := 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("TEST FAIL: CampaignJourneyStoreRetryTest " + message)

func _initialize() -> void:
	var directory := "user://journey-retry-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	check(not DirAccess.dir_exists_absolute(directory) and DirAccess.make_dir_absolute(directory) == OK, "isolated directory")
	for mode in ["retry", "tampered"]:
		var path: String = directory.path_join(mode + ".json")
		var store := CommitBlocker.new(path)
		var journey := Journey.new()
		check(store.load_journey(journey) == Store.LoadResult.MISSING, "new journal")
		check(journey.commit_clear(1, 1, 37, {"damage": 1}, "damage"), "valid candidate")
		store.block_commit_once = true
		check(not store.save_journey(journey) and FileAccess.file_exists(path + ".tmp"), "real commit interruption did not retain prepared temp")
		check(DirAccess.dir_exists_absolute(path) and DirAccess.remove_absolute(path) == OK, "remove own empty commit blocker")
		if mode == "retry":
			check(store.save_journey(journey), "same writer cannot retry its own verified prepared transaction")
			var restored := Journey.new()
			check(Store.new(path).load_journey(restored) == Store.LoadResult.LOADED and restored.to_state() == journey.to_state(), "retried commit not readable")
		else:
			var file := FileAccess.open(path + ".tmp", FileAccess.WRITE)
			file.store_string("external replacement")
			file.close()
			check(not store.save_journey(journey), "changed prepared bytes accepted as writer-owned")
			check(FileAccess.open(path + ".tmp", FileAccess.READ).get_as_text() == "external replacement", "changed unowned temporary overwritten")
		for suffix in ["", ".bak", ".tmp"]:
			var owned: String = path + suffix
			if FileAccess.file_exists(owned):
				check(DirAccess.remove_absolute(owned) == OK, "owned fixture cleanup")
	check(DirAccess.remove_absolute(directory) == OK, "owned directory cleanup")
	if failures == 0:
		print("TEST PASS: CampaignJourneyStoreRetryTest %d" % checks)
	quit(0 if failures == 0 else 1)
