extends SceneTree
## Controlled physics candidate, NOT ordinary combat, clear/save or victory proof.
## Real Player input/movement, real Nursery rectangle and real Enemy body. Enemy
## AI is disabled before simulation; no live player pose/stat/solver writes.
## Run with matching --fixed-fps N and user argument --physics-hz=N (30/60/120).
const PlayerScript = preload("res://scripts/actors/Player.gd")
const EnemyScript = preload("res://scripts/actors/Enemy.gd")
const ObstacleScript = preload("res://scripts/world/NurseryObstacle.gd")
const WALL := Rect2(160.0, -300.0, 20.0, 600.0)
const ACTIONS := [&"move_left", &"move_right", &"move_up", &"move_down", &"dash_melee", &"fire"]
var assertions := 0
var failures := 0
var violating_cases := 0

func check(ok: bool, label: String) -> bool:
	assertions += 1
	if not ok:
		failures += 1
		push_error("TEST FAIL: PlayerDashWallContactTest " + label)
	return ok

func _initialize() -> void:
	call_deferred("run_checks")

func release_input() -> void:
	for action in ACTIONS: Input.action_release(action)

func run_checks() -> void:
	await process_frame
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--physics-hz="):
			Engine.physics_ticks_per_second = argument.trim_prefix("--physics-hz=").to_int()
	if not check(Engine.physics_ticks_per_second in [30, 60, 120], "unsupported physics rate"):
		quit(1)
		return
	print("DASH WALL SCOPE: controlled fixtures only; no ordinary combat/save proof; engine=%s hz=%d" % [Engine.get_version_info().string, Engine.physics_ticks_per_second])
	# Empty-wall control separates terrain sweep failure from entity recovery.
	await run_case(false, 0.0)
	for enemy_x in [105.0, 110.0, 120.0]:
		await run_case(true, enemy_x)
	# Same public Player guard invoked by formal Chapter _resume_combat; not just
	# toggling SceneTree pause and leaving the actor lifecycle untested.
	await run_case(true,120.0,"completed_dash_guard")
	await run_case(true,120.0,"interrupted_dash_guard")
	release_input()
	print("DASH WALL RESULT: violating_cases=%d; zero means this candidate was not reproduced, not that the GPU failure is fixed" % violating_cases)
	if failures == 0: print("TEST PASS: PlayerDashWallContactTest %d" % assertions)
	quit(1 if failures else 0)

