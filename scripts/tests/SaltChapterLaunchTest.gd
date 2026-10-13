extends SceneTree
const Main = preload("res://scripts/Main.gd")
const Progress = preload("res://scripts/systems/CampaignProgress.gd")
const Store = preload("res://scripts/systems/CampaignProgressStore.gd")
const Support = preload("TestSupport.gd")
var failures := 0
var assertions := 0
func check(ok: bool,message: String) -> void:
	assertions += 1
	if not ok: failures += 1; push_error("TEST FAIL: SaltChapterLaunchTest "+message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var path := "user://salt_launch_%d.json"%OS.get_process_id()
	check(not FileAccess.file_exists(path) and not FileAccess.file_exists(path+".bak"),"owned save must be absent")
	if failures: quit(1); return
	var progress := Progress.new()
	check(progress.record_boss_defeat(1) and progress.record_boss_defeat(2) and Store.new(path).save_progress(progress),"isolated prerequisites failed")
	var before := FileAccess.get_sha256(path)
	var main := Main.new(); main.audio_enabled = false; main.campaign_store_path = path
	root.add_child(main); current_scene = main
	check(main._can_start_campaign_chapter(1) and main._can_start_campaign_chapter(2),"previous chapters blocked")
	check(main._can_start_campaign_chapter(3) and not main._can_start_campaign_chapter(4),"actual third unavailable or future fourth accepted")
	main.ui.start_screen.regions_button.pressed.emit(); main.ui.start_screen.chapter_buttons[2].pressed.emit()
	check(main.ui.start_screen.selected_chapter==3 and not main.ui.start_screen.launch_button.disabled,"unlocked salt menu blocked")
	if failures:
		Support.stop_audio(main.audio); main.free(); DirAccess.remove_absolute(path); quit(1); return
	main.ui.start_screen.launch_button.pressed.emit(); await process_frame; await process_frame
	var chapter = current_scene
	check(chapter!=main and chapter.get_script().resource_path.ends_with("SaltChapter.gd"),"third launch uses old demo or other chapter")
	check(chapter.campaign_store_path==path and chapter.director.get_encounter().id==&"salt_locks" and chapter.director.tidal_field==chapter.map.tidal_field,"actual salt encounter/field absent")
	check(FileAccess.get_sha256(path)==before,"launch forged progress")
	chapter.ui.return_button.pressed.emit(); await process_frame; await process_frame
	var returned = current_scene
	check(returned.get_script()==Main and returned._can_start_campaign_chapter(3) and not returned._can_start_campaign_chapter(4),"Back loses third or opens unbuilt fourth")
	check(FileAccess.get_sha256(path)==before,"Back forged progress")
	paused = false; Support.stop_audio(returned.audio); returned.free(); await process_frame
	check(DirAccess.remove_absolute(path)==OK,"owned save cleanup failed")
	if not failures: print("TEST PASS: SaltChapterLaunchTest %d"%assertions)
	quit(1 if failures else 0)
