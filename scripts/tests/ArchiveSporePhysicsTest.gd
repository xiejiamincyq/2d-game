extends SceneTree
## Real Player motion and real Projectile overlap. No post-spawn position/stat writes.
const Map = preload("res://scenes/world/luminous_archive.tscn")
const Player = preload("res://scripts/actors/Player.gd")
const Nest = preload("res://scripts/world/ArchiveSporeNest.gd")
const Shot = preload("res://scripts/components/Projectile.gd")
var checks := 0
var failures := 0
var adjacent_moves := 0
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error("TEST FAIL: ArchiveSporePhysicsTest "+label)
func _initialize() -> void: call_deferred("run")
func release() -> void:
	for action in ["move_left","move_right","move_up","move_down","fire","dash_melee"]: Input.action_release(action)
func tick() -> void: await physics_frame; await process_frame
func wait_for(predicate: Callable,seconds: float = 5.0) -> bool:
	var deadline := Time.get_ticks_msec()+int(seconds*1000)
	while not predicate.call() and Time.get_ticks_msec()<deadline: await tick()
	return predicate.call()
func run() -> void:
	var original_hz := Engine.physics_ticks_per_second
	for case in [{"hz":30,"seed":0},{"hz":60,"seed":521},{"hz":120,"seed":20261011}]:
		Engine.physics_ticks_per_second = case.hz
		var host := Node2D.new(); root.add_child(host)
		var map = Map.instantiate(); map.map_seed = case.seed; host.add_child(map)
		var field = map.spore_field; var nest = field.get_child(0)
		var player := Player.new(); player.position = nest.position; player.world_bounds = map.layout.world_bounds; host.add_child(player)
		release(); await tick(); await tick(); field.bind_player(player); field.set_active(true,1)
		var before: float = player.health.current_health+player.shield
		check(await wait_for(func(): return nest.state==Nest.State.WARNING),"natural warning clock %sHz"%case.hz)
		check(player.health.current_health+player.shield==before,"warning damages real Player")
		for _frame in ceili(case.hz*0.15): await tick()
		Input.action_press("move_right")
		var previous := adjacent_moves
		var observed_health := before
		for _frame in ceili(case.hz*0.38):
			var at := player.global_position; await tick()
			if player.health.current_health+player.shield<observed_health:
				print("ESCAPE DAMAGE: hz=%s frame=%s offset=%s remaining=%s radius=%s speed=%s"%[case.hz,_frame,player.position-nest.position,nest.remaining,player.get_body_radius(),player.velocity])
				observed_health = player.health.current_health+player.shield
			adjacent_moves += 1 if player.global_position.distance_to(at)>0.01 else 0
			check(map.layout.is_position_walkable(player.position,player.get_body_radius()),"normal escape embeds Player")
		release()
		check(adjacent_moves>previous+2 and player.position.distance_to(nest.position)>Nest.RADIUS+player.get_body_radius(),"real body never escaped")
		check(player.health.current_health+player.shield==before,"0.15s reaction cannot escape %sHz"%case.hz)
		check(is_equal_approx(player.move_speed,235) and not player.is_stealthed(),"escape bypasses normal speed/collision")
		field.set_active(false); host.free(); await process_frame
	Engine.physics_ticks_per_second = 60
	var host := Node2D.new(); root.add_child(host)
	var map = Map.instantiate(); map.map_seed = 521; host.add_child(map)
	var field = map.spore_field; var nest = field.get_child(0)
	var player := Player.new(); player.position = nest.position; host.add_child(player)
	await tick(); await tick(); field.bind_player(player); field.set_active(true,1)
	var before: float = player.health.current_health+player.shield
	check(await wait_for(func(): return nest.state==Nest.State.ACTIVE),"stationary real Player receives pulse")
	check(is_equal_approx(before-player.health.current_health-player.shield,18),"actual Player damage differs from18")
	var damaged: float = player.health.current_health+player.shield
	for _frame in 20: await tick()
	check(player.health.current_health+player.shield==damaged,"single emission repeats damage")
	paused = true; await tick(); await tick()
	check(nest.state==Nest.State.INACTIVE and not nest.is_in_group(&"enemies"),"pause leaves harmful/targetable nest")
	paused = false; await tick(); await tick()
	check(nest.state==Nest.State.COOLDOWN and nest.remaining>3.1,"resume lacks full safe cooldown")
	player.begin_entrance(); await tick(); await tick()
	check(nest.state==Nest.State.INACTIVE,"actual entrance leaves danger")
	check(await wait_for(func(): return not player.is_entrance_active()),"actual entrance never ends")
	await tick(); await tick(); check(nest.state==Nest.State.COOLDOWN and nest.remaining>3.1,"entrance restart unsafe")
	# Real Area2D projectile travels into target collider; no direct take_damage call.
	var shot := Shot.new(); shot.position = nest.position-Vector2(80,0); shot.velocity = Vector2(420,0); shot.damage = 36
	host.add_child(shot)
	check(await wait_for(func(): return nest.destroyed,1),"real friendly Projectile fails to break nest")
	check(nest.health.current_health==0 and not nest.is_in_group(&"enemies") and nest.collision_layer==0,"broken collision/target group remains")
	field.set_active(true,1); await tick()
	check(nest.destroyed,"repeated field update revives shot target")
	check(not player.has_signal("enemy_died") and not nest.has_signal("died"),"environment implements enemy reward signal")
	# Walk directly across broken physical area with ordinary inputs.
	Input.action_press("move_right"); var previous := adjacent_moves
	for _frame in 20:
		var at := player.position; await tick(); adjacent_moves += 1 if player.position.distance_to(at)>0.01 else 0
	release(); check(adjacent_moves>previous+15,"nest collider blocks movement")
	field.set_active(false); host.free(); await process_frame
	Engine.physics_ticks_per_second = original_hz; release()
	if not failures: print("TEST PASS: ArchiveSporePhysicsTest %d; %d actual adjacent moves"%[checks,adjacent_moves])
	quit(1 if failures else 0)
