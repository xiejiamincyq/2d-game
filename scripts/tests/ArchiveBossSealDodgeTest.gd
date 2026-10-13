extends SceneTree
## Actual Player input/physics; isolated seal, not a chapter victory or human playtest.
const Boss = preload("res://scripts/actors/ArchiveArchivistBoss.gd")
const Player = preload("res://scripts/actors/Player.gd")
var checks := 0
var failures := 0
var adjacent_moves := 0
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error("TEST FAIL: ArchiveBossSealDodgeTest "+label)
func _initialize() -> void: call_deferred("run")
func release_inputs() -> void:
	for action in ["move_up","move_down","move_left","move_right","fire","dash_melee"]: Input.action_release(action)
func run() -> void:
	var original_rate := Engine.physics_ticks_per_second
	for rate in [30,60,120]:
		Engine.physics_ticks_per_second = rate
		for route in [[Vector2(240,0),"move_right"],[Vector2(-240,0),"move_left"],[Vector2(0,240),"move_down"],[Vector2(0,-240),"move_up"]]:
			for dodge in [false,true]:
				release_inputs()
				var host := Node2D.new(); root.add_child(host)
				var shots := Node2D.new(); host.add_child(shots)
				var player := Player.new(); player.position = route[0]
				player.world_bounds = Rect2(-1000,-1000,2000,2000); host.add_child(player)
				var boss := Boss.new(); boss.world_bounds = player.world_bounds
				boss.setup(4,shots,player); host.add_child(boss)
				var combat = boss.get_attack_director()
				# Entrance acceleration only; no subsequent HP/speed/collision/invulnerability edits.
				combat.advance(1.4); boss._update_entrance_reveal(); combat.attack_gap = 99
				check(player.health.current_health==100 and player.shield==0 and is_equal_approx(player.player_collision.shape.radius,16.9),"real player defaults changed")
				check(combat.start_action(&"seal") and boss.should_show_attack_marker(),"real warning cannot arm")
				var centers: Array = combat.seal_attack.centers.duplicate()
				if dodge: Input.action_press(route[1])
				var previous := player.position
				var moves := 0
				var deadline := Time.get_ticks_msec()+2500
				while combat.action_stage not in [combat.Stage.RECOVERY,combat.Stage.IDLE] and Time.get_ticks_msec()<deadline:
					await physics_frame
					moves += 1 if player.position.distance_squared_to(previous)>0.01 else 0
					previous = player.position
					if not combat.seal_attack.centers.is_empty(): check(combat.seal_attack.centers==centers,"seal follows ordinary-input dodge")
				release_inputs(); adjacent_moves += moves
				check(Time.get_ticks_msec()<deadline and combat.seal_attack.centers.is_empty(),"real seal does not finish")
				if dodge: check(player.health.current_health==100 and moves>=4,"ordinary movement cannot escape %s/%s" % [rate,route[0]])
				else: check(player.health.current_health==82 and moves==0,"stationary counter-example never actually hit %s/%s" % [rate,route[0]])
				check(player.scale==Vector2.ONE and not player.dash_active and not player.is_stealthed() and not player.player_collision.disabled,"escape bypasses normal collision")
				host.free(); await process_frame
	release_inputs(); Engine.physics_ticks_per_second = original_rate
	if not failures: print("TEST PASS: ArchiveBossSealDodgeTest %d; %d actual adjacent moves, 12 normal-input dodges + 12 actual stationary hits" % [checks,adjacent_moves])
	quit(1 if failures else 0)