func run_case(with_enemy: bool, enemy_x: float, resume_mode := "none") -> void:
	release_input()
	var scene := Node2D.new()
	root.add_child(scene)
	var wall := ObstacleScript.new()
	wall.setup(WALL, &"root_wall")
	scene.add_child(wall)
	var player := PlayerScript.new()
	scene.add_child(player)
	player.set_physics_process(false)
	var enemy: CharacterBody2D = null
	if with_enemy:
		enemy = EnemyScript.new()
		enemy.setup(EnemyScript.EnemyKind.BRUISER, 1, scene, player)
		enemy.position = Vector2(enemy_x, 0.0) # Arrangement only, before simulation.
		scene.add_child(enemy)
		enemy.set_physics_process(false) # Keep real collider; disable attacks/AI.
	await physics_frame
	await process_frame
	await physics_frame
	await process_frame
	var label := "enemy_x_%.0f" % enemy_x if with_enemy else "no_enemy_control"
	label += "_"+resume_mode
	var ready := check(player.player_collision.shape is CircleShape2D and player.player_collision.global_scale.is_equal_approx(Vector2.ONE), label + " real player circle invalid")
	ready = check(player.active_build_evolutions.is_empty() and not player.is_stealthed() and not player.stealth_recovery_pending, label + " must exercise never-stealthed ordinary dash") and ready
	ready = check(circle_gap(player.global_position, player.get_body_radius()) >= 0.0, label + " player initially intersects terrain") and ready
	if with_enemy:
		ready = check(circle_gap(enemy.global_position, enemy.body_radius) >= 0.0 and player.global_position.distance_to(enemy.global_position) > player.get_body_radius() + enemy.body_radius, label + " fixture starts overlapped") and ready
	if not ready:
		scene.queue_free()
		await process_frame
		return
	var previous_frame := Engine.get_physics_frames()
	var saw_dash := false
	var saw_dash_end := false
	var overlap_at_dash_end := false
	var initial_health: float = player.health.current_health
	var previous := snapshot(player, enemy)
	var violations: Array[Dictionary] = []
	var transitions: Array[Dictionary] = []
	var guard_invoked := false
	Input.action_press("move_right")
	Input.action_press("dash_melee")
	player.set_physics_process(true)
	for index in Engine.physics_ticks_per_second:
		await physics_frame
		await process_frame # physics_frame precedes the Player callback.
		var actual_frame := Engine.get_physics_frames()
		if not check(actual_frame == previous_frame + 1, label + " skipped/duplicated physics step; match --fixed-fps to --physics-hz"):
			break
		previous_frame = actual_frame
		var current := snapshot(player, enemy)
		if index == 0:
			check(player.dash_active, label + " actual dash input was not consumed")
			Input.action_release("dash_melee")
		saw_dash = saw_dash or player.dash_active
		# At 30 Hz wall contact and natural dash completion share one callback.
		# Cancel the still-active, actually overlapping dash just before contact;
		# higher rates can also expose an active already-blocked frame.
		if resume_mode=="interrupted_dash_guard" and player.dash_active and bool(current.entity_overlap) and float(current.terrain_gap)<10.0 and not guard_invoked:
			paused=true
			player.begin_spawn_input_guard()
			check(player.dash_recovery_pending,label+" cancelled active dash lost body recovery")
			paused=false
			guard_invoked=true
			Input.action_release("move_right")
			current=snapshot(player,enemy)
		if saw_dash and not saw_dash_end and not player.dash_active:
			saw_dash_end = true
			overlap_at_dash_end = bool(current.entity_overlap)
			transitions.append({"before": previous, "after": current})
			# A stationary next ordinary frame isolates native overlap recovery.
			Input.action_release("move_right")
			if resume_mode=="completed_dash_guard":
				paused=true
				player.begin_spawn_input_guard()
				paused=false
				guard_invoked=true
		if float(current.terrain_gap) < -0.05:
			violations.append({"before": previous, "after": current})
		previous = current
	release_input()
	player.set_physics_process(false)
	check(saw_dash and saw_dash_end, label + " did not observe a complete ordinary dash")
	if resume_mode!="none": check(guard_invoked,label+" formal resume input guard was not invoked")
	if with_enemy:
		check(overlap_at_dash_end, label + " candidate not established: dash did not finish in actual enemy overlap")
		check(is_instance_valid(enemy) and not enemy.death_resolved and enemy.health.current_health > 0.0, label + " dash removed the intended real enemy collider")
	check(is_equal_approx(player.health.current_health, initial_health), label + " controlled enemy unexpectedly attacked")
	print("DASH WALL CASE: " + JSON.stringify({"label": label, "transitions": transitions, "violating_steps": violations.size(), "first_violation": violations[0] if not violations.is_empty() else {}, "last": previous}))
	if not violations.is_empty(): violating_cases += 1
	check(violations.is_empty(), label + " real player circle penetrated terrain during dash/native recovery")
	# The guard must not strand the player or leave entity collision disabled.
	player.set_physics_process(true)
	var escape_from:=player.global_position
	var escape_frame:=Engine.get_physics_frames()
	Input.action_press("move_up")
	for index in Engine.physics_ticks_per_second / 2:
		await physics_frame
		await process_frame
		check(circle_gap(player.global_position,player.get_body_radius())>=-0.05,label+" escape input entered terrain")
	release_input()
	player.set_physics_process(false)
	check(not snapshot(player,enemy).entity_overlap,label+" ordinary tangent input cannot escape enemy overlap")
	check(Engine.get_physics_frames()-escape_frame==Engine.physics_ticks_per_second/2 and player.global_position.y<escape_from.y-30,label+" escape did not execute real moving physics frames")
	check(not player.get("dash_recovery_pending"),label+" post-dash guard never returned to native motion")
	check(not player.player_collision.disabled and player.collision_mask==player.normal_collision_mask and player.collision_layer==player.normal_collision_layer,label+" guard disabled normal collisions")
	scene.queue_free()
	await process_frame

func circle_gap(point: Vector2, radius: float) -> float:
	return point.distance_to(point.clamp(WALL.position, WALL.end)) - radius

func snapshot(player: CharacterBody2D, enemy: CharacterBody2D) -> Dictionary:
	var contacts: Array[Dictionary] = []
	for index in player.get_slide_collision_count():
		var contact := player.get_slide_collision(index)
		var collider := contact.get_collider()
		contacts.append({"collider": collider.get_instance_id() if is_instance_valid(collider) else 0, "class": collider.get_class() if is_instance_valid(collider) else "freed", "normal": xy(contact.get_normal()), "travel": xy(contact.get_travel()), "remainder": xy(contact.get_remainder()), "depth": contact.get_depth(), "collider_velocity": xy(contact.get_collider_velocity())})
	var enemy_gap := INF
	var overlap := false
	if is_instance_valid(enemy):
		enemy_gap = player.global_position.distance_to(enemy.global_position) - player.get_body_radius() - enemy.body_radius
		var query := PhysicsShapeQueryParameters2D.new()
		query.shape = player.player_collision.shape
		query.transform = player.player_collision.global_transform
		query.collision_mask = player.collision_mask
		query.exclude = [player.get_rid()]
		query.collide_with_areas = false
		for hit in player.get_world_2d().direct_space_state.intersect_shape(query, 16):
			overlap = overlap or hit.collider == enemy
	return {"frame": Engine.get_physics_frames(), "position": xy(player.global_position), "shape_position": xy(player.player_collision.global_position), "velocity": xy(player.velocity), "terrain_gap": circle_gap(player.global_position, player.get_body_radius()), "enemy_gap": enemy_gap if is_instance_valid(enemy) else null, "entity_overlap": overlap, "enemy_position": xy(enemy.global_position) if is_instance_valid(enemy) else [], "dash": player.dash_active, "dash_timer": player.dash_timer, "dash_blocked": player.dash_terrain_blocked, "stealth_pending": player.stealth_recovery_pending, "shape_disabled": player.player_collision.disabled, "safe_margin": player.safe_margin, "motion_mode": player.motion_mode, "floor": player.is_on_floor(), "platform_velocity": xy(player.get_platform_velocity()), "contacts": contacts}

func xy(value: Vector2) -> Array:
	return [value.x, value.y]
