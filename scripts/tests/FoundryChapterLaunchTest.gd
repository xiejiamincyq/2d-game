extends SceneTree
const Main = preload("res://scripts/Main.gd")
const Progress = preload("res://scripts/systems/CampaignProgress.gd")
const Store = preload("res://scripts/systems/CampaignProgressStore.gd")
const Support = preload("TestSupport.gd")
var failures := 0
var assertions := 0
func check(ok: bool, message: String) -> void:
	assertions += 1
	if not ok:
		failures += 1
		push_error("TEST FAIL: FoundryChapterLaunchTest " + message)
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	var path := "user://foundry_launch_%d.json" % OS.get_process_id()
	check(not FileAccess.file_exists(path) and not FileAccess.file_exists(path + ".bak"), "owned save must be absent")
	if failures:
		quit(1)
		return
	var progress := Progress.new()
	check(progress.record_boss_defeat(1) and Store.new(path).save_progress(progress), "isolated prerequisite fixture failed")
	var hash_before := FileAccess.get_sha256(path)
	var main := Main.new()
	main.audio_enabled = false
	main.campaign_store_path = path
	root.add_child(main)
	current_scene = main
	check(main._can_start_campaign_chapter(1), "first chapter no longer replayable")
	check(main._can_start_campaign_chapter(2), "verified second scene cannot launch")
	check(not main._can_start_campaign_chapter(3), "locked third scene accepted without second Boss clear")
	main.ui.start_screen.regions_button.pressed.emit()
	main.ui.start_screen.chapter_buttons[1].pressed.emit()
	check(main.ui.start_screen.selected_chapter == 2 and not main.ui.start_screen.launch_button.disabled, "menu blocks unlocked second chapter")
	if failures:
		Support.stop_audio(main.audio)
		main.free()
		DirAccess.remove_absolute(path)
		quit(1)
		return
	main.ui.start_screen.launch_button.pressed.emit()
	await process_frame
	await process_frame
	var chapter = current_scene
	check(chapter != main and chapter.get_script().resource_path.ends_with("FoundryChapter.gd"), "second launch routes to first chapter or old demo")
	check(chapter.campaign_store_path == path and chapter.director.get_encounter().id == &"slag_workshop", "second launch lost save path/actual encounter")
	check(chapter.director.heat_field == chapter.map.heat_field, "second launch bypasses actual map heat")
	check(chapter.map.layout.get_obstacle_descriptors().size()>=16 and chapter.map.layout._layout_is_acceptable(), "actual random second launch returned empty/rejected terrain, seed %s" % chapter.run_seed)
	check(FileAccess.get_sha256(path) == hash_before, "launch rewrote permanent progress")
	chapter.ui.return_button.pressed.emit()
	await process_frame
	await process_frame
	var returned = current_scene
	check(returned.get_script() == Main and returned._can_start_campaign_chapter(2), "Back did not restore actual second-chapter menu")
	check(FileAccess.get_sha256(path) == hash_before, "Back forged progress")
	paused = false
	Support.stop_audio(returned.audio)
	returned.free()
	await process_frame
	check(DirAccess.remove_absolute(path) == OK, "owned save cleanup failed")
	if failures == 0: print("TEST PASS: FoundryChapterLaunchTest %d" % assertions)
	quit(1 if failures else 0)
