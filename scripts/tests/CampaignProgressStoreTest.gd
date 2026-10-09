extends SceneTree

const Progress = preload("res://scripts/systems/CampaignProgress.gd")
const LegacyStore = preload("res://scripts/systems/RunSnapshotStore.gd")
var assertions := 0
var failures := 0
var test_root := ""
var owned_files: Array[String] = []
var owned_directories: Array[String] = []

func check(ok: bool, message: String) -> void:
	assertions += 1
	if not ok:
		failures += 1
		push_error("TEST FAIL: CampaignProgressStoreTest " + message)

func fixture_path(name: String) -> String:
	var path := test_root.path_join(name)
	for suffix in ["", ".tmp", ".bak"]:
		if path + suffix not in owned_files:
			owned_files.append(path + suffix)
	return path

func write_text(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	check(file != null, "cannot create isolated fixture")
	if file != null:
		file.store_string(text)
		file.close()

func read_text(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	return file.get_as_text()

func make_directory(path: String) -> void:
	check(DirAccess.make_dir_absolute(path) == OK, "cannot create isolated blocker directory")
	owned_directories.append(path)

func _initialize() -> void:
	var source := "res://scripts/systems/CampaignProgressStore.gd"
	check(FileAccess.file_exists(source), "permanent progress disk store is not implemented")
	if failures > 0:
		quit(1)
		return
	var Store = load(source)
	test_root = "user://campaign-store-test-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	check(not DirAccess.dir_exists_absolute(test_root), "test isolation directory already exists")
	check(DirAccess.make_dir_absolute(test_root) == OK, "cannot create test isolation directory")
	check(Store.DEFAULT_PATH != LegacyStore.DEFAULT_PATH, "campaign store reuses old wave save path")
	var path := fixture_path("progress.json")
	var store = Store.new(path)
	var progress := Progress.new()
	check(store.load_progress(progress) == Store.LoadResult.MISSING, "new profile was not reported missing")
	check(progress.get_highest_unlocked_chapter() == 1, "missing save opens extra chapters")
	check(not store.save_progress(null), "null progress saved")
	progress.record_boss_defeat(1)
	check(store.save_progress(progress), "first permanent progress save failed")
	progress.record_boss_defeat(2)
	check(store.save_progress(progress), "second permanent progress save failed")
	var committed := read_text(path)
	var backup := read_text(path + ".bak")
	check(not backup.is_empty(), "previous committed progress backup was discarded")
	var restored := Progress.new()
	check(Store.new(path).load_progress(restored) == Store.LoadResult.LOADED, "new store instance failed to load")
	check(restored.to_state() == progress.to_state(), "disk roundtrip changed unlocked chapters")
	check(store.save_progress(restored), "idempotent save failed")
	check(read_text(path) == committed and read_text(path + ".bak") == backup, "no-op save rewrote journal")
	var stale := Progress.new()
	stale.record_boss_defeat(1)
	check(not store.save_progress(stale), "stale writer rolled permanent unlocks backwards")
	check(read_text(path) == committed, "rejected stale write changed committed progress")
	var invalid := Progress.new()
	invalid._cleared_chapters.append(5)
	check(not store.save_progress(invalid), "invalid in-memory progression reached disk")
	check(read_text(path) == committed, "invalid save corrupted committed data")

	write_text(path, "{unfinished")
	check(store.load_progress(restored) == Store.LoadResult.RECOVERED, "valid previous backup was not recoverable")
	check(restored.has_cleared(1) and not restored.has_cleared(2), "recovery did not use committed backup")
	check(read_text(path) == "{unfinished" and read_text(path + ".bak") == backup, "read-only recovery silently rewrote files")
	check(not store.save_progress(progress), "corrupt primary was silently overwritten")
	write_text(path, committed)
	DirAccess.remove_absolute(path)
	check(store.load_progress(restored) == Store.LoadResult.RECOVERED, "interruption after primary rename lost backup")
	check(store.save_progress(progress), "recovered missing-primary progress could not commit")
	check(read_text(path + ".bak") == backup, "missing-primary save discarded committed backup")

	var future := fixture_path("future.json")
	var future_text := JSON.stringify({"version": 2, "cleared_chapters": [1, 2, 3]})
	write_text(future, future_text)
	write_text(future + ".bak", committed)
	var before := restored.to_state()
	check(Store.new(future).load_progress(restored) == Store.LoadResult.UNSUPPORTED_VERSION, "future version fell back to stale backup")
	check(restored.to_state() == before, "unsupported schema changed live progress")
	check(not Store.new(future).save_progress(progress), "future version silently downgraded")
	check(read_text(future) == future_text, "unsupported version file was overwritten")

	for text in ["{bad", "[]", "null", JSON.stringify({"version": 1, "pending_stage": 6}), "x".repeat(4097)]:
		var bad := fixture_path("bad.json")
		write_text(bad, text)
		check(Store.new(bad).load_progress(restored) == Store.LoadResult.CORRUPT, "invalid/legacy save accepted")
		check(restored.to_state() == before, "invalid load destroyed live progress")
		check(not Store.new(bad).save_progress(progress) and read_text(bad) == text, "bad save was silently replaced")

	var orphan := fixture_path("orphan.json")
	write_text(orphan + ".tmp", committed)
	check(Store.new(orphan).load_progress(restored) == Store.LoadResult.MISSING, "uncommitted temporary file was promoted")
	check(FileAccess.file_exists(orphan + ".tmp"), "load removed pending write without consent")
	var directory := fixture_path("directory.json")
	make_directory(directory)
	check(Store.new(directory).load_progress(restored) == Store.LoadResult.IO_ERROR, "directory save target was reported missing")
	check(not Store.new(directory).save_progress(progress), "directory target accepted a save")
	make_directory(path + ".tmp")
	progress.record_boss_defeat(3)
	check(not store.save_progress(progress), "blocked temporary path allowed commit")
	check(read_text(path) == committed, "temporary write failure destroyed primary")
	DirAccess.remove_absolute(path + ".tmp")
	owned_directories.erase(path + ".tmp")
	var blocked_backup := fixture_path("blocked-backup.json")
	check(Store.new(blocked_backup).save_progress(stale), "backup-blocker fixture setup failed")
	make_directory(blocked_backup + ".bak")
	check(not Store.new(blocked_backup).save_progress(progress), "blocked backup path allowed unsafe replacement")
	check(read_text(blocked_backup) == JSON.stringify(stale.to_state()), "backup failure destroyed primary")

	var FailedCommit = load("res://scripts/tests/fixtures/CampaignFailedCommitStore.gd")
	check(not FailedCommit.new(path).save_progress(progress), "injected commit failure ignored")
	check(read_text(path) == committed, "failed final rename did not restore committed primary")
	check(Store.new(path).load_progress(restored) == Store.LoadResult.LOADED and restored.has_cleared(2) and not restored.has_cleared(3), "rollback exposed uncommitted unlocks")

	# Only exact files/directories created under this unique test root are removed.
	for owned in owned_files:
		if FileAccess.file_exists(owned):
			DirAccess.remove_absolute(owned)
	owned_directories.reverse()
	for owned in owned_directories:
		DirAccess.remove_absolute(owned)
	check(DirAccess.remove_absolute(test_root) == OK, "isolated fixtures leaked")
	if failures == 0:
		print("TEST PASS: CampaignProgressStoreTest %d" % assertions)
	quit(0 if failures == 0 else 1)
