extends SceneTree
## Controlled actual-actor fixtures, NOT ordinary play or chapter-victory evidence.
## Only entrance is accelerated; attacks and Player movement use real physics ticks.
const Player = preload("res://scripts/actors/Player.gd")
const VineBoss = preload("res://scripts/actors/NurseryVineBoss.gd")
const FurnaceBoss = preload("res://scripts/actors/FoundryFurnaceBoss.gd")
const FoundryMap = preload("res://scenes/world/ember_foundry.tscn")
const HeatVent = preload("res://scripts/world/FoundryHeatVent.gd")
const FoundryDirector = preload("res://scripts/systems/FoundryEncounterDirector.gd")
const Growth = preload("res://scripts/systems/UpgradeSystem.gd")
const REACTION_SECONDS := 0.25
var checks := 0
var failures := 0

func _initialize() -> void: call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("TEST FAIL: BossFairnessFirstSecondTest " + label)

func release_inputs() -> void:
	for action in ["move_up", "move_down", "move_left", "move_right", "fire", "dash_melee"]:
		Input.action_release(action)

func vitality(player: Node) -> float:
	return player.health.current_health + player.shield

func boss_fixture(first: bool) -> Dictionary:
	release_inputs()
	var host := Node2D.new()
	root.add_child(host)
	var shots := Node2D.new()
	host.add_child(shots)
	var player := Player.new()
	player.position = Vector2(150, 0)
	player.world_bounds = Rect2(-1000, -1000, 2000, 2000)
	host.add_child(player)
	var boss = VineBoss.new() if first else FurnaceBoss.new()
	boss.world_bounds = player.world_bounds
	boss.setup(1 if first else 2, shots, player)
	host.add_child(boss)
	var combat = boss.get_attack_director()
	combat.advance(combat.ENTRANCE_SECONDS)
	boss._update_entrance_reveal()
	combat.attack_gap = 99
	return {"host": host, "player": player, "boss": boss, "combat": combat}

func ordinary_player(player: Node, label: String) -> void:
	check(player.scale == Vector2.ONE and not player.dash_active and not player.is_stealthed()
		and not player.player_collision.disabled and player.is_physics_processing(), label + " ordinary physical Player")
	check(is_equal_approx(player.BASE_MOVE_SPEED, 235.0), label + " baseline speed")

func attack_case(hz: int, kind: StringName, dodge: bool) -> void:
	var f := boss_fixture(kind == &"lash")
	var combat = f.combat
	var player = f.player
	var label := "%dHz %s %s" % [hz, kind, "reaction dodge" if dodge else "stationary control"]
	var before := vitality(player)
	var start_position: Vector2 = player.global_position
	var armed: bool = combat.start_action(kind)
	check(armed, label + " armed in open terrain")
	if armed:
		var direction: Vector2 = combat.locked_direction
		var sites: Array = combat.vent_centers.duplicate() if kind == &"vents" else []
		var start_frame := Engine.get_physics_frames()
		var reaction_frames := ceili(REACTION_SECONDS * hz)
		var deadline := Time.get_ticks_msec() + int((float(combat.DURATIONS[kind][0]) + float(combat.DURATIONS[kind][1]) + 3.0) * 1000)
		var moved := false
		var released_at := -1
		while combat.action_stage != combat.Stage.RECOVERY and combat.action_stage != combat.Stage.IDLE and Time.get_ticks_msec() < deadline:
			await physics_frame
			await process_frame
			var elapsed := Engine.get_physics_frames() - start_frame
			if dodge and released_at < 0 and elapsed >= reaction_frames:
				check(player.global_position.distance_to(start_position) < 0.1, label + " no movement during reaction")
				released_at = elapsed
				Input.action_press("move_left" if kind == &"vents" else "move_down")
			moved = moved or player.global_position.distance_to(start_position) > 5.0
		release_inputs()
		check(combat.action_stage == combat.Stage.RECOVERY, label + " actual action clock reached recovery")
		if dodge:
			check(released_at >= reaction_frames and moved, label + " at least 250ms before ordinary movement")
			check(is_equal_approx(vitality(player), before) and not combat.hit_delivered, label + " escaped without damage")
		else:
			check(vitality(player) < before and combat.hit_delivered, label + " real stationary hit")
		check(combat.locked_direction == direction and (kind != &"vents" or combat.vent_centers == sites), label + " target remained locked")
		ordinary_player(player, label)
	f.host.free()
	await process_frame

func add_wall(host: Node2D, at: Vector2, size: Vector2) -> void:
	var body := StaticBody2D.new()
	body.position = at
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = size
	shape.shape = rectangle
	body.add_child(shape)
	host.add_child(body)

func trapped_vents_case(hz: int) -> void:
	var f := boss_fixture(false)
	f.player.position = Vector2(200, 0)
	var center: Vector2 = f.player.position
	# Walls have 45px inner faces. Player fits, but its circle cannot leave the
	# central radius-44 vent. A point-only endpoint or ray is not sufficient.
	for offset in [Vector2(-55, 0), Vector2(55, 0)]:
		add_wall(f.host, center + offset, Vector2(20, 400))
	for offset in [Vector2(0, -55), Vector2(0, 55)]:
		add_wall(f.host, center + offset, Vector2(400, 20))
	await physics_frame
	await physics_frame
	await process_frame
	check(not f.combat.start_action(&"vents") and not f.combat.is_attacking(), "%dHz four-wall vents rejected" % hz)
	f.host.free()
	await process_frame

