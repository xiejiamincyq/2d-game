extends SceneTree
## Real Main -> actual chapter UI -> ordinary movement/fire -> saved clear.
## No actor stat writes, direct damage, injected rewards, or fake Boss death.

const MainScene = preload("res://scenes/Main.tscn")
const Policy = preload("res://scripts/art/NaturalRunPolicy.gd")
const Clearance = preload("res://scripts/art/VerifyNurseryEncounterRun.gd")
const Store = preload("res://scripts/systems/CampaignProgressStore.gd")
const Progress = preload("res://scripts/systems/CampaignProgress.gd")
const Projectile = preload("res://scripts/components/Projectile.gd")
const OUT := "res://build/diagnostics/campaign-goal/nursery-flow-v4/"
var output := OUT
var additional_sources: Array[String] = []
var failures := 0
var assertions := 0
var shots := 0
var moves := 0
var samples: Array[Dictionary] = []
var actions: Array[Dictionary] = []
var sources := {}

func check(ok: bool, message: String) -> void:
	assertions += 1
	if not ok:
		failures += 1
		push_error("TEST FAIL: VerifyNurseryChapterFlow " + message)

func _initialize() -> void:
	call_deferred("_run")

func _release() -> void:
	for action in ["move_left", "move_right", "move_up", "move_down", "fire", "dash_melee"]:
		Input.action_release(action)

func _click(button: Button) -> void:
	check(button.is_visible_in_tree() and not button.disabled, "input target unavailable: " + button.text)
	actions.append({"button": button.text, "physics_frame": Engine.get_physics_frames()})
	var point := button.get_global_rect().get_center()
	Input.warp_mouse(point)
	var motion := InputEventMouseMotion.new()
	motion.position = point
	root.push_input(motion, true)
	for down in [true, false]:
		var click := InputEventMouseButton.new()
		click.position = point
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = down
		root.push_input(click, true)
	await process_frame

func _capture(chapter: Node, step: int, label: String) -> void:
	await RenderingServer.frame_post_draw
	var path := output + "frame_%03d.png" % samples.size()
	check(root.get_texture().get_image().save_png(path) == OK, "native frame save failed")
	var boss = chapter.director.get_active_boss()
	samples.append({"step": step, "label": label, "physics_frame": Engine.get_physics_frames(), "wall_usec": Time.get_ticks_usec(), "state": chapter.director.State.keys()[chapter.director.state], "encounter": chapter.director.encounter_index, "position": [chapter.player.position.x, chapter.player.position.y], "health": chapter.player.health.current_health, "boss_health": boss.health.current_health if boss != null else null, "kills": chapter.kills, "shots": shots, "file": path.trim_prefix("res://"), "sha256": FileAccess.get_sha256(path)})

func _pick_offer(chapter: Node) -> Button:
	# Explicit initialization in a non-awaiting helper avoids stale loop locals
	# across the long-running driver's coroutine/reward state changes.
	var selected: Button = null
	for button: Button in chapter.ui.settlement_screen.offer_buttons:
		if button.visible and not button.disabled:
			if selected == null or button.text.contains("无人机") or button.text.contains("弹道"):
				selected = button
	return selected

