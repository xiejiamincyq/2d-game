extends SceneTree
## Controlled real-scene routing, not ordinary-input chapter victories.
const Main = preload("res://scripts/Main.gd")
const Progress = preload("res://scripts/systems/CampaignProgress.gd")
const Store = preload("res://scripts/systems/CampaignProgressStore.gd")
const Snapshot = preload("res://scripts/systems/RunSnapshotStore.gd")
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
		main.snapshot_store.save_path = snapshot_path
		main.ui.set_continue_available(main.snapshot_store.has_valid_snapshot())
		check(not main.ui.start_screen.start_button.disabled, "actual frontier primary unavailable")
		key(main.ui, KEY_C)
		key(main.ui, KEY_ENTER, true)
		check(not main.run_started and not main.restarting, "cover C or echo starts legacy/formal run")
		if clears == 6:
			key(main.ui, KEY_ENTER)
			check(current_scene == main and main.ui.start_screen.page == main.ui.start_screen.Page.CHAPTERS and main.ui.start_screen.selected_chapter == 6, "all-clear primary invents seventh or launches legacy")
			main._start_primary_campaign()
			check(not main.run_started and not main.restarting, "live all-clear model bypasses replay choice")
			await dispose(main)
		else:
			key(main.ui, KEY_SPACE if clears % 2 == 0 else KEY_ENTER)
			main._start_primary_campaign() # a duplicate signal cannot spawn another scene
			await process_frame
			await process_frame
			var chapter = current_scene
			check(chapter != main and chapter.has_method("_chapter_number"), "primary never reached actual chapter")
			if chapter == main:
				await dispose(main)
				break
			check(chapter._chapter_number() == clears + 1 and chapter.campaign_store_path == path, "primary skipped frontier or save boundary")
			var live_chapters := 0
			for child in root.get_children():
				if child.has_method("_chapter_number"): live_chapters += 1
			check(live_chapters == 1, "duplicate launch creates multiple chapters")
			if clears == 0:
				chapter.ui.return_button.pressed.emit()
				await process_frame
				await process_frame
				var returned = current_scene
				check(returned.get_script() == Main and not returned.run_started and returned.ui.start_screen.start_button.text.contains("第1区"), "Back lost formal primary")
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
	check(not bad.restarting and not bad.run_started and bad.ui.start_screen.start_button.text.contains("异常"), "live storage failure silently enters demo")
	check(FileAccess.get_sha256(bad_path) == bad_sha and not FileAccess.file_exists(bad_path + ".tmp"), "bad campaign silently repaired")
	await dispose(bad)
	# C remains an actual legacy continuation request, only in the explicit page.
	var legacy := Main.new()
	legacy.audio_enabled = false
	legacy.campaign_store_path = owned_paths[1]
	root.add_child(legacy)
	current_scene = legacy
	legacy.snapshot_store.save_path = snapshot_path
	legacy.ui.set_continue_available(legacy.snapshot_store.has_valid_snapshot())
	legacy.ui.start_screen.settings_button.pressed.emit()
	key(legacy.ui, KEY_SPACE)
	key(legacy.ui, KEY_C)
	check(not legacy.run_started and not legacy.restarting, "settings shortcuts hijack focused controls")
	legacy.ui.start_screen.back_button.pressed.emit()
	legacy.ui.start_screen.legacy_button.pressed.emit()
	key(legacy.ui, KEY_C)
	check(legacy.run_started and legacy.player != null and not legacy.ui.start_screen.visible, "explicit C no longer resumes actual legacy snapshot")
	check(legacy.campaign_progress.to_state().cleared_chapters.is_empty(), "legacy continuation advances campaign")
	await dispose(legacy)
	for path in owned_paths:
		for suffix in ["", ".tmp", ".bak"]:
			if FileAccess.file_exists(path + suffix): DirAccess.remove_absolute(path + suffix)
	if not failures: print("TEST PASS: CampaignPrimaryEntryTest %d" % assertions)
	quit(1 if failures else 0)
