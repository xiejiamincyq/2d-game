extends SceneTree
## Production Actor/physics/native pose; quantized 0.15s input reaction, no save/victory.
const Boss = preload("res://scripts/actors/RiftObserverBoss.gd")
const PlayerScript = preload("res://scripts/actors/Player.gd")
var checks := 0
var failures := 0
var adjacent_moves := 0
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error("TEST FAIL: RiftObserverBeamDodgeTest "+label)
func release_inputs() -> void:
	for action in ["move_up","move_down","move_left","move_right","fire","dash_melee"]: Input.action_release(action)
func run() -> void:
	var original_rate := Engine.physics_ticks_per_second
	for rate in [30,60,120]:
		Engine.physics_ticks_per_second = rate
		for route in [
			[Vector2(240,0),["move_down"]],[Vector2(-240,0),["move_down"]],
			[Vector2(0,240),["move_right"]],[Vector2(0,-240),["move_right"]],
			[Vector2(200,200),["move_left","move_down"]],[Vector2(-200,200),["move_right","move_down"]]]:
			for dodge in [false,true]:
				release_inputs(); var host := Node2D.new(); root.add_child(host)
				var shots := Node2D.new(); host.add_child(shots)
				var player := PlayerScript.new(); player.position = route[0]; player.world_bounds = Rect2(-1000,-1000,2000,2000); host.add_child(player)
				var boss := Boss.new(); boss.world_bounds = player.world_bounds; boss.setup(6,shots,player); host.add_child(boss)
				var combat = boss.get_attack_director()
				# Controlled entry setup only. Entire attack below uses natural physics.
				combat.advance(1.4); boss._update_entrance_reveal(); combat.attack_gap = 99
				check(player.health.current_health==100 and player.shield==0 and is_equal_approx(player.move_speed,235) and is_equal_approx(player.get_body_radius(),16.9),"ordinary Player modified")
				check(combat.start_action(&"beam") and boss.should_show_attack_marker(),"real short head warning absent")
				var direction: Vector2 = combat.locked_direction
				var previous := player.global_position; var moves := 0; var input_started := false; var reaction := -1.0
				var active_origin := Vector2.INF; var active_samples := 0
				var deadline := Time.get_ticks_msec()+3000
				while combat.is_attacking() and Time.get_ticks_msec()<deadline:
					await physics_frame
					if dodge and not input_started and combat.action_stage==combat.Stage.WARNING and combat.action_elapsed>=0.15:
						reaction = combat.action_elapsed
						for input in route[1]: Input.action_press(input)
						input_started = true
					moves += 1 if player.global_position.distance_squared_to(previous)>0.01 else 0; previous = player.global_position
					check(combat.locked_direction==direction,"beam follows normal player movement")
					if combat.action_stage==combat.Stage.ACTIVE:
						active_samples += 1
						if not active_origin.is_finite(): active_origin = combat.locked_origin
						check(combat.locked_origin==active_origin and combat.beam.origin==active_origin,"true released origin follows recoil/player")
				release_inputs(); adjacent_moves += moves
				check(Time.get_ticks_msec()<deadline and not combat.beam.armed and active_samples>=2,"real finite beam not completed/visible for physics frames")
				if dodge:
					check(player.health.current_health==100 and input_started and moves>=4 and reaction>=0.15 and reaction<=0.15+1.0/rate+0.00001,"0.15s reaction natural dodge fails %sHz/%s HP%s"%[rate,route[0],player.health.current_health])
				else: check(player.health.current_health==64 and moves==0,"stationary control misses or repeats %sHz/%s HP%s"%[rate,route[0],player.health.current_health])
				check(player.scale==Vector2.ONE and not player.dash_active and not player.is_stealthed() and not player.player_collision.disabled,"dodge bypasses physical body")
				print("OBSERVER NATURAL BEAM: %sHz at%s dodge%s reaction%s moves%s active%s HP%s"%[rate,route[0],dodge,reaction,moves,active_samples,player.health.current_health])
				host.free(); await process_frame
	release_inputs(); Engine.physics_ticks_per_second = original_rate
	if not failures: print("TEST PASS: RiftObserverBeamDodgeTest %d; %d actual adjacent moves, 18 ordinary-input delayed dodges + 18 stationary hits"%[checks,adjacent_moves])
	quit(1 if failures else 0)
func _initialize() -> void: call_deferred("run")
