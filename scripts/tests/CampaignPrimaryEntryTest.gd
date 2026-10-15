extends SceneTree
## Controlled real-scene routing, not ordinary-input chapter victories.
const Main = preload("res://scripts/Main.gd")
const Progress = preload("res://scripts/systems/CampaignProgress.gd")
const Store = preload("res://scripts/systems/CampaignProgressStore.gd")
const Snapshot = preload("res://scripts/tests/fixtures/LegacyRunSnapshotStore.gd")
const Support = preload("TestSupport.gd")
var assertions := 0
var failures := 0
var owned_paths: Array[String] = []

func check(ok: bool, message: String) -> void:
	assertions += 1
	if not ok:
		failures += 1
		push_error("TEST FAIL: CampaignPrimaryEntryTest " + message)

func _initialize() -> void: call_deferred("_run")

func dispose(scene: Node) -> void:
	paused = false
	Support.stop_audio(scene.audio)
	scene.free()
	await process_frame

func key(ui: Node, code: Key, echo := false) -> void:
	var event := InputEventKey.new()
	event.pressed = true
	event.echo = echo
	event.keycode = code
	ui._unhandled_input(event)

func _run() -> void:
	var probe := Main.new()
	check(probe.has_method("_start_primary_campaign"), "Main default still routes to old waves")
	probe.free()
	if failures: quit(1); return
	var snapshot_path := "user://primary_snapshot_%d.json" % OS.get_process_id()
	owned_paths.append(snapshot_path)
	var snapshot := Snapshot.new()
	snapshot.save_path = snapshot_path
	check(snapshot.save_snapshot({"version": 1, "boundary": "wave_intro", "pending_stage": 1, "coins": 0,
		"family_levels": {"ballistics": 1, "mobility": 1, "automation": 1}, "upgrade_counts": {}, "evolution": "",
		"settlement": {"wave": 0, "generation": 0, "offers": [], "reward_claimed": false, "closed": true},
		"player": {"position": [0, 0], "health": 100.0, "max_health": 100.0, "shield": 0.0, "max_shield": 20.0},
		"kills": 0, "elapsed_seconds": 0.0}), "valid legacy snapshot fixture rejected")
	snapshot.free()
	var snapshot_sha := FileAccess.get_sha256(snapshot_path)
	for clears in range(0, 7):
		var path := "user://primary_campaign_%d_%d.json" % [OS.get_process_id(), clears]
		owned_paths.append(path)
		var progress := Progress.new()
		for number in range(1, clears + 1): progress.record_boss_defeat(number)
		if clears: check(Store.new(path).save_progress(progress), "isolated sequential progress fixture")
		var before := FileAccess.get_sha256(path) if clears else ""
		var main := Main.new()
		main.audio_enabled = false
		main.campaign_store_path = path
		root.add_child(main)
		current_scene = main
		check(not main.ui.start_screen.start_button.disabled, "actual frontier primary unavailable")
		key(main.ui, KEY_C)
		key(main.ui, KEY_ENTER, true)
		check(not main.restarting, "cover C or echo starts legacy/formal run")
		key(main.ui, KEY_SPACE if clears % 2 == 0 else KEY_ENTER)
		main._start_primary_campaign() # a duplicate signal cannot spawn another scene
		await process_frame
		await process_frame
		var chapter = current_scene
		check(chapter != main and chapter.has_method("_chapter_number"), "primary never reached actual chapter")
		if chapter == main:
			await dispose(main)
			break
		check(chapter._chapter_number() == clears % 6 + 1 and chapter.run_loop == clears / 6 + 1 and chapter.campaign_store_path == path, "primary skipped frontier, next loop or save boundary")
		var live_chapters := 0
		for child in root.get_children():
			if child.has_method("_chapter_number"): live_chapters += 1
		check(live_chapters == 1, "duplicate launch creates multiple chapters")
		if clears == 0:
			chapter.ui.return_button.pressed.emit()
			await process_frame
			await process_frame
			var returned = current_scene
			check(returned.get_script() == Main and not returned.restarting and returned.ui.start_screen.start_button.text.contains("第1关"), "Back lost formal primary")
			await dispose(returned)
		else: await dispose(chapter)
		check(FileAccess.get_sha256(snapshot_path) == snapshot_sha, "formal launch/Back deleted or rewrote legacy snapshot")
		check((FileAccess.get_sha256(path) if clears else "") == before and (clears > 0 or not FileAccess.file_exists(path)), "primary selection wrote permanent progress")
	# Hostile UI state cannot bypass Main's live storage guard.
	var bad_path := "user://primary_bad_%d.json" % OS.get_process_id()
	owned_paths.append(bad_path)
	var bad_file := FileAccess.open(bad_path, FileAccess.WRITE)
	bad_file.store_string("invalid campaign; preserve me")
	bad_file.close()
	var bad_sha := FileAccess.get_sha256(bad_path)
	var bad := Main.new()
	bad.audio_enabled = false
	bad.campaign_store_path = bad_path
	root.add_child(bad)
	current_scene = bad
	bad.ui.start_screen.start_button.disabled = false
	bad.ui.start_requested.emit()
	check(not bad.restarting and not bad.has_method("_start_run") and bad.ui.start_screen.start_button.text.contains("异常"), "live storage failure silently enters demo")
	check(FileAccess.get_sha256(bad_path) == bad_sha and not FileAccess.file_exists(bad_path + ".tmp"), "bad campaign silently repaired")
	await dispose(bad)
	# C is ignored on cover/settings even when an old snapshot exists.
	var tent:=Main.new(); tent.audio_enabled=false; tent.campaign_store_path=owned_paths[1]
	root.add_child(tent); current_scene=tent
	tent.ui.start_screen.settings_button.pressed.emit()
	key(tent.ui,KEY_SPACE); key(tent.ui,KEY_C)
	check(not tent.restarting,"settings shortcuts hijack focused controls")
	tent.ui.start_screen.back_button.pressed.emit(); key(tent.ui,KEY_C)
	check(not tent.restarting and not tent.has_method("_continue_run"),"retired C resumes legacy gameplay")
	check(FileAccess.get_sha256(snapshot_path)==snapshot_sha,"ignored legacy snapshot was modified")
	await dispose(tent)
	for path in owned_paths:
		check(Support.cleanup_journey_fixture(path),"owned journey cleanup")
		for suffix in ["", ".tmp", ".bak"]:
			if FileAccess.file_exists(path + suffix): DirAccess.remove_absolute(path + suffix)
	if not failures: print("TEST PASS: CampaignPrimaryEntryTest %d" % assertions)
	quit(1 if failures else 0)
