extends SceneTree

const Main = preload("res://scripts/Main.gd")
const Support = preload("res://scripts/tests/TestSupport.gd")
var assertions := 0
var failures := 0

func check(ok: bool, message: String) -> void:
	assertions += 1
	if not ok:
		failures += 1
		push_error("TEST FAIL: CampaignMenuIntegrationTest " + message)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene = Main.new()
	scene.audio_enabled = false
	root.add_child(scene)
	await process_frame
	check(scene.ui.get("start_screen") != null, "Main still uses the old flat start panel")
	if failures > 0:
		Support.stop_audio(scene.audio)
		scene.free()
		quit(1)
		return
	check(not scene.run_started and scene.player == null, "opening the menu started gameplay")
	var menu = scene.ui.start_screen
	menu.regions_button.pressed.emit()
	check(not scene.run_started and not menu.launch_button.disabled, "ready first chapter unavailable or selection started old waves")
	var event := InputEventKey.new()
	event.pressed = true
	event.keycode = KEY_ENTER
	scene.ui._unhandled_input(event)
	check(not scene.run_started, "region page Enter launched the old demo")
	menu.back_button.pressed.emit()
	menu.settings_button.pressed.emit()
	check(is_equal_approx(menu.volume_slider.value, scene.audio.bgm_volume_linear), "settings invented a different audio state")
	menu.volume_slider.value = 0.41
	check(is_equal_approx(scene.audio.bgm_volume_linear, 0.41), "menu did not control actual audio")
	check(is_equal_approx(scene.ui.hud.bgm_volume_slider.value, 41), "HUD volume does not match menu")
	menu.mute_button.button_pressed = true
	check(scene.audio.bgm_muted, "menu mute did not reach audio")
	menu.back_button.pressed.emit()
	menu.start_button.pressed.emit()
	check(scene.run_started and scene.player != null, "one-click old demo no longer starts")
	check(not scene.ui.start_screen.visible and not scene.ui.start_panel.visible and not scene.ui.start_backdrop.visible, "new cover obscures live gameplay")
	check(scene.campaign_progress.to_state().cleared_chapters.is_empty(), "starting old demo advanced campaign progress")
	Support.stop_audio(scene.audio)
	scene.free()
	await process_frame
	# Main must surface corruption and never overwrite/repair it during menu load.
	var path := "user://campaign_menu_corrupt_%d.json" % OS.get_process_id()
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string("not a valid campaign")
	file.close()
	var before := FileAccess.get_sha256(path)
	var corrupt = Main.new()
	corrupt.audio_enabled = false
	corrupt.campaign_store_path = path
	root.add_child(corrupt)
	await process_frame
	corrupt.ui.start_screen.regions_button.pressed.emit()
	check(corrupt.ui.start_screen.storage_label.visible and corrupt.ui.start_screen.storage_label.text.contains("异常"), "Main hides corrupt campaign data")
	check(FileAccess.get_sha256(path) == before, "read-only menu load modified corrupt data")
	check(not FileAccess.file_exists(path + ".tmp") and not FileAccess.file_exists(path + ".bak"), "menu generated a silent replacement save")
	Support.stop_audio(corrupt.audio)
	corrupt.free()
	DirAccess.remove_absolute(path)
	await process_frame
	if failures == 0:
		print("TEST PASS: CampaignMenuIntegrationTest %d" % assertions)
	quit(1 if failures > 0 else 0)
