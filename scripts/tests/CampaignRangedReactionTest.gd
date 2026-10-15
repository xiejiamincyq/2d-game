extends SceneTree
## Naturally ticking real actors and real Player input, not manual combat clocks.
const Factory = preload("res://scripts/campaign/RegionalEnemyFactory.gd")
const PlayerActor = preload("res://scripts/actors/Player.gd")
const CASES := [
	[1,"spore_spitter",240.0], [2,"spark_gunner",240.0],
	[3,"salt_needle",280.0], [4,"capsule_planter",240.0],
	[5,"echo_sentinel",80.0], [6,"rift_elite",200.0],
	[6,"space_cutter",140.0],
]
const REACTION_SECONDS := 0.25
var checks := 0
var failures := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("TEST FAIL: CampaignRangedReactionTest " + label)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var original_rate := Engine.physics_ticks_per_second
	for rate in [30,60,120]:
		Engine.physics_ticks_per_second = rate
		for entry in CASES:
			await _case(entry,rate,false)
			await _case(entry,rate,true)
	Engine.physics_ticks_per_second = original_rate
	_clear_input()
	check(checks >= 290,"all 42 natural stationary/dodge cases finished")
	if failures == 0:
		print("TEST PASS: CampaignRangedReactionTest %d" % checks)
	else:
		print("TEST RED: CampaignRangedReactionTest %d failures / %d checks" % [failures,checks])
	quit(1 if failures else 0)

func _case(entry: Array, rate: int, dodge: bool) -> void:
	_clear_input()
	var chapter := int(entry[0])
	var role := String(entry[1])
	var label := "%dHz chapter%d %s %s: " % [rate,chapter,role,"dodge" if dodge else "stand"]
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280,720)
	viewport.world_2d = World2D.new()
	root.add_child(viewport)
	var arena := Node2D.new()
	viewport.add_child(arena)
	var shots := Node2D.new()
	arena.add_child(shots)
	var player := PlayerActor.new()
	player.position = Vector2(400 + float(entry[2]),400)
	player.world_bounds = Rect2(-3000,-3000,6000,6000)
	arena.add_child(player)
	# Neutral real physics handles any input admission guard; no field bypass.
	await physics_frame
	await process_frame
	await physics_frame
	await process_frame
	check(not player.spawn_input_guard_active,label + "neutral physics admits input normally")
	check(player.health.current_health == 100 and player.shield == 0 and
		is_equal_approx(player.player_collision.shape.radius,16.9) and
		is_equal_approx(player.get_effective_move_speed(),235),label + "unchanged ordinary player")
	var start := player.global_position
	var actor = Factory.create_actor(chapter,role,0,shots,player)
	check(actor != null,label + "real factory actor")
	if actor == null:
		viewport.free()
		return
	actor.position = Vector2(400,400)
	actor.world_bounds = player.world_bounds
	actor.shoot_cooldown = 0
	actor.basic_attack.cooldown = 0
	arena.add_child(actor)
	var birth_damage: Array[float] = []
	var pending_shots: Array[WeakRef] = []
	var births := [0]
	shots.child_entered_tree.connect(func(child: Node):
		births[0] += 1
		pending_shots.append(weakref(child)))
	var elapsed := 0.0
	var warning_started := -1.0
	var input_started := -1.0
	var warning_visible_seconds := 0.0
	var normal_state := true
	var origin_frame:=Engine.get_physics_frames()
	var warning_frame:=-1
	var last_warning_frame:=-1
	var warning_finished:=false
	var prior_frame:=origin_frame
	var observed_batch:=0
	var input_frame:=-1
	while elapsed < 4.0:
		await physics_frame
		await process_frame
		var frame:=Engine.get_physics_frames()
		observed_batch=maxi(observed_batch,frame-prior_frame); prior_frame=frame
		elapsed=float(frame-origin_frame)/rate
		# MARKSMAN configures damage after add_child; observe completed real tick.
		for reference in pending_shots:
			var shot = reference.get_ref()
			if is_instance_valid(shot) and shot.get("damage") != null:
				birth_damage.append(float(shot.get("damage")))
		pending_shots.clear()
		var marker: bool = actor.should_show_attack_marker()
		if marker and warning_started < 0:
			warning_started = elapsed
			warning_frame=frame
		# A conservative bound for the FIRST continuous cue; never add a later
		# warning or pretend one rendered observation means one physics tick.
		if marker and not warning_finished: last_warning_frame=frame
		elif warning_frame>=0: warning_finished=true
		if dodge and warning_frame >= 0 and input_started < 0 and frame-warning_frame>=ceili(REACTION_SECONDS*rate):
			Input.action_press("move_up")
			input_started = elapsed
			input_frame=frame
		normal_state = (normal_state and not player.is_damage_immune() and not player.is_stealthed() and
			not player.dash_active and not player.player_collision.disabled and player.shield == 0)
		# Enough for the first bullet/rim/cut to cross the stationary player's lane.
		if warning_started >= 0 and elapsed - warning_started >= 1.5:
			break
	_clear_input()
	if last_warning_frame>=warning_frame and warning_frame>=0: warning_visible_seconds=float(last_warning_frame-warning_frame)/rate
	check(warning_started >= 0 and elapsed < 4,label + "real warning observed within watchdog")
	check(normal_state,label + "no dash, stealth, immunity, shield or disabled collision")
	check(warning_visible_seconds >= 0.5,label + "compact warning visible for human reaction window")
	if dodge:
		var reaction_seconds:=float(input_frame-warning_frame)/rate
		check(reaction_seconds >= REACTION_SECONDS,label + "input delayed >=0.25s after visible cue")
		check(reaction_seconds<=REACTION_SECONDS+float(observed_batch+1)/rate,label+"reaction clock is not diluted by batched physics")
		check(player.global_position.y < start.y - 100,label + "real ordinary input actually moved player")
		check(player.health.current_health == 100,label + "normal side movement avoids first attack")
	else:
		check(player.global_position.is_equal_approx(start),label + "stationary control did not move")
		if role in ["echo_sentinel","space_cutter"]:
			var expected := 85.0 if role == "echo_sentinel" else 79.0
			check(player.health.current_health == expected,label + "stationary control suffers unchanged real damage")
		else:
			check(births[0] > 0,label + "real projectile/plant birth, attack not cancelled")
			if chapter != 4:
				var expected_damage: float = {1:21.0,2:9.0,3:36.0,6:12.0}[chapter]
				check(not birth_damage.is_empty() and birth_damage.all(func(value): return value == expected_damage),
					label + "original projectile damage retained")
	print("REACTION CASE: %s warning=%.3f reaction=%.3f hp=%.1f births=%d moved=%.1f" %
		[label,warning_visible_seconds,input_started-warning_started if dodge else -1,
		player.health.current_health,births[0],start.distance_to(player.global_position)])
	print("REACTION CLOCK: ",JSON.stringify({"case":label,"maximum_physics_batch":observed_batch,"warning_first_frame":warning_frame,"warning_last_frame":last_warning_frame}))
	viewport.free()
	await process_frame

func _clear_input() -> void:
	for action in ["move_left","move_right","move_up","move_down","dash_melee","fire"]:
		Input.action_release(action)
