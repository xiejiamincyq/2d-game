extends SceneTree

const Journey = preload("res://scripts/systems/CampaignJourney.gd")
var assertions := 0
var failures := 0
var test_root := ""

func check(ok: bool, message: String) -> void:
	assertions += 1
	if not ok:
		failures += 1
		push_error("TEST FAIL: CampaignJourneyStoreTest " + message)

func read_text(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	return file.get_as_text() if file != null else ""

func write_text(path: String, content: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	check(file != null, "isolated fixture writable")
	if file != null:
		file.store_string(content)
		file.close()

func _initialize() -> void:
	var source := "res://scripts/systems/CampaignJourneyStore.gd"
	check(ResourceLoader.exists(source, "GDScript"), "journey disk journal missing")
	if failures:
		quit(1)
		return
	var Store = load(source)
	test_root = "user://journey-store-test-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	check(not DirAccess.dir_exists_absolute(test_root), "isolated root already exists")
	check(DirAccess.make_dir_absolute(test_root) == OK, "isolated root creation")
	var path := test_root.path_join("journey.json")
	var journey := Journey.new()
	var store = Store.new(path)
	check(Store.DEFAULT_PATH != "user://five_minute_overdrive_campaign_v1.json", "old permanent save overwritten")
	check(not store.save_journey(journey), "save without load/CAS baseline accepted")
	check(store.load_journey(journey) == Store.LoadResult.MISSING, "fresh save missing status")
	check(journey.commit_clear(1, 1, 91, {"damage": 1}, "damage"), "first chapter fixture")
	check(store.save_journey(journey), "first disk clear commit")
	var previous := read_text(path)
	var restored := Journey.new()
	var newer = Store.new(path)
	check(newer.load_journey(restored) == Store.LoadResult.LOADED, "fresh store instance restore")
	check(restored.to_state() == journey.to_state(), "disk restores coins/cards/frontier exactly")
	check(restored.checkpoint_coins(12) and newer.save_journey(restored), "spent coins cannot decrease persisted balance")
	var committed := read_text(path)
	var backup := read_text(path + ".bak")
	check(backup == previous, "previous committed checkpoint not retained")
	check(newer.save_journey(restored), "idempotent write failed")
	check(read_text(path) == committed and read_text(path + ".bak") == backup, "no-op save rewrites journal")
	journey.checkpoint_coins(93)
	check(not store.save_journey(journey), "stale store overwrote newer balance")
	check(read_text(path) == committed, "stale write changed primary")
	var loaded_before := restored.to_state()
	write_text(path, "{broken")
	check(newer.load_journey(restored) == Store.LoadResult.RECOVERED, "backup recovery not reported")
	check(restored.get_build().coins == 91, "backup coins not restored")
	check(read_text(path) == "{broken" and read_text(path + ".bak") == backup, "load changed corrupt/backup files")
	check(not newer.save_journey(restored), "corrupt primary silently overwritten")
	write_text(path, '{"version":2}')
	var recovery_state := restored.to_state()
	check(newer.load_journey(restored) == Store.LoadResult.UNSUPPORTED_VERSION, "future version downgraded through backup")
	check(restored.to_state() == recovery_state, "future-version rejection changed memory")
	check(not newer.save_journey(restored), "future save overwritten")
	write_text(path, committed)
	check(newer.load_journey(restored) == Store.LoadResult.LOADED and restored.to_state() == loaded_before, "restored committed checkpoint differs")
	var impossible := '{"version":1,"cleared_stage":0,"coins":0,"inherited_counts":{"damage":1}}'
	write_text(path, impossible)
	check(newer.load_journey(restored) == Store.LoadResult.RECOVERED, "impossible extra rewards treated as a valid save")
	check(read_text(path) == impossible and read_text(path + ".bak") == backup, "semantic corruption recovery changed journal")
	check(not newer.save_journey(restored), "semantic corrupt primary silently overwritten")
	write_text(path, committed)
	check(newer.load_journey(restored) == Store.LoadResult.LOADED, "return to valid primary after semantic recovery")
	write_text(path + ".tmp", "unowned pending bytes")
	check(restored.checkpoint_coins(8) and not newer.save_journey(restored), "unowned temporary file overwritten")
	check(read_text(path + ".tmp") == "unowned pending bytes" and read_text(path) == committed, "temp conflict changes user data")
	# Delete only files created in this unique test directory, never player saves.
	for suffix in ["", ".bak", ".tmp"]:
		var owned: String = path + suffix
		if FileAccess.file_exists(owned):
			check(DirAccess.remove_absolute(owned) == OK, "owned fixture cleanup")
	check(DirAccess.remove_absolute(test_root) == OK, "owned root cleanup")
	if failures == 0:
		print("TEST PASS: CampaignJourneyStoreTest %d" % assertions)
	quit(0 if failures == 0 else 1)
