extends "res://scripts/art/VerifyChapterBuildRun.gd"
## Real Main/Player physics pointer fidelity; not a victory or balance fixture.
var observed_shots := 0
const PointerSupport = preload("res://scripts/tests/TestSupport.gd")
func _initialize() -> void: call_deferred("pointer_checks")
func pointer_checks() -> void:
	check(has_method("_observe_build_shot"),"diagnostic lacks read-only actual shot observations")
	if failures: quit(1); return
	await prepare_scene_host()
	check(scene_host() is SubViewport,"build diagnostic still depends on desktop Window cursor")
	if failures: quit(1); return
	var view: SubViewport = scene_host()
	var main := MainScene.instantiate()
	var owned := "user://chapter_build_pointer_%d.json"%OS.get_process_id()
	check(not FileAccess.file_exists(owned),"owned save must be absent")
	main.campaign_store_path = owned
	main.audio_enabled = false
	view.add_child(main)
	await process_frame
	await launch_campaign_entry(main)
	await process_frame
	var chapter: Node = actual_scene()
	check(chapter.has_method("_chapter_number") and chapter._chapter_number()==1,"actual primary Main launch escaped host")
	check(chapter.player.get_viewport()==view,"Player escaped input viewport")
	for frame in 240:
		if not chapter.player.is_entrance_active(): break
		await process_frame
	check(not chapter.player.is_entrance_active(),"natural entrance unfinished")
	await _click(chapter.ui.proceed_button)
	await prepare_layout_capture(chapter)
	chapter.player.fired.connect(func(shot: Node) -> void:
		observed_shots += 1
		var expected: Vector2 = (chapter.player.get_global_mouse_position() - shot.global_position).normalized()
		var fired_direction: Vector2 = (shot.velocity-chapter.player.velocity).normalized()
		check(fired_direction.dot(expected)>0.99999,"actual emitted shot ignores pointer direction")
	)
	for direction: Vector2 in [Vector2.RIGHT,Vector2.DOWN,Vector2.LEFT,Vector2.UP]:
		var point: Vector2 = view.get_canvas_transform()*(chapter.player.global_position+direction*180)
		_inject_mouse(view,point)
		Input.action_press("fire")
		for frame in 12:
			await physics_frame
			await process_frame
			check(view.get_mouse_position().distance_to(point)<0.001,"pointer changed across real physics/process frames")
			var expected: Vector2 = view.get_canvas_transform().affine_inverse()*point
			check(chapter.player.get_global_mouse_position().distance_to(expected)<0.001,"Player reads another coordinate space")
		_release()
	check(observed_shots>=4,"no actual multi-direction firing observed")
	var observations: Array = get("shot_observations")
	check(not observations.is_empty(),"actual shots were not recorded")
	for observation: Dictionary in observations:
		check(float(observation.pointer_error)<0.001 and observation.mouse_world.size()==2 and observation.velocity.size()==2,"recorded real pointer/shot data invalid")
	check(not FileAccess.file_exists(owned),"short pointer test falsely saved Boss clear")
	paused = false
	PointerSupport.stop_audio(chapter.audio)
	chapter.free()
	view.free()
	await process_frame
	if failures==0: print("TEST PASS: ChapterBuildPointerTest %d"%assertions)
	quit(1 if failures>0 else 0)
