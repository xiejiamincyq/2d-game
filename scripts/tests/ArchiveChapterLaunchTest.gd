extends SceneTree
const Main = preload("res://scripts/Main.gd")
const Progress = preload("res://scripts/systems/CampaignProgress.gd")
const Store = preload("res://scripts/systems/CampaignProgressStore.gd")
const Support = preload("TestSupport.gd")
var assertions := 0
var failures := 0
func check(ok: bool,label: String) -> void:
	assertions += 1
	if not ok: failures += 1; push_error("TEST FAIL: ArchiveChapterLaunchTest "+label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var path := "user://archive_launch_%d.json"%OS.get_process_id()
	check(not FileAccess.file_exists(path) and not FileAccess.file_exists(path+".bak"),"owned save must be absent")
	if failures: quit(1); return
	var progress := Progress.new()
	check(progress.record_boss_defeat(1) and progress.record_boss_defeat(2) and progress.record_boss_defeat(3) and Store.new(path).save_progress(progress),"isolated predecessor fixture")
	var before := FileAccess.get_sha256(path)
	var main := Main.new(); main.audio_enabled = false; main.campaign_store_path = path
	root.add_child(main); current_scene = main
	check(main._can_start_campaign_chapter(1) and main._can_start_campaign_chapter(2) and main._can_start_campaign_chapter(3),"previous chapters unavailable")
	check(main._can_start_campaign_chapter(4) and not main._can_start_campaign_chapter(5),"actual fourth unavailable or unbuilt fifth admitted")
	if not failures:
		main.ui.start_screen.regions_button.pressed.emit(); main.ui.start_screen.chapter_buttons[3].pressed.emit()
		check(main.ui.start_screen.selected_chapter==4 and not main.ui.start_screen.launch_button.disabled,"unlocked archive menu blocked")
		main.ui.start_screen.launch_button.pressed.emit(); await process_frame; await process_frame
		var chapter = current_scene
		check(chapter!=main and chapter.get_script().resource_path.ends_with("ArchiveChapter.gd"),"fourth launch reuses old waves/wrong chapter")
		check(chapter.campaign_store_path==path and chapter.director.get_encounter().id==&"sealed_shelves" and chapter.director.spore_field==chapter.map.spore_field,"real archive encounter/field missing")
		check(FileAccess.get_sha256(path)==before,"launch fabricated progress")
		chapter.ui.return_button.pressed.emit(); await process_frame; await process_frame
		main = current_scene
		check(main.get_script()==Main and main._can_start_campaign_chapter(4) and not main._can_start_campaign_chapter(5),"Back loses fourth or opens unbuilt fifth")
		check(FileAccess.get_sha256(path)==before,"Back fabricated progress")
	paused = false; Support.stop_audio(main.audio); main.free(); await process_frame
	check(DirAccess.remove_absolute(path)==OK,"owned save cleanup")
	if not failures: print("TEST PASS: ArchiveChapterLaunchTest %d"%assertions)
	quit(1 if failures else 0)
