extends SceneTree
## Unmodified factory actors, real physics and ordinary Input only. This is the
## <=32px legacy contact branch, NOT the already-covered CLAW/POUNCE/CHARGE.
const Factory = preload("res://scripts/campaign/RegionalEnemyFactory.gd")
const PlayerActor = preload("res://scripts/actors/Player.gd")
const BaseEnemy = preload("res://scripts/actors/Enemy.gd")
const ROLES := [[1, "root_pursuer", 24.0], [2, "slag_charger", 18.0]]
const SCENARIOS := ["stand", "open-side", "open-back", "wall-stand", "wall-back"]
const REACTION_SECONDS := 0.25
const OBSERVE_AFTER_CUE := 0.80 # Before the unmodified 1.02s second attack cycle.
var checks := 0
var failures := 0
var completed_cases := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("TEST FAIL: CampaignCloseContactReactionTest " + label)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var original_rate := Engine.physics_ticks_per_second
	var rate := 60
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--ticks="):
			rate = int(argument.trim_prefix("--ticks="))
	check(rate in [30, 60, 120], "supported natural physics rate")
	if failures:
		quit(1)
		return
	Engine.physics_ticks_per_second = rate
	for entry in ROLES:
		for scenario in SCENARIOS:
			await _case(entry, rate, scenario)
	Engine.physics_ticks_per_second = original_rate
	_clear_input()
	check(completed_cases == ROLES.size() * SCENARIOS.size(), "all ten close-contact natural cases completed")
	if failures == 0:
		print("TEST PASS: CampaignCloseContactReactionTest %d" % checks)
	else:
		print("TEST RED: CampaignCloseContactReactionTest %dHz %d failures / %d checks" % [rate, failures, checks])
	quit(1 if failures else 0)

