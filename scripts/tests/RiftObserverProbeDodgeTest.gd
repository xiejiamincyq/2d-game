extends SceneTree
## Real physics and normal inputs; 0.15s reaction, no teleport during attack/save.
const Boss = preload("res://scripts/actors/RiftObserverBoss.gd")
const PlayerScript = preload("res://scripts/actors/Player.gd")
var checks := 0
var failures := 0
var adjacent_moves := 0
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error("TEST FAIL: RiftObserverProbeDodgeTest "+label)
func release_inputs() -> void:
	for action in ["move_up","move_down","move_left","move_right","fire","dash_melee"]: Input.action_release(action)
func run() -> void:
	var original_rate := Engine.physics_ticks_per_second
	for rate in [30,60,120]:
		Engine.physics_ticks_per_second = rate
		for route in [
			[Vector2(240,0),["move_down"],false],[Vector2(-240,0),["move_down"],false],
			[Vector2(0,240),["move_right"],false],[Vector2(0,-240),["move_right"],false],
			[Vector2(160,160),["move_left","move_down"],false],[Vector2(-160,160),["move_right","move_down"],false],
			# Keep both original distant diagonals as strict range-rejection controls.
			[Vector2(200,200),["move_left","move_down"],true],[Vector2(-200,200),["move_right","move_down"],true]]:
			for dodge in [false,true]:
				release_inputs(); var host := Node2D.new(); root.add_child(host)
				var shots := Node2D.new(); host.add_child(shots)
				var player := PlayerScript.new(); player.position = route[0]; player.world_bounds = Rect2(-1000,-1000,2000,2000); host.add_child(player)
				var boss := Boss.new(); boss.world_bounds = player.world_bounds; boss.setup(6,shots,player); host.add_child(boss)
				var combat = boss.get_attack_director()
				combat.advance(1.4); boss._update_entrance_reveal(); combat.attack_gap = 99
				check(player.health.current_health==100 and player.shield==0 and player.move_speed==235 and is_equal_approx(player.get_body_radius(),16.9),"normal Player statistics modified")
				check(combat.start_action(&"probes") and boss.should_show_attack_marker(),"actual head warning cannot start")
				var landings: PackedVector2Array = combat.probe_landings.duplicate()
				var direction: Vector2 = combat.locked_direction
				var previous := player.global_position; var moves := 0; var input_started := false; var reaction := -1.0
				var seen := [false,false]; var samples := [0,0]
				var origins := PackedVector2Array([Vector2.INF,Vector2.INF])
				var deadline := Time.get_ticks_msec()+4000
				while combat.is_attacking() and Time.get_ticks_msec()<deadline:
					await physics_frame
					if dodge and not input_started and combat.action_stage==combat.Stage.WARNING and combat.action_elapsed>=0.15:
						reaction = combat.action_elapsed
						for input in route[1]: Input.action_press(input)
						input_started = true
					moves += 1 if player.global_position.distance_squared_to(previous)>0.01 else 0; previous = player.global_position
					check(combat.probe_landings==landings and combat.locked_direction==direction,"normal movement retargets pair")
					for index in range(2):
						if combat.probe_released[index] and not seen[index]:
							seen[index] = true; origins[index] = combat.probe_origins[index]
							if index==0 and route[2]:
								check(not combat.probes[index].armed and origins[index].distance_to(landings[index])>360,"overlong path not strictly rejected")
							else: check(combat.probes[index].armed and combat.probes[index].age==0,"birth already damages or invisible")
						if combat.probes[index].armed:
							samples[index] += 1
							check(combat.probes[index].origin==origins[index] and combat.probes[index].landing==landings[index],"normal recoil changes flight path")
				release_inputs(); adjacent_moves += moves
				var left_valid: bool = samples[0]==0 if route[2] else samples[0]>=3
				check(Time.get_ticks_msec()<deadline and seen==[true,true] and left_valid and samples[1]>=3 and not combat.probes[0].armed and not combat.probes[1].armed,"two finite releases/path rejection not completed")
				if dodge:
					check(player.health.current_health==100 and input_started and moves>=4 and reaction>=0.15 and reaction<=0.15+1.0/rate+0.00001,"delayed ordinary dodge fails %sHz/%s HP%s"%[rate,route[0],player.health.current_health])
				else: check(player.health.current_health==73 and moves==0,"stationary pair misses/repeats %sHz/%s HP%s"%[rate,route[0],player.health.current_health])
				check(player.scale==Vector2.ONE and not player.dash_active and not player.is_stealthed() and not player.player_collision.disabled,"dodge bypasses physical collision")
				print("OBSERVER NATURAL PROBES: %sHz at%s dodge%s reaction%s moves%s samples%s HP%s"%[rate,route[0],dodge,reaction,moves,samples,player.health.current_health])
				host.free(); await process_frame
	release_inputs(); Engine.physics_ticks_per_second = original_rate
	if not failures: print("TEST PASS: RiftObserverProbeDodgeTest %d; %d actual adjacent moves, 18 paired delayed dodges + 18 paired stationary hits, and 6+6 original long-diagonal range controls"%[checks,adjacent_moves])
	quit(1 if failures else 0)
func _initialize() -> void: call_deferred("run")
