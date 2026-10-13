extends SceneTree
## Actual Boss clock and ordinary movement inputs, isolated one-action fixture.
## Entrance is accelerated before each action; not a normal-input chapter victory.
const Boss = preload("res://scripts/actors/FoundryFurnaceBoss.gd")
const Player = preload("res://scripts/actors/Player.gd")
var checks := 0
var failures := 0
var adjacent_moves := 0
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error("TEST FAIL: FurnaceForemanDodgeTest "+label)
func _initialize() -> void: call_deferred("run")
func release_inputs() -> void:
	for action in ["move_up","move_down","move_left","move_right","fire","dash_melee"]: Input.action_release(action)
func run() -> void:
	var original_hz := Engine.physics_ticks_per_second
	for hz in [30,60,120]:
		Engine.physics_ticks_per_second = hz
		for kind in [&"jet",&"ram",&"vents"]:
			release_inputs()
			var host := Node2D.new(); root.add_child(host)
			var shots := Node2D.new(); host.add_child(shots)
			var player := Player.new(); player.position = Vector2(150,0)
			player.world_bounds = Rect2(-1000,-1000,2000,2000); host.add_child(player)
			var boss := Boss.new(); boss.world_bounds = player.world_bounds
			boss.setup(2,shots,player); host.add_child(boss)
			var combat = boss.get_attack_director()
			combat.advance(1.4); boss._update_entrance_reveal(); combat.attack_gap = 99
			var before: float = player.health.current_health+player.shield
			check(combat.start_action(kind),"ordinary dodge fixture cannot arm %s/%s"%[hz,kind])
			var locked_direction: Vector2 = combat.locked_direction
			var sites: Array = combat.vent_centers.duplicate()
			Input.action_press("move_left" if kind==&"vents" else "move_down")
			var previous := player.position; var moves := 0
			var end := Time.get_ticks_msec()+2500
			while combat.action_stage!=combat.Stage.RECOVERY and Time.get_ticks_msec()<end:
				await physics_frame
				if player.position.distance_squared_to(previous)>0.01: moves += 1
				previous = player.position
			release_inputs(); adjacent_moves += moves
			check(combat.action_stage==combat.Stage.RECOVERY and moves>=4,"actual clock/input did not run %s/%s"%[hz,kind])
			check(player.health.current_health+player.shield>=before and not combat.hit_delivered,"ordinary movement cannot avoid short warning %s/%s"%[hz,kind])
			check(combat.locked_direction==locked_direction and (kind!=&"vents" or combat.vent_centers==sites),"hazard tracks dodge %s/%s"%[hz,kind])
			check(player.scale==Vector2.ONE and not player.dash_active and not player.is_stealthed() and not player.player_collision.disabled,"dodge bypasses physical rules")
			host.free(); await process_frame
	release_inputs(); Engine.physics_ticks_per_second = original_hz
	if not failures: print("TEST PASS: FurnaceForemanDodgeTest %d; %d ordinary-input adjacent moves; 9 isolated actual-clock actions, no chapter victory"%[checks,adjacent_moves])
	quit(1 if failures else 0)