func _case(entry: Array, rate: int, scenario: String) -> void:
	_clear_input()
	var label := "%dHz %s legacy-contact %s: " % [rate, entry[1], scenario]
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.world_2d = World2D.new()
	root.add_child(viewport)
	var arena := Node2D.new()
	viewport.add_child(arena)
	var shots := Node2D.new()
	arena.add_child(shots)
	var player := PlayerActor.new()
	player.position = Vector2(432, 400)
	player.world_bounds = Rect2(-3000, -3000, 6000, 6000)
	arena.add_child(player)
	# Let real neutral Player physics admit input without bypassing any guards.
	await physics_frame
	await process_frame
	await physics_frame
	await process_frame
	check(not player.spawn_input_guard_active and not player.entrance_active, label + "ordinary player has no input/entrance guard")
	check(player.health.current_health == 100 and player.shield == 0 and
		is_equal_approx(player.get_effective_move_speed(), 235) and
		is_equal_approx(player.player_collision.shape.radius, 16.9), label + "normal 235/16.9/100/0 player")
	var actor = Factory.create_actor(int(entry[0]), String(entry[1]), 0, shots, player)
	check(actor != null and actor.get_script() == BaseEnemy, label + "actual factory returns the base Enemy")
	if actor == null:
		viewport.free()
		await process_frame
		return
	actor.position = Vector2(400, 400)
	actor.world_bounds = player.world_bounds
	# Only initial placement is allowed. No attack cooldown, clock, range, health,
	# immunity, or position field is changed once the actor joins the physics tree.
	var separation_limit: float = actor.body_radius + player.player_collision.shape.radius + actor.safe_margin + player.safe_margin
	var initial_distance := maxf(32.0, separation_limit + 0.25)
	player.position = actor.position + Vector2(initial_distance, 0)
	var start := player.global_position
	check(initial_distance > separation_limit and initial_distance <= actor.attack_range,
		label + "legal non-overlapping initial bodies remain inside legacy attack range")
	check(initial_distance <= 36.0 and initial_distance < 72.0,
		label + "initial placement cannot trigger CLAW (>36) or CHARGE (>=72)")
	check(is_equal_approx(actor.contact_damage, float(entry[2])), label + "unmodified factory contact damage")
	if scenario.begins_with("wall-"):
		var wall := StaticBody2D.new()
		wall.position = Vector2(start.x, 360)
		var collision := CollisionShape2D.new()
		var rectangle := RectangleShape2D.new()
		rectangle.size = Vector2(1600, 40)
		collision.shape = rectangle
		wall.add_child(collision)
		arena.add_child(wall)
		check(start.y - 380.0 > player.player_collision.shape.radius + player.safe_margin,
			label + "wall above is close but does not overlap the player; right exit exists")
	var start_tick := Engine.get_physics_frames()
	var damage_ticks: Array[int] = []
	var damage_amounts: Array[float] = []
	var observed_health := [100.0]
	player.health_changed.connect(func(current: float, _maximum: float) -> void:
		if current < observed_health[0]:
			damage_ticks.append(Engine.get_physics_frames())
			damage_amounts.append(observed_health[0] - current)
		observed_health[0] = current)
	arena.add_child(actor)
	var cue_tick := -1
	var input_tick := -1
	var cue_timer := -1.0
	var cue_seconds := 0.0
	var legacy_observed := false
	var normal_state := true
	var neutral_before_reaction := true
	var exit_checked := false
	var standing := scenario in ["stand", "wall-stand"]
	var reaction_ticks := int(ceil(REACTION_SECONDS * rate))
	while Engine.get_physics_frames() - start_tick < rate * 4:
		await physics_frame
		await process_frame
		var tick := Engine.get_physics_frames()
		var cue := _actual_head_cue_visible(actor)
		if cue and cue_tick < 0:
			cue_tick = tick
			cue_timer = actor.attack_timer
			legacy_observed = (actor.is_attacking and actor.attack_timer > 0 and
				not actor.basic_attack.is_active() and not actor.charge_attack.is_active())
			check(legacy_observed, label + "first real head cue belongs to legacy contact, not a special controller")
			check(player.health.current_health == 100, label + "first head warning precedes any real damage")
		if cue:
			cue_seconds += 1.0 / rate
		if not exit_checked:
			exit_checked = true
			var probe := PhysicsShapeQueryParameters2D.new()
			var body := CircleShape2D.new()
			body.radius = player.player_collision.shape.radius + player.safe_margin
			probe.shape = body
			probe.transform = Transform2D(0, player.global_position)
			probe.motion = Vector2(180, 0) # Ordinary wall-back/open-back exit.
			probe.collision_mask = player.collision_mask
			probe.exclude = [player.get_rid()]
			var sweep := viewport.world_2d.direct_space_state.cast_motion(probe)
			check(sweep.size() == 2 and is_equal_approx(sweep[0], 1.0), label + "real collision query confirms open right exit")
		if input_tick < 0:
			neutral_before_reaction = neutral_before_reaction and Input.get_vector("move_left", "move_right", "move_up", "move_down") == Vector2.ZERO
		if not standing and cue_tick >= 0 and input_tick < 0 and tick - cue_tick >= reaction_ticks:
			Input.action_press("move_down" if scenario == "open-side" else "move_right")
			input_tick = tick
		normal_state = (normal_state and not player.is_damage_immune() and not player.is_stealthed() and
			not player.dash_active and not player.player_collision.disabled and player.shield == 0)
		if cue_tick >= 0 and tick - cue_tick >= int(ceil(OBSERVE_AFTER_CUE * rate)):
			break
	_clear_input()
	check(cue_tick >= 0 and legacy_observed, label + "actual visible native head cue was observed")
	check(normal_state, label + "no dash, immunity source, stealth, shield, or disabled collision assistance")
	check(neutral_before_reaction, label + "no movement input before human reaction delay")
	if standing:
		check(input_tick == -1, label + "standing control has no movement input")
		check(damage_ticks.size() == 1 and damage_amounts.size() == 1 and
			is_equal_approx(damage_amounts[0], float(entry[2])) and
			is_equal_approx(player.health.current_health, 100.0 - float(entry[2])),
			label + "stationary keeps exactly the original one-hit factory damage")
	else:
		check(input_tick >= cue_tick + reaction_ticks and cue_tick >= 0,
			label + "ordinary Input starts only after >=0.25s from actual cue")
		check(start.distance_to(player.global_position) > 100,
			label + "normal Input actually moves along the open exit")
		check(damage_ticks.is_empty(), label + "first contact must not hit before/through the delayed ordinary escape")
		check(is_equal_approx(player.health.current_health, 100), label + "human-reactable side/back escape remains undamaged")
	var hit_after_cue := float(damage_ticks[0] - cue_tick) / rate if not damage_ticks.is_empty() and cue_tick >= 0 else -1.0
	var reaction := float(input_tick - cue_tick) / rate if input_tick >= 0 and cue_tick >= 0 else -1.0
	print("CLOSE CONTACT CASE: %s distance=%.3f nonoverlap>%.3f configured_windup=%.3f cue_timer=%.3f cue_visible=%.3f hit_after_cue=%.3f reaction=%.3f hp=%.1f moved=%.1f damage=%s" %
		[label, initial_distance, separation_limit, actor.attack_windup, cue_timer, cue_seconds, hit_after_cue, reaction, player.health.current_health, start.distance_to(player.global_position), damage_amounts])
	completed_cases += 1
	viewport.free()
	await process_frame

func _actual_head_cue_visible(actor: Node) -> bool:
	var status: Node2D = actor.world_status
	if status == null or status.warning == null or not status.warning.is_visible_in_tree():
		return false
	# The same real WorldStatus state and Actor predicate used by _draw_warning.
	if status._last_state.size() < 4 or not status._last_state[3] or not actor.should_show_attack_marker():
		return false
	var point: Vector2 = status.warning.get_global_transform_with_canvas() * Vector2(0, actor.get_attack_marker_top())
	return Rect2(Vector2.ZERO, Vector2(1280, 720)).has_point(point)

func _clear_input() -> void:
	for action in ["move_left", "move_right", "move_up", "move_down", "dash_melee", "fire"]:
		Input.action_release(action)
