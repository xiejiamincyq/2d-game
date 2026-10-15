extends SceneTree
## One locked attack, real physics/input; the upper wall leaves a right exit.
const Factory = preload("res://scripts/campaign/RegionalEnemyFactory.gd")
const PlayerActor = preload("res://scripts/actors/Player.gd")
const CASES := [
	[1,"root_pursuer","CLAW",50.0], [1,"root_pursuer","POUNCE",105.0],
	[3,"flanking_crab","PINCER",50.0], [5,"circling_shade","HOOK",45.0],
	[5,"circling_shade","DASH",80.0], [2,"slag_charger","CHARGE",72.0],
	[4,"splitting_mote","MOTHER",40.0], [4,"splitting_mote","FRAGMENT",27.0],
]
var checks := 0
var failures := 0

func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("TEST FAIL: CampaignMeleeReactionTest " + label)

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	var original_rate := Engine.physics_ticks_per_second
	var rate := 60
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--ticks="): rate = int(argument.trim_prefix("--ticks="))
	check(rate in [30,60,120],"supported physics rate")
	Engine.physics_ticks_per_second = rate
	for entry in CASES:
		for scenario in ["stand","open-side","wall-back"]:
			await _case(entry,rate,scenario)
	Engine.physics_ticks_per_second = original_rate
	_clear_input()
	check(checks >= 150,"all 24 natural melee cases finished")
	if not failures: print("TEST PASS: CampaignMeleeReactionTest %d" % checks)
	else: print("TEST RED: CampaignMeleeReactionTest %dHz %d failures / %d checks" % [rate,failures,checks])
	quit(1 if failures else 0)

func _case(entry: Array,rate: int,scenario: String) -> void:
	_clear_input()
	var label := "%dHz %s %s %s: " % [rate,entry[1],entry[2],scenario]
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280,720)
	viewport.world_2d = World2D.new()
	root.add_child(viewport)
	var arena := Node2D.new()
	viewport.add_child(arena)
	var shots := Node2D.new()
	arena.add_child(shots)
	var player := PlayerActor.new()
	player.position = Vector2(800,400)
	player.world_bounds = Rect2(-3000,-3000,6000,6000)
	arena.add_child(player)
	await physics_frame
	await process_frame
	var actor = Factory.create_actor(int(entry[0]),String(entry[1]),0,shots,player)
	actor.position = Vector2(400,400)
	actor.world_bounds = player.world_bounds
	if entry[2] == "FRAGMENT":
		# Actual mother death produces production fragments with normal birth guard.
		var children: Array = []
		actor.offspring_prepared.connect(func(prepared): children.append_array(prepared))
		arena.add_child(actor)
		actor.take_damage(1000,&"bullet")
		await process_frame
		check(children.size() == 2,label + "real production split creates two fragments")
		if children.size() != 2:
			viewport.free()
			return
		actor = children[0]
		children[1].queue_free() # Isolate one fragment, not a fabricated swarm escape.
		while actor.spawn_impulse_remaining > 0:
			await physics_frame
			await process_frame
	# This is the only initial placement; all later movement comes from Input.
	player.position = actor.position + Vector2(float(entry[3]),0)
	var start := player.global_position
	if scenario == "wall-back":
		var wall := StaticBody2D.new()
		wall.position = Vector2(start.x,360)
		var shape := CollisionShape2D.new()
		var rectangle := RectangleShape2D.new()
		rectangle.size = Vector2(1600,40)
		shape.shape = rectangle
		wall.add_child(shape)
		arena.add_child(wall)
		check(start.y - 380 > player.player_collision.shape.radius,label + "wall above leaves unblocked right exit")
	if not actor.is_inside_tree(): arena.add_child(actor)
	actor.basic_attack.cooldown = 0
	actor.charge_attack.cooldown = 0
	check(player.health.current_health == 100 and player.shield == 0 and
		is_equal_approx(player.get_effective_move_speed(),235) and
		is_equal_approx(player.player_collision.shape.radius,16.9),label + "normal player stats")
	var elapsed := 0.0
	var began := -1.0
	var reaction := -1.0
	var warning_duration := -1.0
	var no_assistance := true
	var neutral_input := true
	var warning_frame := -1
	var reaction_frame := -1
	var observed_batch := 0
	var prior_frame := Engine.get_physics_frames()
	var origin_frame := prior_frame
	while elapsed < 4:
		await physics_frame
		await process_frame
		observed_batch=maxi(observed_batch,Engine.get_physics_frames()-prior_frame)
		prior_frame=Engine.get_physics_frames()
		# Rendering may batch multiple physics ticks. Time the real simulation,
		# not the number of coroutine observations (120Hz physics/60FPS is valid).
		elapsed=float(prior_frame-origin_frame)/rate
		neutral_input = neutral_input and Input.get_vector("move_left","move_right","move_up","move_down") == Vector2.ZERO
		if actor.should_show_attack_marker() and began < 0:
			began = elapsed
			warning_frame=Engine.get_physics_frames()
			warning_duration = actor.charge_attack.WARNING if entry[2] == "CHARGE" else actor.basic_attack.get_warning_duration()
			if entry[2] in ["CLAW","POUNCE","HOOK","DASH"]:
				var expect_pounce: bool = entry[2] in ["POUNCE","DASH"]
				check((actor.basic_attack.move == actor.basic_attack.Move.POUNCE) == expect_pounce,label + "requested natural attack branch")
		if scenario != "stand" and warning_frame >= 0 and reaction < 0 and prior_frame-warning_frame>=ceili(0.25*rate):
			Input.action_press("move_right" if scenario == "wall-back" else "move_up")
			reaction = float(prior_frame-warning_frame)/rate
			reaction_frame=Engine.get_physics_frames()
		no_assistance = (no_assistance and not player.is_damage_immune() and not player.is_stealthed() and
			not player.dash_active and not player.player_collision.disabled and player.shield == 0)
		if began >= 0 and elapsed - began >= 1.0: break
	_clear_input()
	check(began >= 0 and elapsed < 4,label + "actual compact head warning observed")
	check(no_assistance,label + "no immunity, dash, stealth, shield or collision bypass")
	if scenario == "stand":
		# Collision push is not player input and has no single-radius upper bound.
		check(neutral_input,label + "standing control had no movement input throughout attack")
		check(player.health.current_health == 100 - actor.contact_damage,label + "stationary takes unchanged real damage")
	else:
		check(reaction >= 0.25,label + "normal input begins after >=0.25s reaction")
		check(reaction<=0.25+float(observed_batch+1)/rate,label+"reaction clock is not diluted by batched physics")
		check(start.distance_to(player.global_position) > 100,label + "normal input really moved along clear exit")
		check(player.health.current_health == 100,label + "first attack leaves human-reactable escape")
	print("MELEE CASE: %s warning=%.3f reaction=%.3f hp=%.1f moved=%.1f" %
		[label,warning_duration,reaction,player.health.current_health,start.distance_to(player.global_position)])
	print("MELEE CLOCK: ",JSON.stringify({"case":label,"sample_reaction":reaction,"physics_reaction":float(reaction_frame-warning_frame)/rate if reaction_frame>=0 else -1.0,"maximum_physics_batch":observed_batch}))
	viewport.free()
	await process_frame

func _clear_input() -> void:
	for action in ["move_left","move_right","move_up","move_down","dash_melee","fire"]:
		Input.action_release(action)
