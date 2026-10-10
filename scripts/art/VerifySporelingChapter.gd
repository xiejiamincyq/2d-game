extends "res://scripts/art/VerifyNurseryChapterFlow.gd"
## Short normal-input first-chapter gate, not another forced Boss completion.
const EnemySource = preload("res://scripts/actors/Enemy.gd")
const OUTPUT := "res://build/diagnostics/campaign-goal/sporeling-chapter-v2/"
var seen := {}
var observations: Array[Dictionary] = []
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	check(DisplayServer.get_name() != "headless" and not DirAccess.dir_exists_absolute(OUTPUT), "requires GPU and new output")
	if failures:
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	for path in ["scripts/art/VerifySporelingChapter.gd", "scripts/actors/Enemy.gd", "scripts/components/NativeSporelingMotion.gd", "scenes/actors/native/sporeling_paper_v1.tscn", "assets/art/actors/native/sporeling_motion_v1.tres", "scripts/components/NativeActorView.gd", "scripts/campaign/NurseryChapter.gd", "scripts/systems/NurseryEncounterDirector.gd", "scripts/Main.gd", "scripts/art/VerifyNurseryChapterFlow.gd", "scripts/art/NaturalRunPolicy.gd"]:
		sources[path] = FileAccess.get_sha256("res://" + path)
	var main = MainScene.instantiate()
	main.audio_enabled = false
	main.campaign_store_path = OUTPUT + "campaign.json"
	root.add_child(main)
	current_scene = main
	await process_frame
	await _click(main.ui.start_screen.regions_button)
	await _click(main.ui.start_screen.launch_button)
	await process_frame
	var chapter = current_scene
	check(chapter.get_script().resource_path.ends_with("NurseryChapter.gd"), "actual chapter entry failed")
	while chapter.player.is_entrance_active():
		await process_frame
	await _click(chapter.ui.proceed_button)
	chapter.player.fired.connect(func(_shot: Node) -> void: shots += 1)
	var policy := Policy.new(521)
	var frames := 0
	for step in 1500:
		_release()
		if chapter.director.state != chapter.director.State.COMBAT or chapter.player.health.current_health <= 0:
			break
		var spitter: Node2D = null
		var threats: Array[Vector2] = []
		for enemy: Node2D in chapter.director.get_active_enemies():
			threats.append(enemy.position)
			if enemy.kind != EnemySource.EnemyKind.SPITTER or enemy.native_visual == null:
				continue
			spitter = enemy
			var body: Node2D = enemy.native_visual
			var clip: String = body.player.current_animation
			seen[clip] = true
			if step % 4 == 0:
				observations.append({"step":step,"clip":clip,"pose_time":body.player.current_animation_position,"position":[enemy.position.x,enemy.position.y],"hp":enemy.health.current_health,"alpha":body.modulate.a,"mouth_rotation":body.skeleton.get_node("Torso/Head/Mouth").rotation})
			check(body.scene_file_path.ends_with("sporeling_paper_v1.tscn") and enemy.static_visual == null and enemy.should_show_health_bar(), "live spore shooter still raster/no bar")
			if frames < 18 and step % 12 == 0:
				await RenderingServer.frame_post_draw
				check(root.get_texture().get_image().save_png(OUTPUT + "frame_%03d.png" % frames) == OK, "runtime capture failed")
				frames += 1
		var aim: Vector2 = spitter.position if spitter != null else chapter.player.position + Vector2.RIGHT * 300
		var cursor := InputEventMouseMotion.new()
		cursor.position = (root.get_canvas_transform() * aim).clamp(Vector2.ONE,Vector2(root.size)-Vector2.ONE)
		Input.warp_mouse(cursor.position)
		root.push_input(cursor,true)
		var direction: Vector2 = policy.choose_direction(chapter.player.position, Vector2.RIGHT.rotated(step / 100.0) * 180, threats, func(point: Vector2) -> bool: return chapter.map.layout.is_position_walkable(point,chapter.player.get_body_radius()))
		for axis in [["move_left",-direction.x],["move_right",direction.x],["move_up",-direction.y],["move_down",direction.y]]:
			if axis[1] > 0:
				Input.action_press(axis[0],axis[1])
		if step >= 240:
			Input.action_press("fire") # Observe genuine warning/spit before killing.
		var before: Vector2 = chapter.player.position
		await physics_frame
		await process_frame
		moves += 1 if chapter.player.position.distance_to(before) > 0.01 else 0
	_release()
	check(frames == 18 and seen.has("walk") and seen.has("warning") and seen.has("attack"), "normal input did not observe native gait/warning/spit")
	check(moves > 300 and shots > 20, "insufficient real movement/shooting")
	check(not FileAccess.file_exists(OUTPUT + "campaign.json"), "short run falsely wrote Boss clear")
	for path in sources:
		check(FileAccess.get_sha256("res://" + path) == sources[path], "source changed during run")
	var file := FileAccess.open(OUTPUT + "report.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed":failures == 0,"checks":assertions,"frames":frames,"moves":moves,"shots":shots,"kills":chapter.kills,"run_seed":chapter.run_seed,"clips":seen.keys(),"observations":observations,"sources":sources,"scope":"Actual Main pointer entry / random first chapter / normal movement, cursor and fire; no stat writes, forced spawns or direct damage. Short encounter, not Boss completion / all-pose alpha / human acceptance."},"\t"))
	file.close()
	print("SPORELING CHAPTER %s: %d frames, %d moves, %d shots; %s" % ["FAIL" if failures else "PASS",frames,moves,shots,seen.keys()])
	chapter._leave(false,true)
