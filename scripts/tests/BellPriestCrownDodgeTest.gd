extends SceneTree
## Full finite three-note phrase, real input after 0.15s, unchanged player stats.
const Boss = preload("res://scripts/actors/EchoBellPriestBoss.gd")
const Player = preload("res://scripts/actors/Player.gd")
var checks := 0
var failures := 0
var adjacent_moves := 0
var requested_phase := 1
var test_name := "BellPriestCrownDodgeTest"
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error("TEST FAIL: "+test_name+" "+label)
func _initialize() -> void: call_deferred("run")
func release_inputs() -> void:
	for action in ["move_up","move_down","move_left","move_right","fire","dash_melee"]: Input.action_release(action)
func run() -> void:
	var original_rate := Engine.physics_ticks_per_second
	for rate in [30,60,120]:
		Engine.physics_ticks_per_second = rate
		for route in [[Vector2(120,0),"move_down"],[Vector2(-120,0),"move_down"],[Vector2(0,120),"move_right"],[Vector2(0,-120),"move_right"]]:
			for dodge in [false,true]:
				release_inputs()
				var host := Node2D.new(); root.add_child(host)
				var shots := Node2D.new(); host.add_child(shots)
				var player := Player.new(); player.position = route[0]; player.world_bounds = Rect2(-1000,-1000,2000,2000); host.add_child(player)
				var boss := Boss.new(); boss.world_bounds = player.world_bounds; boss.setup(5,shots,player); host.add_child(boss)
				var combat = boss.get_attack_director(); combat.advance(1.4); boss._update_entrance_reveal(); combat.attack_gap = 99
				if requested_phase==3:
					boss.take_damage(boss.health.max_health*0.8); combat.advance(0.65); combat.advance(0.65); combat.attack_gap = 99
				check(combat.current_phase==requested_phase,"actual requested Health phase absent")
				check(player.health.current_health==100 and player.shield==0 and is_equal_approx(player.player_collision.shape.radius,16.9),"actual player defaults changed")
				var births: Array = []; shots.child_entered_tree.connect(func(shot): births.append(shot.get_instance_id()))
				check(combat.start_action(&"crown") and boss.should_show_attack_marker(),"real crown warning absent")
				var origin: Vector2 = combat.locked_origin; var heading: Vector2 = combat.locked_direction
				var previous := player.position; var moves := 0; var input_started := false
				var deadline := Time.get_ticks_msec()+3000
				while (combat.is_attacking() or shots.get_child_count()>0) and Time.get_ticks_msec()<deadline:
					await physics_frame
					if dodge and not input_started and combat.state_elapsed>=0.15: Input.action_press(route[1]); input_started = true
					moves += 1 if player.position.distance_squared_to(previous)>0.01 else 0; previous = player.position
					check(combat.locked_origin==origin and combat.locked_direction==heading,"notes retarget ordinary movement")
				release_inputs(); adjacent_moves += moves
				check(Time.get_ticks_msec()<deadline and births.size()==6 and shots.get_child_count()==0,"three notes do not naturally complete %s/%s"%[rate,route[0]])
				if dodge: check(player.health.current_health==100 and input_started and moves>=4,"0.15 reaction ordinary dodge fails %s/%s; HP=%s"%[rate,route[0],player.health.current_health])
				else: check(player.health.current_health==82 and moves==0,"stationary control not actually hit once %s/%s; HP=%s"%[rate,route[0],player.health.current_health])
				check(player.scale==Vector2.ONE and not player.dash_active and not player.is_stealthed() and not player.player_collision.disabled,"dodge bypasses normal collision")
				host.free(); await process_frame
	release_inputs(); Engine.physics_ticks_per_second = original_rate
	if not failures: print("TEST PASS: %s %d; %d actual adjacent moves, 12 normal-input delayed dodges + 12 stationary hits"%[test_name,checks,adjacent_moves])
	quit(1 if failures else 0)
