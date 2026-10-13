extends "res://scripts/art/VerifyChapterReplayRun.gd"
## Actual Main/Player physics handshake. No clear/save or actor stat fixture.
const Support = preload("res://scripts/tests/TestSupport.gd")
func _initialize() -> void: call_deferred("guard_checks")
func guard_checks() -> void:
	check(has_method("resume_ordinary_input"),"Replay lacks neutral physics-frame input handshake")
	if failures: quit(1); return
	await prepare_scene_host()
	var main := MainScene.instantiate()
	var owned := "user://chapter_replay_guard_%d.json"%OS.get_process_id()
	check(not FileAccess.file_exists(owned),"owned save must be absent")
	main.campaign_store_path=owned
	main.audio_enabled=false
	scene_host().add_child(main)
	await process_frame
	await launch_campaign_entry(main)
	await process_frame
	var chapter: Node = actual_scene()
	for frame in 360:
		if not chapter.player.is_entrance_active(): break
		await process_frame
	Input.action_press("move_right")
	await _click(chapter.ui.proceed_button)
	check(chapter.player.spawn_input_guard_active,"actual Proceed did not arm production input guard")
	await call("resume_ordinary_input")
	check(not chapter.player.spawn_input_guard_active,"neutral physics handshake did not clear input guard")
	check(chapter.director.state==chapter.director.State.COMBAT,"handshake changed combat state")
	var before: Vector2=chapter.player.position
	await prepare_layout_capture(chapter)
	_inject_mouse(build_view,build_view.get_canvas_transform()*(before+Vector2(200,0)))
	Input.action_press("move_right")
	Input.action_press("fire")
	for frame in 12:
		await physics_frame
		await process_frame
	_release()
	check(chapter.player.position.distance_to(before)>5 and actual_shots>0,"ordinary movement/fire still blocked after handshake")
	check(not FileAccess.file_exists(owned),"handshake test fabricated Boss save")
	paused=false
	Support.stop_audio(chapter.audio)
	chapter.free()
	build_view.free()
	await process_frame
	if failures==0: print("TEST PASS: ChapterReplayGuardTest %d"%assertions)
	quit(1 if failures else 0)