func heat_case(hz: int, dodge: bool) -> void:
	release_inputs()
	var host := Node2D.new()
	root.add_child(host)
	var map = FoundryMap.instantiate()
	map.map_seed = 521
	host.add_child(map)
	var player := Player.new()
	player.position = Vector2(600, 100)
	player.world_bounds = map.layout.world_bounds
	host.add_child(player)
	var label := "%dHz heat %s" % [hz, "reaction dodge" if dodge else "stationary control"]
	check(map.layout.is_position_walkable(player.position, player.get_body_radius())
		and map.layout.is_position_walkable(player.position + Vector2(100, 0), player.get_body_radius()), label + " real map open fixture")
	var vent := HeatVent.new()
	host.add_child(vent)
	vent.configure(map.layout, player, player.position)
	vent.set_enabled(true)
	check(vent.enabled, label + " real vent armed")
	var deadline := Time.get_ticks_msec() + int((vent.COOLDOWN_TIME + vent.WARNING_TIME + vent.ACTIVE_TIME + 4.0) * 1000)
	while vent.enabled and vent.state != vent.State.WARNING and Time.get_ticks_msec() < deadline:
		await physics_frame
		await process_frame
	check(vent.state == vent.State.WARNING, label + " actual warning reached")
	var before := vitality(player)
	var start_frame := Engine.get_physics_frames()
	var reaction_frames := ceili(REACTION_SECONDS * hz)
	var moving := false
	var saw_active := false
	while vent.enabled and Time.get_ticks_msec() < deadline:
		await physics_frame
		await process_frame
		if dodge and not moving and Engine.get_physics_frames() - start_frame >= reaction_frames:
			Input.action_press("move_right")
			moving = true
		saw_active = saw_active or vent.state == vent.State.ACTIVE
		if saw_active and vent.state == vent.State.COOLDOWN: break
	release_inputs()
	check(saw_active and vent.state == vent.State.COOLDOWN, label + " complete actual active window")
	if dodge:
		check(moving and player.position.x > 605 and is_equal_approx(vitality(player), before), label + " ordinary escape from center after reaction")
	else:
		check(is_equal_approx(before - vitality(player), vent.DAMAGE) and vent.attempted, label + " exactly one real heat hit")
	ordinary_player(player, label)
	host.free()
	await process_frame

func count_encounter(f: Dictionary, expected: int) -> bool:
	var director = f.director
	var began: bool = director.begin_encounter()
	check(began, "formal encounter begins for heat count %d" % expected)
	if not began: return false
	var enabled: int = f.map.heat_field.get_children().filter(func(child): return child.enabled).size()
	check(f.map.heat_field.active and enabled == expected, "formal heat count expected %d actual %d" % [expected, enabled])
	for _step in 100:
		director._process(0.25)
		if director.spawn_queue.is_empty() and director.active_portals.is_empty(): break
	check(not director.get_active_enemies().is_empty(), "formal count fixture has real enemies")
	for enemy in director.get_active_enemies().duplicate(): enemy.take_damage(1e9, &"test")
	await process_frame
	await process_frame
	director._process(0)
	director._process(3.1)
	var reward: Dictionary = f.growth.get_settlement_state()
	if director.state != director.State.REWARD or reward.get("families", []).is_empty():
		check(false, "controlled kills reached genuine reward transaction")
		return false
	var offer: Dictionary = reward.families[0].offers[0].duplicate(true)
	var claimed: bool = director.claim_reward(offer)
	check(claimed and director.finish_reward(), "genuine reward transaction completed")
	return claimed

func formal_heat_counts() -> void:
	# Controlled kills/clock advancement only for the formal encounter policy.
	# This fixture neither claims ordinary combat nor creates a campaign save.
	var host := Node2D.new()
	root.add_child(host)
	var map = FoundryMap.instantiate()
	map.map_seed = 521
	host.add_child(map)
	var player := Player.new()
	player.world_bounds = map.layout.world_bounds
	host.add_child(player)
	player.set_physics_process(false)
	var enemies := Node2D.new()
	var shots := Node2D.new()
	var portals := Node2D.new()
	for layer in [enemies, shots, portals]: host.add_child(layer)
	var growth := Growth.new()
	host.add_child(growth)
	growth.setup(player)
	var director := FoundryDirector.new()
	host.add_child(director)
	director.set_process(false)
	check(director.bind_heat_field(map.heat_field), "formal map-owned heat binding")
	var started: bool = director.start_run(521, player, enemies, shots, portals, growth, map.layout)
	check(started, "formal foundry run starts")
	var f := {"director": director, "map": map, "growth": growth}
	if started and await count_encounter(f, 10):
		if await count_encounter(f, 10):
			var chose: bool = director.choose_route(&"risk")
			check(chose, "formal risk route selected after both rewards")
			if chose: await count_encounter(f, 16)
	host.free()
	await process_frame

func run() -> void:
	var original_hz := Engine.physics_ticks_per_second
	for hz in [30, 60, 120]:
		Engine.physics_ticks_per_second = hz
		for kind in [&"lash", &"jet", &"ram", &"vents"]:
			await attack_case(hz, kind, true)
			await attack_case(hz, kind, false)
		await heat_case(hz, true)
		await heat_case(hz, false)
		await trapped_vents_case(hz)
	Engine.physics_ticks_per_second = original_hz
	release_inputs()
	await formal_heat_counts()
	if failures == 0:
		print("TEST PASS: BossFairnessFirstSecondTest %d; controlled real physics, 250ms reaction, 30/60/120Hz; not ordinary victory" % checks)
	quit(1 if failures else 0)
