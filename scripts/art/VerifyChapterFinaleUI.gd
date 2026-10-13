extends "res://scripts/tests/ChapterFinaleFlowTest.gd"
## Controlled combat fixture, then real engine pointer input on new reward UI.
## No ordinary victory, balance or unlock claim.
const OUTPUT := "res://build/diagnostics/campaign-goal/chapter-final-reward-ui-gpu-v1/"
var view: SubViewport
var captures: Array[Dictionary] = []
var sources := {}

func _scene_host() -> Node: return view

func _capture(label: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var path := OUTPUT + "%dx%d-%s.png" % [view.size.x, view.size.y, label]
	var pixels: Image = view.get_texture().get_image()
	check(pixels != null and pixels.get_size() == view.size and pixels.save_png(path) == OK, "GPU capture failed: " + label)
	captures.append({"file":path.trim_prefix("res://"),"sha256":FileAccess.get_sha256(path),"size":[view.size.x,view.size.y],"state":label})

func _click(screen: Control, button: Button) -> void:
	screen.chapter_scroll.ensure_control_visible(button)
	await process_frame
	await process_frame
	var rectangle := button.get_global_rect()
	check(Rect2(Vector2.ZERO,Vector2(view.size)).encloses(rectangle), "pointer target exceeds actual viewport")
	check(screen.chapter_scroll.get_global_rect().encloses(rectangle), "pointer target clipped by scroll viewport")
	var point := rectangle.get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = point
	view.push_input(motion,true)
	for pressed in [true,false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		view.push_input(event,true)
		await process_frame

func _run() -> void:
	if not check(DisplayServer.get_name() != "headless", "requires real GPU, not headless screenshot"):
		quit(1); return
	if not check(not DirAccess.dir_exists_absolute(OUTPUT), "refusing existing output"):
		quit(1); return
	check(DirAccess.make_dir_recursive_absolute(OUTPUT) == OK, "cannot create owned output")
	var user_paths := [Store.DEFAULT_PATH,"user://five_minute_overdrive_run_v1.json"]
	var before := {}
	for path in user_paths:
		before[path] = FileAccess.get_sha256(path) if FileAccess.file_exists(path) else "absent"
	for path in ["scripts/systems/UpgradeSystem.gd","scripts/systems/ChapterEncounterDirector.gd","scripts/campaign/ChapterRun.gd","scripts/ui/ChapterRunUI.gd","scripts/ui/SettlementScreen.gd","scripts/tests/ChapterFinaleFlowTest.gd","scripts/art/VerifyChapterFinaleUI.gd"]:
		sources[path] = FileAccess.get_sha256("res://"+path)
	for extent in [Vector2i(960,540),Vector2i(1280,720),Vector2i(1920,1080)]:
		view = SubViewport.new()
		view.size = extent
		view.world_2d = World2D.new()
		view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		root.add_child(view)
		view.notify_mouse_entered()
		var chapter: Node = _fixture()
		if chapter == null: view.free(); quit(1); return
		await _clear_encounter(chapter)
		await _clear_encounter(chapter)
		chapter.ui.supply_button.pressed.emit()
		var screen: Control = chapter.ui.settlement_screen
		check(chapter.director.state == chapter.director.State.REWARD and screen.current_offers[0].id == "orbital_storm", "real chapter does not offer focused evolution")
		check(Rect2(Vector2.ZERO,Vector2(extent)).encloses(screen.panel.get_global_rect()), "actual final reward panel exceeds viewport")
		await _capture("unclaimed")
		screen.close_button.grab_focus()
		screen.chapter_scroll.ensure_control_visible(screen.close_button)
		await _capture("scroll-bottom")
		await _click(screen,screen.offer_buttons[0])
		check(chapter.growth.get_settlement_state().reward_claimed and chapter.player.active_build_evolutions.has("orbital_storm"), "engine pointer failed to claim actual evolution")
		await _capture("claimed")
		await _click(screen,screen.close_button)
		check(chapter.director.state == chapter.director.State.BOSS_READY and not screen.visible, "engine pointer failed to complete finale")
		await _capture("boss-ready")
		await _dispose(chapter)
		view.free()
		await process_frame
	var after := {}
	for path in user_paths:
		after[path] = FileAccess.get_sha256(path) if FileAccess.file_exists(path) else "absent"
	check(before == after,"actual user saves changed")
	for path in sources:
		check(FileAccess.get_sha256("res://"+path) == sources[path],"source changed during GPU proof")
	for path in owned_paths:
		for suffix in ["",".tmp",".bak"]:
			check(not FileAccess.file_exists(path+suffix),"fixture wrote permanent progress")
	var report := {"schema":1,"valid":failures==0,"assertions":assertions,"renderer":RenderingServer.get_video_adapter_name(),"process_id":OS.get_process_id(),"sources":sources,"captures":captures,"saves_before":before,"saves_after":after,"scope":"Controlled lethal combat fixture; real paused reward UI, real engine pointer claim/close, actual Player evolution and three GPU viewport sizes. Not ordinary combat, human playtest, permanent unlock, whole F3 or final game acceptance."}
	var file := FileAccess.open(OUTPUT+"report.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t")); file.close()
	if failures==0: print("TEST PASS: VerifyChapterFinaleUI %d"%assertions)
	quit(1 if failures>0 else 0)
