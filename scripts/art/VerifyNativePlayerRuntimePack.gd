extends SceneTree
## Copy this driver beside a fresh PCK and run there without --path.
const MainScene = preload("res://scenes/Main.tscn")
var failures := 0
var checks := 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("NATIVE PLAYER RUNTIME PACK FAIL: " + message)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	check(not FileAccess.file_exists("res://scripts/art/VerifyNativePlayerRuntimePack.gd") and not FileAccess.file_exists("res://scenes/art/technical/PlayerPaperDraft.gd"), "probe sees workspace/author scripts, not isolated pack")
	var path := "user://native_player_pack_%d/campaign.json" % OS.get_process_id()
	check(not FileAccess.file_exists(path), "isolated save path exists")
	var main = MainScene.instantiate()
	main.audio_enabled = false
	main.campaign_store_path = path
	root.add_child(main)
	current_scene = main
	main.ui.start_screen.regions_button.pressed.emit()
	main.ui.start_screen.launch_button.pressed.emit()
	await process_frame
	await process_frame
	var chapter = current_scene
	check(chapter.get_script().resource_path.ends_with("NurseryChapter.gd"), "actual pack menu failed to enter first chapter")
	var actor: Node2D = chapter.player
	var view: Node2D = actor.get_visual_node()
	check(view.scene_file_path.ends_with("player_paper_v1.tscn"), "actual pack Player still renders atlas")
	check(actor.player_body_texture == null and actor.player_weapon_texture == null, "pack Player loaded legacy textures")
	for frame in 180:
		if not actor.is_entrance_active():
			break
		await process_frame
	check(not actor.is_entrance_active(), "natural pack entrance did not finish")
	chapter.ui.proceed_button.pressed.emit()
	for frame in 120:
		if not chapter.director.get_active_enemies().is_empty():
			break
		await process_frame
	check(not chapter.director.get_active_enemies().is_empty(), "pack has no real enemies")
	var observed: Array[Node] = []
	actor.fired.connect(func(shot: Node) -> void: observed.append(shot))
	var start: Vector2 = actor.position
	Input.action_press("move_right")
	Input.action_press("fire")
	for frame in 15:
		await process_frame
	Input.action_release("move_right")
	Input.action_release("fire")
	check(actor.position.distance_to(start) > 0.01 and not observed.is_empty(), "ordinary pack movement/fire failed")
	check(view.clip in ["shoot", "walk", "idle", "hit"] and view.modulate.a == 1, "native pack motion/opacity failed")
	check(view.get_muzzle_position().is_finite() and is_equal_approx(actor.get_body_radius(), 16.9), "pack muzzle/collision contract changed")
	chapter._toggle_pause()
	chapter.ui.return_button.pressed.emit()
	await process_frame
	await process_frame
	var returned = current_scene
	check(returned.get_script().resource_path.ends_with("Main.gd") and returned.ui.start_screen.visible, "pack battle Back failed")
	check(not FileAccess.file_exists(path), "aborted pack battle wrote false permanent clear")
	if failures == 0:
		print("NATIVE PLAYER RUNTIME PACK PASS: %d checks; actual Main/first chapter, native Player, natural entrance/movement/fire and Back" % checks)
	returned._request_close()
