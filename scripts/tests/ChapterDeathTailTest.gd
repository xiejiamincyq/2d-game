extends "res://scripts/tests/NurseryChapterTest.gd"
## Controlled actual Chapter UI/health/clear/save, NOT ordinary-input victory.
const Enemy = preload("res://scripts/actors/Enemy.gd")
const GPU_OUT := "res://build/diagnostics/campaign-goal/chapter-death-tail-gpu-v2/"

func capture_gpu(label: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await process_frame
	await RenderingServer.frame_post_draw
	check(DirAccess.make_dir_recursive_absolute(GPU_OUT) == OK, "GPU evidence directory failed")
	check(root.get_texture().get_image().save_png(GPU_OUT + label + ".png") == OK, "GPU capture failed")

func _run() -> void:
	var owned := "user://chapter_death_tail_%d.json" % OS.get_process_id()
	check(not FileAccess.file_exists(owned), "owned save must start absent")
	var chapter := _fixture(load("res://scenes/campaign/nursery_chapter.tscn"), owned)
	for frame in 360:
		if not chapter.player.is_entrance_active(): break
		await process_frame
	await _battle(chapter)
	await _battle(chapter)
	chapter.ui.supply_button.pressed.emit()
	check(Support.claim_chapter_finale(chapter), "real finale UI failed")
	chapter.ui.proceed_button.pressed.emit()
	var boss: Node = chapter.director.get_active_boss()
	for frame in 360:
		if boss.entrance_resolved: break
		await process_frame
	check(boss.entrance_resolved, "actual Boss entrance not complete")
	# _battle's accelerated fixture disables player physics. Restore it and prove
	# actual input moves before claiming either pause freezes a live player.
	chapter.player.set_physics_process(true)
	await physics_frame
	await process_frame
	var moving_from: Vector2 = chapter.player.position
	Input.action_press("move_up")
	for frame in 6:
		await physics_frame
		await process_frame
	check(chapter.player.position.distance_to(moving_from)>5.0, "live player input did not move before pause")
	var enemy_layer: Node = boss.get_parent()
	var alive := Enemy.new()
	alive.setup(Enemy.EnemyKind.SCRAPPER, 1, chapter.projectiles, chapter.player)
	alive.position = chapter.player.position + Vector2(250, 0)
	enemy_layer.add_child(alive)
	var doomed := Enemy.new()
	doomed.setup(Enemy.EnemyKind.SCRAPPER, 1, chapter.projectiles, chapter.player)
	doomed.position = chapter.player.position + Vector2(200, 0)
	enemy_layer.add_child(doomed)
	var manual_tail: Node2D = doomed.get_visual_node()
	doomed.take_damage(1e9, &"test")
	chapter.ui.pause_button.pressed.emit()
	check(paused and chapter.manually_paused, "formal manual pause failed")
	var alive_position: Vector2 = alive.position
	var player_position: Vector2 = chapter.player.position
	var manual_pose: float = manual_tail.player.current_animation_position
	await create_timer(0.7, true).timeout
	check(is_instance_valid(manual_tail) and manual_tail.player.current_animation_position == manual_pose, "manual pause advanced or removed death tail")
	check(alive.position == alive_position and chapter.player.position == player_position, "manual pause advanced live actors")
	check(chapter.player.is_physics_processing() and not chapter.player.can_process() and alive.is_physics_processing() and not alive.can_process(), "manual pause control was already disabled")
	await capture_gpu("manual_pause")
	Input.action_release("move_up")
	chapter.ui.resume_button.pressed.emit()
	check(not paused and not chapter.manually_paused, "formal resume failed")
	await physics_frame
	await process_frame
	Input.action_press("move_up")
	var survivor := Enemy.new()
	survivor.setup(Enemy.EnemyKind.SCRAPPER, 1, chapter.projectiles, chapter.player)
	survivor.position = chapter.player.position + Vector2(-250, 0)
	enemy_layer.add_child(survivor)
	# Produce multiple fresh tails immediately before an accepted real Boss death.
	var clear_tail: Node2D = alive.get_visual_node()
	alive.take_damage(1e9, &"test")
	check(clear_tail != null, "real small enemy death tail missing")
	check(clear_tail.find_children("*", "CollisionObject2D", true, false).is_empty(), "detached tail still owns gameplay collider")
	var boss_tail: Node2D = boss.get_visual_node()
	var foreign_owner := Node2D.new()
	foreign_owner.process_mode = Node.PROCESS_MODE_PAUSABLE
	root.add_child(foreign_owner)
	var foreign_actor := Enemy.new()
	foreign_actor.setup(Enemy.EnemyKind.SCRAPPER, 1, foreign_owner, chapter.player)
	foreign_owner.add_child(foreign_actor)
	var foreign_tail: Node2D = foreign_actor.get_visual_node()
	foreign_actor.take_damage(1e9, &"test")
	check(boss.take_damage(1e9, &"test"), "accepted Boss damage failed")
	await process_frame
	await process_frame
	check(Support.claim_chapter_carry(chapter), "actual carry choice required")
	check(paused and chapter.clear_saved and chapter.director.state == chapter.director.State.CLEARED, "actual Boss did not create saved paused clear")
	var saved_sha := FileAccess.get_sha256(owned+".journey")
	var final_position: Vector2 = chapter.player.position
	var final_health: float = chapter.player.health.current_health
	var final_kills: int = chapter.kills
	var survivor_position: Vector2 = survivor.position
	var survivor_health: float = survivor.health.current_health
	var foreign_pose: float = foreign_tail.player.current_animation_position
	check(chapter.player.is_physics_processing() and not chapter.player.can_process(), "saved clear disabled player instead of pausing it")
	check(survivor.is_physics_processing() and not survivor.can_process() and not survivor.death_resolved, "saved clear lacks an enabled live enemy pause control")
	await capture_gpu("saved_clear_start")
	await create_timer(0.15, true).timeout
	await capture_gpu("saved_clear_mid")
	await create_timer(1.35, true).timeout
	check(not is_instance_valid(boss_tail), "saved clear freezes actual Boss death tail")
	check(not is_instance_valid(clear_tail) and not is_instance_valid(manual_tail), "saved clear freezes detached small enemy death tails")
	check(paused and chapter.player.position == final_position and chapter.player.health.current_health == final_health and chapter.kills == final_kills, "visual settlement advanced paused gameplay")
	check(FileAccess.get_sha256(owned+".journey") == saved_sha, "visual settlement mutated journey save")
	check(is_instance_valid(survivor) and survivor.position==survivor_position and survivor.health.current_health==survivor_health and not survivor.can_process(), "visual settlement advanced a live enemy")
	check(is_instance_valid(foreign_tail) and foreign_tail.process_mode==Node.PROCESS_MODE_PAUSABLE and foreign_tail.player.current_animation_position==foreign_pose, "cleared Chapter advanced another owner's death tail")
	await capture_gpu("saved_clear_finished")
	Input.action_release("move_up")
	foreign_owner.free()
	check(not is_instance_valid(foreign_tail), "owner cancellation left detached death tail")
	await _dispose(chapter)
	check(Support.cleanup_journey_fixture(owned), "owned journey cleanup failed")
	if FileAccess.file_exists(owned):
		check(DirAccess.remove_absolute(owned) == OK, "owned test save cleanup failed")
	if failures == 0: print("TEST PASS: ChapterDeathTailTest %d" % assertions)
	quit(1 if failures else 0)
