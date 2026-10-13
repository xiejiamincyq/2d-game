extends "EchoChapterLaunchTest.gd"
## Real Main/scene/UI boundary, controlled prerequisites; NOT ordinary victory.
func check(ok: bool,label: String) -> void:
	assertions += 1
	if not ok: failures += 1; push_error("TEST FAIL: RiftChapterLaunchTest "+label)
func run() -> void:
	var path := "user://rift_launch_%d.json"%OS.get_process_id()
	check(not FileAccess.file_exists(path) and not FileAccess.file_exists(path+".bak"),"owned save must be absent")
	if failures: quit(1); return
	var progress := Progress.new()
	for number in range(1,6): check(progress.record_boss_defeat(number),"sequential prerequisite fixture")
	check(Store.new(path).save_progress(progress),"isolated prerequisite save")
	var before := FileAccess.get_sha256(path)
	var main := Main.new(); main.audio_enabled = false; main.campaign_store_path = path
	root.add_child(main); current_scene = main
	for number in range(1,7): check(main._can_start_campaign_chapter(number),"verified chapter unavailable: "+str(number))
	check(not main._can_start_campaign_chapter(7),"seventh chapter invented")
	if not failures:
		main.ui.start_screen.regions_button.pressed.emit(); main.ui.start_screen.chapter_buttons[5].pressed.emit()
		check(main.ui.start_screen.selected_chapter==6 and not main.ui.start_screen.launch_button.disabled,"actual sixth menu blocked")
		main.ui.start_screen.launch_button.pressed.emit(); await process_frame; await process_frame
		var chapter = current_scene
		check(chapter!=main and chapter.get_script().resource_path.ends_with("RiftChapter.gd"),"launch reuses old waves/wrong chapter")
		check(chapter.campaign_store_path==path and chapter.director.get_encounter().id==&"outer_calibration" and chapter.director.rift_field==chapter.map.rift_field,"actual sixth map/director/field missing")
		check(FileAccess.get_sha256(path)==before and not chapter.progress.has_cleared(6),"launch fabricates progress")
		for _frame in 360:
			if not chapter.player.is_entrance_active(): break
			await process_frame
		chapter.ui.proceed_button.pressed.emit(); chapter.director.set_process(false)
		for _step in 20:
			chapter.director._process(0.25)
			if not chapter.director.get_active_enemies().is_empty(): break
		check(chapter.map.rift_field.active and not chapter.director.get_active_enemies().is_empty(),"Back fixture lacks actual live sixth combat")
		chapter._toggle_pause(); chapter.audio.set_bgm_volume(0.37); chapter.audio.set_bgm_muted(true)
		chapter.ui.return_button.pressed.emit(); await process_frame; await process_frame
		main = current_scene
		check(main.get_script()==Main and main._can_start_campaign_chapter(6) and not main._can_start_campaign_chapter(7),"Back loses sixth or creates seventh")
		check(main.campaign_store_path==path and is_equal_approx(main.audio.bgm_volume_linear,0.37) and main.audio.bgm_muted,"Back loses actual save path/audio preferences")
		check(FileAccess.get_sha256(path)==before and not main.campaign_progress.has_cleared(6),"aborting living combat fabricates clear or rewrites progress")
	paused = false; Support.stop_audio(main.audio); main.free(); await process_frame
	check(DirAccess.remove_absolute(path)==OK,"owned save cleanup")
	if FileAccess.file_exists(path+".bak"): check(DirAccess.remove_absolute(path+".bak")==OK,"owned backup cleanup")
	if not failures: print("TEST PASS: RiftChapterLaunchTest %d"%assertions)
	quit(1 if failures else 0)
