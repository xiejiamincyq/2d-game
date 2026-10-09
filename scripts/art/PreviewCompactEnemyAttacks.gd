extends SceneTree

# Controlled encounters in the real Main scene. Player input, enemy AI,
# obstacles and attack clocks run normally; spawns/health are diagnostic only.
const Main = preload("res://scripts/Main.gd")
const Enemy = preload("res://scripts/actors/Enemy.gd")
var output := ""
var scene: Node2D
var view: SubViewport
var actors: Array[Node] = []
var samples: Array[Dictionary] = []

func _initialize() -> void:
	call_deferred("run")

func spawn_enemy(kind: int, offset: Vector2, cooldown: float) -> void:
	var enemy := Enemy.new()
	enemy.setup(kind, 0, scene.projectiles, scene.player)
	enemy.position = scene.player.position + offset
	enemy.world_bounds = scene.WORLD_BOUNDS
	enemy.set_arena_navigation(scene.arena_layout)
	scene.enemies.add_child(enemy)
	enemy.basic_attack.cooldown = cooldown
	enemy.shoot_cooldown = cooldown
	actors.append(enemy)

func clear_input() -> void:
	for action in ["move_left", "move_right", "move_up", "move_down", "fire"]:
		Input.action_release(action)

func run() -> void:
	var run_id := OS.get_environment("COMPACT_ATTACK_RUN_ID")
	output = "res://build/diagnostics/compact-enemy/" + run_id
	if DisplayServer.get_name() == "headless" or run_id.is_empty() or not run_id.is_valid_filename() or DirAccess.dir_exists_absolute(output):
		push_error("Fresh native preview output required")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(output)
	view = SubViewport.new()
	view.size = Vector2i(1280, 720)
	view.world_2d = World2D.new()
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	var screen := TextureRect.new()
	screen.size = Vector2(1280, 720)
	screen.texture = view.get_texture()
	root.add_child(screen)
	scene = Main.new()
	scene.audio_enabled = false
	view.add_child(scene)
	scene.snapshot_store.save_path = "user://compact-preview-%s.json" % run_id
	scene._start_run()
	for frame in range(360):
		await process_frame
		if scene.run_state == scene.RunState.PLAYING:
			break
	if scene.run_state != scene.RunState.PLAYING:
		push_error("Main did not reach gameplay")
		quit(1)
		return
	scene.wave_director.set_process(false)
	scene.wave_director.set_physics_process(false)
	scene.portals.process_mode = Node.PROCESS_MODE_DISABLED
	for actor in scene.enemies.get_children():
		actor.queue_free()
	await process_frame
	scene.player.health.max_health = 10000.0
	scene.player.health.current_health = 10000.0
	scene.player.shield = 0.0
	spawn_enemy(0, Vector2(55, 0), 0.0)
	var warning_frames := 0
	var active_frames := 0
	var player_start: Vector2 = scene.player.position
	var screenshot_saved := false
	var attack_saved := false
	for frame in range(900):
		clear_input()
		if frame == 300:
			for index in range(14):
				spawn_enemy(0 if index < 11 else [2, 4, 5][index - 11], Vector2.RIGHT.rotated(index * TAU / 14.0) * (115.0 if index < 11 else 310.0), index * 0.11)
		if frame >= 330:
			Input.action_press(["move_up", "move_left", "move_down", "move_right"][int((frame - 330) / 70) % 4])
		var warnings := 0
		var active := 0
		for actor in actors:
			if is_instance_valid(actor):
				warnings += int(actor.should_show_attack_marker())
				active += int(actor.basic_attack.stage == actor.basic_attack.Stage.ACTIVE or actor.is_attacking and actor.attack_has_hit)
		warning_frames += int(warnings > 0)
		active_frames += int(active > 0)
		await process_frame
		await RenderingServer.frame_post_draw
		if frame % 3 == 0:
			var bitmap := view.get_texture().get_image()
			if bitmap.save_png(output + "/frame-%03d.png" % (frame / 3)) != OK:
				push_error("Capture failed")
				quit(1)
				return
			if warnings > 0 and frame > 300 and not screenshot_saved:
				bitmap.save_png(output + "/head-warning.png")
				screenshot_saved = true
			if active > 0 and frame < 300 and not attack_saved:
				bitmap.save_png(output + "/short-strike.png")
				attack_saved = true
			samples.append({"frame": frame, "physics_frame": Engine.get_physics_frames(), "warnings": warnings, "active": active, "player": [scene.player.position.x, scene.player.position.y]})
	clear_input()
	var valid: bool = warning_frames > 0 and active_frames > 0 and screenshot_saved and attack_saved and scene.player.health.current_health < 10000 and scene.player.position.distance_to(player_start) > 5.0
	var file := FileAccess.open(output + "/report.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"valid": valid, "scope": "real Main, controlled spawns and diagnostic health; normal input movement/AI/terrain/timing, not natural full-run or human feel acceptance", "warning_frames": warning_frames, "active_frames": active_frames, "frames": samples, "player_health": scene.player.health.current_health}, "  "))
	file.close()
	scene.queue_free()
	await create_timer(0.25).timeout
	view.queue_free()
	screen.queue_free()
	await process_frame
	print("COMPACT_ENEMY_PREVIEW valid=%s" % valid)
	quit(0 if valid else 1)