func _run() -> void:
	check(DisplayServer.get_name() != "headless", "native rendering required")
	check(not DirAccess.dir_exists_absolute(output), "must not overwrite previous proof")
	if failures > 0:
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(output)
	for path in ["scripts/Main.gd", "scripts/campaign/NurseryChapter.gd", "scripts/ui/NurseryChapterUI.gd", "scripts/systems/NurseryEncounterDirector.gd", "scripts/systems/CampaignProgress.gd", "scripts/systems/CampaignProgressStore.gd", "scripts/actors/Player.gd", "scripts/actors/Enemy.gd", "scripts/actors/OverseerBoss.gd", "scripts/systems/UpgradeSystem.gd", "scripts/art/NaturalRunPolicy.gd", "scripts/art/VerifyNurseryChapterFlow.gd", "scripts/world/NurseryArenaLayout.gd"] + additional_sources:
		sources[path] = FileAccess.get_sha256("res://" + path)
	_release()
	var main = MainScene.instantiate()
	main.campaign_store_path = output + "campaign.json"
	main.audio_enabled = false
	root.add_child(main)
	current_scene = main
	await process_frame
	await _click(main.ui.start_screen.regions_button)
	await _click(main.ui.start_screen.launch_button)
	await process_frame
	var chapter = current_scene
	check(chapter.get_script().resource_path.ends_with("NurseryChapter.gd"), "Main click did not enter chapter")
	if failures > 0:
		quit(1)
		return
	chapter.player.fired.connect(func(_shot: Node) -> void: shots += 1)
	var policy := Policy.new(20261009)
	var prior_state := -1
	var settle_purchases := 0
	var resumed := false
	for step in 30000:
		_release()
		var state: int = chapter.director.state
		if state != prior_state:
			print("FLOW STATE: %s step=%d HP=%.1f kills=%d" % [chapter.director.State.keys()[state], step, chapter.player.health.current_health, chapter.kills])
			await _capture(chapter, step, chapter.director.State.keys()[state])
			prior_state = state
			settle_purchases = 0
			resumed = false
		if state in [chapter.director.State.CLEARED, chapter.director.State.FAILED]:
			break
		if state in [chapter.director.State.INTRO, chapter.director.State.BOSS_READY] and not chapter.ui.proceed_button.disabled:
			await _click(chapter.ui.proceed_button)
		elif state == chapter.director.State.REWARD:
			var reward: Dictionary = chapter.growth.get_settlement_state()
			var selected: Button = _pick_offer(chapter)
			if selected != null and (not reward.reward_claimed or settle_purchases < 3):
				await _click(selected)
				settle_purchases += 1
			else:
				await _click(chapter.ui.settlement_screen.close_button)
		elif state == chapter.director.State.ROUTE:
			await _click(chapter.ui.supply_button)
		elif state in [chapter.director.State.COMBAT, chapter.director.State.COLLECT, chapter.director.State.BOSS]:
			if resumed:
				var threats: Array[Vector2] = []
				var danger_distance := INF
				var aim: Vector2 = chapter.player.position + Vector2(500, 0)
				var nearest := INF
				for enemy in chapter.director.get_active_enemies():
					if not is_instance_valid(enemy) or enemy.health.current_health <= 0:
						continue
					threats.append(enemy.global_position)
					var distance: float = chapter.player.position.distance_squared_to(enemy.global_position)
					if distance < nearest:
						nearest = distance
						aim = enemy.global_position
				for projectile in chapter.projectiles.get_children():
					if projectile is Projectile and projectile.target_group == &"player" and projectile.global_position.distance_to(chapter.player.position) < 400:
						var future: Vector2 = projectile.global_position + projectile.velocity * 0.18
						threats.append(projectile.global_position)
						threats.append(future)
						danger_distance = minf(danger_distance, future.distance_to(chapter.player.position))
				var boss = chapter.director.get_active_boss()
				var telegraph: Node = boss.get_tentacle_attack() if boss != null else null
				if telegraph != null and telegraph.is_attacking():
					threats.append_array(telegraph.get_slam_targets())
				var steering := pilot_motion(chapter, policy, step, threats, telegraph, danger_distance)
				var direction: Vector2 = steering.direction
				for axis in [["move_left", -direction.x], ["move_right", direction.x], ["move_up", -direction.y], ["move_down", direction.y]]:
					if axis[1] > 0:
						Input.action_press(axis[0], axis[1])
				var mouse := InputEventMouseMotion.new()
				mouse.position = (root.get_canvas_transform() * aim).clamp(Vector2.ONE, Vector2(root.size) - Vector2.ONE)
				# Root Window polls the OS mouse position unlike a SubViewport.
				# Use the engine's ordinary cursor input, never write player aim/pose.
				Input.warp_mouse(mouse.position)
				root.push_input(mouse, true)
				Input.action_press("fire")
				if steering.dash and direction != Vector2.ZERO:
					Input.action_press("dash_melee")
			resumed = true
		var before: Vector2 = chapter.player.position
		await physics_frame
		await process_frame
		moves += 1 if chapter.player.position.distance_to(before) > 0.01 else 0
		check(Clearance.has_body_clearance(chapter.player.position, chapter.map.layout.world_bounds, chapter.map.layout.get_obstacle_descriptors(), chapter.player.get_body_radius()), "actual player penetrated terrain")
		if step % 1800 == 0:
			await _capture(chapter, step, "periodic")
	_release()
	var restored := Progress.new()
	check(chapter.clear_saved and chapter.director.state == chapter.director.State.CLEARED, "ordinary run did not reach saved Boss clear")
	check(Store.new(output + "campaign.json").load_progress(restored) == Store.LoadResult.LOADED and restored.is_unlocked(2), "ordinary Boss clear not persisted")
	check(moves > 500 and shots > 50 and chapter.kills >= 30, "insufficient actual movement/fire/kills")
	for path in sources:
		check(FileAccess.get_sha256("res://" + path) == sources[path], "source changed during proof")
	var file := FileAccess.open(output + "report.json", FileAccess.WRITE)
	var report := {"valid": failures == 0, "scope": "Real Main pointer UI and Input.warp_mouse cursor, ordinary movement/aim/fire; no stat writes/direct damage; transitional actors, not human or final art acceptance", "run_seed": chapter.run_seed, "assertions": assertions, "moves": moves, "shots": shots, "actions": actions, "sources": sources, "samples": samples}
	report.merge(additional_report())
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	if failures == 0:
		print("TEST PASS: VerifyNurseryChapterFlow %d" % assertions)
		chapter._leave(false, true)
	else:
		chapter.audio.begin_shutdown()
		chapter.feedback.reset_all()
		quit(1)

func additional_report() -> Dictionary:
	return {}

func pilot_motion(chapter: Node, policy: RefCounted, step: int, threats: Array[Vector2], telegraph: Node, danger_distance: float) -> Dictionary:
	var goal := Vector2.RIGHT.rotated(step / 180.0) * 350
	var direction: Vector2 = policy.choose_direction(chapter.player.position, goal, threats, func(point: Vector2) -> bool:
		if not chapter.map.layout.is_position_walkable(point, chapter.player.get_body_radius()):
			return false
		if telegraph != null and telegraph.is_attacking():
			if telegraph.is_point_in_sweep(point):
				return false
			for target: Vector2 in telegraph.get_slam_targets():
				if point.distance_to(target) < 72:
					return false
		return true
	)
	return {"direction": direction, "dash": danger_distance < 80}
