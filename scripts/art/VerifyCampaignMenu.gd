extends SceneTree

const Main = preload("res://scripts/Main.gd")
const Support = preload("res://scripts/tests/TestSupport.gd")
const DIR := "res://docs/art/previews/campaign/"
class ExitProbe extends Main:
	var exit_code := -1
	func _finish_close(code: int) -> void:
		exit_code = code # Only redirect process termination so evidence can be flushed.

var failures := 0
var assertions := 0
var captures: Array[Dictionary] = []

func check(ok: bool, message: String) -> void:
	assertions += 1
	if not ok:
		failures += 1
		push_error("TEST FAIL: VerifyCampaignMenu " + message)

func _click(view: SubViewport, button: Button) -> void:
	var point := button.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = point
	view.push_input(motion, true)
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		view.push_input(event, true)
		await process_frame

func _key(view: SubViewport, code: int) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.pressed = pressed
		view.push_input(event, true)
		await process_frame

func _capture(view: SubViewport, menu: Control, label: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var filename := "paper-menu-%s-%dx%d-v1.png" % [label, view.size.x, view.size.y]
	var image := view.get_texture().get_image()
	check(image != null and image.get_size() == view.size and image.save_png(DIR + filename) == OK, "capture failed " + filename)
	for target in menu.get_active_controls():
		check(Rect2(Vector2.ZERO, Vector2(view.size)).encloses(target.get_global_rect()), "live Main control exceeds viewport: " + target.name)
	captures.append({"file": filename, "sha256": FileAccess.get_sha256(DIR + filename), "size": [view.size.x, view.size.y], "page": label})

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var paths := ["user://five_minute_overdrive_run_v1.json", "user://five_minute_overdrive_campaign_v1.json"]
	var before := {}
	for path in paths:
		before[path] = FileAccess.get_sha256(path) if FileAccess.file_exists(path) else "absent"
	var sources := {}
	for path in ["scripts/Main.gd", "scripts/ui/GameUI.gd", "scripts/ui/CampaignStartScreen.gd", "scripts/ui/CampaignBackdrop.gd", "scripts/ui/CampaignRegionIcon.gd", "scripts/ui/CampaignMenuTheme.gd"]:
		sources[path] = FileAccess.get_sha256("res://" + path)
	for extent in [Vector2i(960, 540), Vector2i(1280, 720), Vector2i(1920, 1080)]:
		var view := SubViewport.new()
		view.size = extent
		view.world_2d = World2D.new()
		view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		root.add_child(view)
		view.notify_mouse_entered()
		var scene := ExitProbe.new()
		scene.audio_enabled = false
		scene.campaign_store_path = "user://campaign_menu_capture_%d.json" % OS.get_process_id()
		view.add_child(scene)
		# Switch the old snapshot destination before any input can start a run.
		scene.snapshot_store.save_path = "user://campaign_menu_capture_wave_%d.json" % OS.get_process_id()
		scene.ui.set_continue_available(false)
		var menu: Control = scene.ui.start_screen
		await _capture(view, menu, "cover")
		await _click(view, menu.regions_button)
		check(menu.page == menu.Page.CHAPTERS and not scene.run_started, "mouse region entry failed")
		await _click(view, menu.chapter_buttons[5])
		check(menu.selected_chapter == 6 and menu.launch_button.disabled and not scene.run_started, "locked chapter inspection failed")
		await _capture(view, menu, "regions")
		await _key(view, KEY_ESCAPE)
		check(menu.page == menu.Page.COVER and menu.start_button.has_focus(), "Escape did not return to focused cover")
		await _click(view, menu.settings_button)
		check(menu.page == menu.Page.SETTINGS, "mouse settings entry failed")
		await _capture(view, menu, "settings")
		await _key(view, KEY_ESCAPE)
		if extent.x == 1280:
			menu.start_button.grab_focus()
			await _key(view, KEY_ENTER)
			check(scene.run_started and scene.player != null and not menu.visible, "normal Enter did not start unobscured old demo")
			check(scene.campaign_progress.to_state().cleared_chapters.is_empty(), "old run mutated campaign progression")
		else:
			await _click(view, menu.quit_button)
			var deadline := Time.get_ticks_msec() + 2500
			while scene.exit_code < 0 and Time.get_ticks_msec() < deadline:
				await process_frame
			check(scene.exit_code == 0 and scene.audio.is_shutdown_complete(), "normal quit did not drain audio")
		paused = false
		Support.stop_audio(scene.audio)
		view.queue_free()
		await process_frame
	var after := {}
	for path in paths:
		after[path] = FileAccess.get_sha256(path) if FileAccess.file_exists(path) else "absent"
	check(before == after, "capture/input test modified user saves")
	for path in sources:
		check(FileAccess.get_sha256("res://" + path) == sources[path], "sources changed while capturing")
	var report := {"schema": "campaign-menu-runtime-v1", "renderer": RenderingServer.get_video_adapter_name(), "valid": failures == 0, "assertions": assertions, "sources": sources, "user_saves_before": before, "user_saves_after": after, "captures": captures, "limits": ["Only menu input/startup, not full gameplay or chapter completion.", "ExitProbe redirects process termination only; production audio drain is inherited.", "No chapter is playable yet. Demo remains old wave mode."]}
	var file := FileAccess.open(DIR + "paper-menu-runtime-v1.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	if failures == 0:
		print("TEST PASS: VerifyCampaignMenu %d" % assertions)
	quit(1 if failures > 0 else 0)
