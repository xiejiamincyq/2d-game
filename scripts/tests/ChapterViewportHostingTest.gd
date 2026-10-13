extends SceneTree
## Default Window and embedded engine viewports share the same scene lifecycle.
const Main = preload("res://scripts/Main.gd")
const Support = preload("TestSupport.gd")
var assertions := 0
var failures := 0
func check(ok: bool, message: String) -> void:
	assertions += 1
	if not ok:
		failures += 1
		push_error("TEST FAIL: ChapterViewportHostingTest " + message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var view := SubViewport.new(); view.size = Vector2i(1280,720); view.world_2d = World2D.new()
	root.add_child(view); view.notify_mouse_entered()
	var main := Main.new(); main.audio_enabled = false
	main.campaign_store_path = "user://chapter_viewport_%d.json" % OS.get_process_id()
	check(not FileAccess.file_exists(main.campaign_store_path), "owned save must be absent")
	if failures: view.free(); quit(1); return
	view.add_child(main); current_scene = view
	main.ui.start_screen.regions_button.pressed.emit()
	main.ui.start_screen.launch_button.pressed.emit()
	await process_frame; await process_frame
	var chapter = view.get_child(0) if view.get_child_count() > 0 else current_scene
	check(chapter != main and chapter.get_parent() == view and chapter.get_viewport() == view, "launch escaped its existing viewport")
	check(current_scene == view, "embedded scene replaced the outer SceneTree root")
	if failures:
		paused = false; Support.stop_audio(chapter.audio); chapter.free(); view.free(); await process_frame; quit(1); return
	check(chapter.player.get_world_2d() == view.world_2d and chapter.ui.get_viewport() == view, "physics/HUD uses different host")
	var at := Vector2(840,360)
	var motion := InputEventMouseMotion.new(); motion.position = at; motion.global_position = at
	view.push_input(motion,true)
	check(view.get_mouse_position().distance_to(at) < 0.001, "engine mouse event not delivered")
	var expected: Vector2 = view.get_canvas_transform().affine_inverse() * at
	check(chapter.player.get_global_mouse_position().distance_to(expected) < 0.001, "actual Player reads wrong cursor space")
	var prior_seed: int = chapter.run_seed
	chapter._leave(true)
	await process_frame; await process_frame
	var replay = view.get_child(0)
	check(replay.get_parent() == view and replay.run_seed != prior_seed, "fresh replay escaped host or reused seed")
	replay.ui.return_button.pressed.emit()
	await process_frame; await process_frame
	var returned = view.get_child(0)
	check(returned.get_script() == Main and returned.get_parent() == view, "Back escaped its viewport")
	check(not FileAccess.file_exists(returned.campaign_store_path), "hosting wrote a false clear")
	paused = false; Support.stop_audio(returned.audio); returned.free(); view.free(); await process_frame
	if not failures: print("TEST PASS: ChapterViewportHostingTest %d" % assertions)
	quit(1 if failures else 0)
