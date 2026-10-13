extends SceneTree
## Independent fairness reproduction: real Player, Boss, physics and input.
## Deliberately stricter than earlier immediate/0.15s dodge fixtures.
## Isolated actions in open terrain, NOT all-map/all-monster safety proof.
const Tide = preload("res://scripts/actors/SaltTideBoss.gd")
const Bell = preload("res://scripts/actors/EchoBellPriestBoss.gd")
const Player = preload("res://scripts/actors/Player.gd")
const REACTION_SECONDS := 0.25
var checks := 0
var failures := 0
var adjacent_moves := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("TEST FAIL: BossFairnessThirdFifthTest " + label)
func _initialize() -> void: call_deferred("run")
func release_inputs() -> void:
	for action in ["move_up", "move_down", "move_left", "move_right", "fire", "dash_melee"]:
		Input.action_release(action)
func run() -> void:
	var original_rate := Engine.physics_ticks_per_second
	for rate in [30, 60, 120]:
		Engine.physics_ticks_per_second = rate
		for route in [
			[Tide, 3, &"ripple", Vector2(120, 0), "move_right"],
			[Tide, 3, &"pincer", Vector2(120, -28), "move_right"],
			[Tide, 3, &"salt", Vector2(150, 0), "move_down"],
			[Bell, 5, &"bell", Vector2(120, 0), "move_down"],
			[Bell, 5, &"pendant", Vector2(120, 0), "move_down"],
			[Bell, 5, &"crown", Vector2(120, 0), "move_down"]]:
			for dodge in [false, true]:
				release_inputs()
				var host := Node2D.new(); root.add_child(host)
				var shots := Node2D.new(); host.add_child(shots)
				var player := Player.new(); player.position = route[3]
				player.world_bounds = Rect2(-1000, -1000, 2000, 2000); host.add_child(player)
				var boss = route[0].new(); boss.world_bounds = player.world_bounds
				boss.setup(route[1], shots, player); host.add_child(boss)
				var combat = boss.get_attack_director()
				combat.advance(1.4); boss._update_entrance_reveal(); combat.attack_gap = 99
				check(player.health.current_health == 100 and player.shield == 0 and
					is_equal_approx(player.get_body_radius(), 16.9) and
					is_equal_approx(player.get_effective_move_speed(), 235), "unchanged real player defaults")
				check(combat.start_action(route[2]), "cannot arm action %s/%s" % [rate, route[2]])
				var heading: Vector2 = combat.locked_direction
				var origin: Vector2 = combat.locked_origin
				var previous := player.position; var moves := 0; var input_started := false
				var warning_seconds: float = combat.DURATIONS[route[2]][0]
				var deadline := Time.get_ticks_msec() + 4500
				while (combat.is_attacking() or shots.get_child_count() > 0) and Time.get_ticks_msec() < deadline:
					await physics_frame
					if dodge and not input_started and combat.state_elapsed >= REACTION_SECONDS:
						Input.action_press(route[4]); input_started = true
					moves += 1 if player.position.distance_squared_to(previous) > 0.01 else 0
					previous = player.position
					check(combat.locked_origin == origin and combat.locked_direction == heading,
						"attack retargeted after warning %s/%s" % [rate, route[2]])
				release_inputs(); adjacent_moves += moves
				check(Time.get_ticks_msec() < deadline, "action never completed %s/%s" % [rate, route[2]])
				var label := "%sHz chapter%s/%s warning=%s reaction=%s HP=%s moves=%s" % [
					rate, route[1], route[2], warning_seconds, REACTION_SECONDS, player.health.current_health, moves]
				if dodge:
					check(input_started and moves >= 4, "ordinary input never began " + label)
					check(player.health.current_health == 100, "no-dash delayed escape failed " + label)
				else:
					check(player.health.current_health < 100 and moves == 0, "stationary control did not prove lethal footprint " + label)
				check(player.scale == Vector2.ONE and not player.dash_active and not player.is_stealthed()
					and not player.player_collision.disabled, "escape bypassed physical player " + label)
				print("FAIRNESS CASE: " + label + (" dodge" if dodge else " stationary"))
				host.free(); await process_frame
		await narrow_ring_edge(rate)
	release_inputs(); Engine.physics_ticks_per_second = original_rate
	if not failures:
		print("TEST PASS: BossFairnessThirdFifthTest %d; %d ordinary adjacent moves, 18 delayed escapes + 18 stationary controls; open-terrain isolated actions only" % [checks, adjacent_moves])
	else:
		print("FAIRNESS RESULT: %d failures / %d checks" % [failures, checks])
	quit(1 if failures else 0)

func narrow_ring_edge(rate: int) -> void:
	# Boss still fits this arena. The player's outward escape is bounded;
	# horizontal inward movement is the fastest remaining radial exit.
	# This is a synthetic narrow-arena fixture, not a generated-map claim.
	release_inputs()
	var host := Node2D.new(); root.add_child(host)
	var shots := Node2D.new(); host.add_child(shots)
	var player := Player.new(); player.position = Vector2(200, 0)
	player.world_bounds = Rect2(-1000, -100, 1217, 200); host.add_child(player)
	var boss := Tide.new(); boss.world_bounds = player.world_bounds
	boss.setup(3, shots, player); host.add_child(boss)
	var combat = boss.get_attack_director()
	combat.advance(1.4); boss._update_entrance_reveal(); combat.attack_gap = 99
	var armed: bool = combat.start_action(&"ripple")
	if not armed:
		check(not combat.is_attacking() and shots.get_child_count() == 0,
			"edge rejection leaves a live attack %sHz" % rate)
		print("FAIRNESS CASE: %sHz narrow-ring edge safely rejected" % rate)
	else:
		var started := false; var previous := player.position; var moves := 0
		var deadline := Time.get_ticks_msec() + 4500
		while combat.is_attacking() and Time.get_ticks_msec() < deadline:
			await physics_frame
			if not started and combat.state_elapsed >= REACTION_SECONDS:
				Input.action_press("move_left"); started = true
			moves += 1 if player.position.distance_squared_to(previous) > 0.01 else 0
			previous = player.position
		release_inputs(); adjacent_moves += moves
		check(Time.get_ticks_msec() < deadline and started and moves > 4,
			"narrow-ring ordinary inward escape fixture stalled")
		check(player.health.current_health == 100,
			"edge-trapped expanding ripple is neither rejected nor ordinarily escapable %sHz HP=%s" % [rate, player.health.current_health])
		print("FAIRNESS CASE: %sHz narrow-ring edge inward HP=%s moves=%s" % [rate, player.health.current_health, moves])
	host.free(); await process_frame
