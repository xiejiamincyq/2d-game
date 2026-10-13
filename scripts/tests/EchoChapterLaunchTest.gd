extends SceneTree
const Main = preload("res://scripts/Main.gd")
const Progress = preload("res://scripts/systems/CampaignProgress.gd")
const Store = preload("res://scripts/systems/CampaignProgressStore.gd")
const Support = preload("TestSupport.gd")
var assertions := 0
var failures := 0
func check(ok: bool,label: String) -> void:
	assertions += 1
	if not ok: failures += 1; push_error("TEST FAIL: EchoChapterLaunchTest "+label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var path := "user://echo_launch_%d.json"%OS.get_process_id()
	check(not FileAccess.file_exists(path) and not FileAccess.file_exists(path+".bak"),"owned save must be absent")
	if failures: quit(1); return
	var progress := Progress.new()
	for chapter in range(1,5): check(progress.record_boss_defeat(chapter),"sequential prerequisite fixture")
	check(Store.new(path).save_progress(progress),"isolated prerequisite save")
	var before := FileAccess.get_sha256(path)
	var main := Main.new(); main.audio_enabled = false; main.campaign_store_path = path
	root.add_child(main); current_scene = main
	for chapter in range(1,5): check(main._can_start_campaign_chapter(chapter),"previous chapter unavailable")
	check(main._can_start_campaign_chapter(5) and not main._can_start_campaign_chapter(6),"verified fifth unavailable or locked sixth admitted before real fifth clear")
	if not failures:
		main.ui.start_screen.regions_button.pressed.emit(); main.ui.start_screen.chapter_buttons[4].pressed.emit()
		check(main.ui.start_screen.selected_chapter==5 and not main.ui.start_screen.launch_button.disabled,"actual fifth menu blocked")
		main.ui.start_screen.launch_button.pressed.emit(); await process_frame; await process_frame
		var chapter = current_scene
		check(chapter!=main and chapter.get_script().resource_path.ends_with("EchoChapter.gd"),"launch reuses old waves/wrong chapter")
		check(chapter.campaign_store_path==path and chapter.director.get_encounter().id==&"outer_bell_walk" and chapter.director.echo_field==chapter.map.echo_field,"actual fifth map/director/field missing")
		check(FileAccess.get_sha256(path)==before,"launch fabricated progress")
		for _frame in 360:
			if not chapter.player.is_entrance_active(): break
			await process_frame
		chapter.ui.proceed_button.pressed.emit(); chapter.director.set_process(false)
		for _step in 20:
			chapter.director._process(0.25)
			if not chapter.director.get_active_enemies().is_empty(): break
		check(chapter.map.echo_field.active and not chapter.director.get_active_enemies().is_empty(),"Back fixture lacks actual live fifth combat")
		chapter._toggle_pause(); chapter.ui.return_button.pressed.emit(); await process_frame; await process_frame
		main = current_scene
		check(main.get_script()==Main and main._can_start_campaign_chapter(5) and not main._can_start_campaign_chapter(6),"Back loses fifth or exposes still-locked sixth")
		check(FileAccess.get_sha256(path)==before and not main.campaign_progress.has_cleared(5),"Back fabricated clear or rewrote progress")
	paused = false; Support.stop_audio(main.audio); main.free(); await process_frame
	check(DirAccess.remove_absolute(path)==OK,"owned save cleanup")
	if not failures: print("TEST PASS: EchoChapterLaunchTest %d"%assertions)
	quit(1 if failures else 0)
