extends "res://scripts/art/VerifyNurseryChapterFlow.gd"
## Actual legacy wave: DASHER is not yet part of the unfinished second chapter.
const EnemySource = preload("res://scripts/actors/Enemy.gd")
const OUTPUT := "res://build/diagnostics/campaign-goal/cinder-runtime-v2/"
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	check(DisplayServer.get_name() != "headless" and not DirAccess.dir_exists_absolute(OUTPUT),"requires GPU and fresh output")
	if failures:
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	for path in ["scripts/art/VerifyCinderRunnerRuntime.gd","scripts/actors/Enemy.gd","scripts/components/NativeCinderRunnerMotion.gd","scripts/Main.gd","scripts/systems/WaveDirector.gd","scripts/art/NaturalRunPolicy.gd","scripts/art/VerifyNurseryChapterFlow.gd","scenes/actors/native/cinder_runner_paper_v1.tscn","assets/art/actors/native/cinder_runner_motion_v1.tres"]:
		sources[path] = FileAccess.get_sha256("res://"+path)
		check(sources[path].length() == 64,"missing source hash")
	var main = MainScene.instantiate()
	main.audio_enabled = false
	main.campaign_store_path = OUTPUT+"campaign.json"
	root.add_child(main)
	current_scene = main
	main.snapshot_store.save_path = OUTPUT+"run.json" # Before any start/save write.
	await process_frame
	await _click(main.ui.start_screen.start_button)
	main.player.fired.connect(func(_shot: Node) -> void: shots += 1)
	var policy := Policy.new(20261010)
	var clips := {}
	var frames := 0
	var play_steps := 0
	var observed: Array[Dictionary] = []
	for step in 2400:
		_release()
		if main.player.health.current_health <= 0 or main.run_state == main.RunState.RESULT:
			break
		if main.run_state != main.RunState.PLAYING:
			await physics_frame
			await process_frame
			continue # Real entrance/banner, no time skipping.
		play_steps += 1
		var runner: Node2D = null
		var threats: Array[Vector2] = []
		for enemy in main.wave_director.active_enemies:
			if not is_instance_valid(enemy):
				continue
			threats.append(enemy.position)
			if enemy.kind == EnemySource.EnemyKind.DASHER:
				runner = enemy
		if runner != null:
			var body: Node2D = runner.native_visual
			check(body != null and runner.static_visual == null and body.skeleton.get_bone_count() == 15 and runner.should_show_health_bar(),"natural runner missing rig/bar")
			if body == null:
				break
			clips[body.player.current_animation] = true
			if play_steps % 8 == 0:
				observed.append({"step":play_steps,"clip":body.player.current_animation,"pose_time":body.player.current_animation_position,"hp":runner.health.current_health,"shin":body.skeleton.get_node("Torso/LegL/ShinL").rotation})
			if frames < 24 and play_steps % 4 == 0:
				await RenderingServer.frame_post_draw
				check(root.get_texture().get_image().save_png(OUTPUT+"frame_%03d.png"%frames) == OK,"runtime capture failed")
				frames += 1
		var aim: Vector2 = runner.position if runner != null else main.player.position+Vector2.RIGHT*300
		var cursor := InputEventMouseMotion.new()
		cursor.position = (root.get_canvas_transform()*aim).clamp(Vector2.ONE,Vector2(root.size)-Vector2.ONE)
		Input.warp_mouse(cursor.position)
		root.push_input(cursor,true)
		var direction: Vector2 = policy.choose_direction(main.player.position,aim-main.player.position,threats,func(point: Vector2) -> bool: return main.arena_layout.is_position_walkable(point,main.player.get_body_radius()))
		for axis in [["move_left",-direction.x],["move_right",direction.x],["move_up",-direction.y],["move_down",direction.y]]:
			if axis[1] > 0:
				Input.action_press(axis[0],axis[1])
		Input.action_press("fire")
		var before: Vector2 = main.player.position
		await physics_frame
		await process_frame
		moves += 1 if main.player.position.distance_to(before) > 0.01 else 0
		if frames == 24 and moves > 400 and shots > 50:
			break
	_release()
	check(frames == 24 and clips.has("walk") and moves > 400 and shots > 50,"insufficient natural wave/input evidence")
	for path in sources:
		check(FileAccess.get_sha256("res://"+path) == sources[path],"source changed during run")
	var file := FileAccess.open(OUTPUT+"report.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed":failures == 0,"checks":assertions,"frames":frames,"moves":moves,"shots":shots,"kills":main.kill_count,"map_seed":main.map_seed,"clips":clips.keys(),"observations":observed,"sources":sources,"scope":"Actual Main legacy wave demo, normal pointer/move/fire and natural DASHER portals; not chapter 2, full wave/Boss, every pose or human acceptance. No stat writes or forced actor spawning."},"\t"))
	file.close()
	print("CINDER RUNTIME %s: %d frames/%d moves/%d shots; %s"%["FAIL" if failures else "PASS",frames,moves,shots,clips.keys()])
	main._request_close()
