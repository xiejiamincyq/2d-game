extends SceneTree
## Real Player inputs and actual Boss physics clock. Entrance-only acceleration;
## no post-spawn position/velocity/health/shield/speed/collision/invulnerability edits.
const Boss = preload("res://scripts/actors/SaltTideBoss.gd")
const Player = preload("res://scripts/actors/Player.gd")
var checks := 0
var failures := 0
var adjacent_moves := 0
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("TEST FAIL: TideShellDodgeTest "+label)
func _initialize() -> void: call_deferred("run")
func release_inputs() -> void:
	for action in ["move_up","move_down","move_left","move_right","fire","dash_melee"]: Input.action_release(action)
func run() -> void:
	var original_rate := Engine.physics_ticks_per_second
	for rate in [30,60,120]:
		Engine.physics_ticks_per_second = rate
		for entry in [[&"ripple",Vector2(120,0),"move_left"],[&"ripple",Vector2(200,0),"move_right"],[&"pincer",Vector2(120,-28),"move_right"],[&"salt",Vector2(150,0),"move_down"]]:
			release_inputs()
			var action: StringName = entry[0]
			var host := Node2D.new(); root.add_child(host)
			var shots := Node2D.new(); host.add_child(shots)
			var player := Player.new(); player.position = entry[1]
			player.world_bounds = Rect2(-1000,-1000,2000,2000); host.add_child(player)
			var boss := Boss.new(); boss.world_bounds = player.world_bounds; boss.setup(3,shots,player); host.add_child(boss)
			var combat = boss.get_attack_director(); combat.advance(1.4); boss._update_entrance_reveal(); combat.attack_gap = 99
			var before: float = player.health.current_health+player.shield
			var losses := {"count":0}
			player.health_changed.connect(func(value,_max):
				if value<player.health.max_health: losses.count += 1)
			player.shield_changed.connect(func(value,_max):
				if value<player.max_shield: losses.count += 1)
			check(combat.start_action(action),"normal-input fixture cannot arm")
			var locked: Vector2 = combat.locked_direction
			Input.action_press(entry[2])
			var previous := player.position
			var moves := 0
			var deadline := Time.get_ticks_msec()+2500
			while (combat.action_stage not in [combat.Stage.RECOVERY,combat.Stage.IDLE] or (action==&"salt" and shots.get_child_count()>0)) and Time.get_ticks_msec()<deadline:
				await physics_frame
				if player.position.distance_squared_to(previous)>0.01: moves += 1
				previous = player.position
			release_inputs(); adjacent_moves += moves
			check(moves>=4 and Time.get_ticks_msec()<deadline,"clock/input did not finish")
			check(player.health.current_health+player.shield>=before and losses.count==0 and not combat.hit_delivered,"ordinary movement fails %s/%s/%s"%[rate,action,entry[2]])
			check(combat.locked_direction==locked,"attack retargets dodge")
			check(player.scale==Vector2.ONE and not player.dash_active and not player.is_stealthed() and not player.player_collision.disabled,"dodge bypasses physics")
			host.free(); await process_frame
	release_inputs(); Engine.physics_ticks_per_second = original_rate
	if not failures: print("TEST PASS: TideShellDodgeTest %d; %d ordinary-input adjacent moves; 12 isolated real-clock actions, no chapter victory" % [checks,adjacent_moves])
	quit(1 if failures else 0)
