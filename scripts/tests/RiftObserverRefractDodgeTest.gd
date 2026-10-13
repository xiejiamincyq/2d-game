extends SceneTree
## Actual physics, normal Player input and delayed reaction; no in-attack teleport.
const Boss = preload("res://scripts/actors/RiftObserverBoss.gd")
const PlayerScript = preload("res://scripts/actors/Player.gd")
var checks := 0
var failures := 0
var adjacent_moves := 0
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error("TEST FAIL: RiftObserverRefractDodgeTest "+label)
func release_inputs() -> void:
	for action in ["move_up","move_down","move_left","move_right","fire","dash_melee"]: Input.action_release(action)
func run() -> void:
	var original_rate := Engine.physics_ticks_per_second
	for rate in [30,60,120]:
		Engine.physics_ticks_per_second = rate
		for route in [
			[Vector2(240,0),["move_down"]],[Vector2(-240,0),["move_down"]],
			# The downward fan's right edge crosses the earlier rightward route.
			# Escape toward its left gap, with the stricter current reaction delay.
			[Vector2(0,240),["move_left"]],[Vector2(0,-240),["move_right"]],
			[Vector2(160,160),["move_left","move_down"]],[Vector2(-160,160),["move_right","move_down"]]]:
			for dodge in [false,true]:
				release_inputs(); var host := Node2D.new(); root.add_child(host)
				var shots := Node2D.new(); host.add_child(shots)
				var player := PlayerScript.new(); player.position = route[0]; player.world_bounds = Rect2(-1000,-1000,2000,2000); host.add_child(player)
				var boss := Boss.new(); boss.world_bounds = player.world_bounds; boss.setup(6,shots,player); host.add_child(boss)
				var combat = boss.get_attack_director(); combat.advance(1.4); boss._update_entrance_reveal(); combat.attack_gap = 99
				check(player.health.current_health==100 and player.shield==0 and player.move_speed==235 and is_equal_approx(player.get_body_radius(),16.9),"normal Player statistics modified")
				check(combat.start_action(&"refract") and boss.should_show_attack_marker(),"actual short head warning cannot start")
				var direction: Vector2 = combat.locked_direction; var distance: float = combat.refract.path_length
				var previous := player.global_position; var moves := 0; var input_started := false; var reaction := -1.0
				var seen := [false,false,false]; var samples := [0,0,0]; var origins := PackedVector2Array([Vector2.INF,Vector2.INF,Vector2.INF])
				var deadline := Time.get_ticks_msec()+4000
				while combat.is_attacking() and Time.get_ticks_msec()<deadline:
					await physics_frame
					if dodge and not input_started and combat.action_stage==combat.Stage.WARNING and combat.action_elapsed>=0.25:
						reaction = combat.action_elapsed
						for input in route[1]: Input.action_press(input)
						input_started = true
					moves += 1 if player.global_position.distance_squared_to(previous)>0.01 else 0; previous = player.global_position
					check(combat.locked_direction==direction and combat.refract.path_length==distance,"normal movement tracks target or stretches rays")
					for batch in range(3):
						if combat.refract.released[batch] and not seen[batch]:
							seen[batch] = true; origins[batch] = combat.refract.origins[batch]
							for offset in range(3):
								var fragment: RefCounted = combat.refract.fragments[batch*3+offset]
								check(fragment.armed and fragment.age==0 and fragment.origin==origins[batch],"birth is blocked, fake or retroactive")
						if combat.refract.fragments[batch*3].armed:
							samples[batch] += 1
							for offset in range(3):
								var fragment: RefCounted = combat.refract.fragments[batch*3+offset]
								check(fragment.origin==origins[batch] and fragment.landing.is_equal_approx(origins[batch]+direction.rotated(combat.refract.ANGLES[batch][offset])*distance),"flight reanchors after normal movement")
				release_inputs(); adjacent_moves += moves
				check(Time.get_ticks_msec()<deadline and seen==[true,true,true] and samples[0]>=2 and samples[1]>=2 and samples[2]>=2,"three actual finite batches incomplete")
				for fragment in combat.refract.fragments: check(not fragment.armed,"closing leaves residual damage geometry")
				if dodge:
					check(player.health.current_health==100 and input_started and moves>=4 and reaction>=0.25 and reaction<=0.25+1.0/rate+0.00001,"delayed ordinary dodge fails %sHz/%s HP%s"%[rate,route[0],player.health.current_health])
				else: check(player.health.current_health==76 and moves==0,"stationary counter-hit misses/repeats %sHz/%s HP%s"%[rate,route[0],player.health.current_health])
				check(player.scale==Vector2.ONE and not player.dash_active and not player.is_stealthed() and not player.player_collision.disabled,"dodge bypasses physical collision")
				print("OBSERVER NATURAL REFRACT: %sHz at%s dodge%s reaction%s moves%s samples%s HP%s"%[rate,route[0],dodge,reaction,moves,samples,player.health.current_health])
				host.free(); await process_frame
	release_inputs(); Engine.physics_ticks_per_second = original_rate
	if not failures: print("TEST PASS: RiftObserverRefractDodgeTest %d; %d actual adjacent moves, 18 ordinary delayed dodges + 18 stationary hits"%[checks,adjacent_moves])
	quit(1 if failures else 0)
func _initialize() -> void: call_deferred("run")
