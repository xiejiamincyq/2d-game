extends SceneTree

const Main = preload("res://scripts/Main.gd")
const Support = preload("res://scripts/tests/TestSupport.gd")
var assertions := 0
var failures := 0

func check(ok: bool, message: String) -> void:
	assertions += 1
	if not ok:
		failures += 1
		push_error("TEST FAIL: CampaignChapterLaunchTest " + message)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var path := "user://chapter_launch_%d.json" % OS.get_process_id()
	var main := Main.new()
	main.audio_enabled = false
	main.campaign_store_path = path
	root.add_child(main)
	current_scene = main
	check(main.has_method("_can_start_campaign_chapter"), "Main has no actual chapter launch coordinator")
	if failures > 0:
		Support.stop_audio(main.audio)
		main.free()
		quit(1)
		return
	check(main._can_start_campaign_chapter(1), "ready first chapter blocked")
	check(not main._can_start_campaign_chapter(2) and not main._can_start_campaign_chapter(0), "locked/unbuilt/invalid chapter accepted")
	main.ui.start_screen.regions_button.pressed.emit()
	check(not main.ui.start_screen.launch_button.disabled, "menu cannot launch ready first chapter")
	main.ui.start_screen.launch_button.pressed.emit()
	await process_frame
	await process_frame
	var chapter = current_scene
	check(chapter != main and chapter.get_script().resource_path.ends_with("NurseryChapter.gd"), "menu still routes chapter to old six waves")
	check(chapter.campaign_store_path == path and chapter.director.get_encounter().id == &"root_outskirts", "launch lost save path or actual encounter")
	check(not FileAccess.file_exists(path), "merely starting chapter wrote permanent progress")
	for frame in 360:
		if not chapter.player.is_entrance_active():
			break
		await process_frame
	chapter.ui.proceed_button.pressed.emit()
	chapter.director.set_process(false)
	for step in 20:
		chapter.director._process(0.25)
		if not chapter.director.get_active_enemies().is_empty():
			break
	check(not chapter.director.get_active_enemies().is_empty(), "combat Back fixture contains no real living actors")
	chapter._toggle_pause()
	chapter.audio.set_bgm_volume(0.37)
	chapter.audio.set_bgm_muted(true)
	chapter.ui.return_button.pressed.emit()
	await process_frame
	await process_frame
	var returned = current_scene
	check(returned.get_script() == Main and returned.ui.start_screen.visible and not returned.run_started, "Back did not return to real tent menu")
	check(returned.campaign_store_path == path and is_equal_approx(returned.audio.bgm_volume_linear, 0.37) and returned.audio.bgm_muted, "Back lost progress path/audio preferences")
	check(not FileAccess.file_exists(path), "aborting chapter saved a false unlock")
	returned.ui.start_screen.start_button.pressed.emit()
	check(not returned._can_start_campaign_chapter(1), "active old demo admits parallel chapter")
	paused = false
	Support.stop_audio(returned.audio)
	returned.free()
	await process_frame
	if failures == 0:
		print("TEST PASS: CampaignChapterLaunchTest %d" % assertions)
	quit(1 if failures > 0 else 0)
