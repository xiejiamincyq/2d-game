extends SceneTree
## Real normal movement with 0.15s reaction; no position/stat writes after spawn.
const Map = preload("res://scenes/world/salt_waterway.tscn")
const Player = preload("res://scripts/actors/Player.gd")
const Band = preload("res://scripts/world/SaltTidalBand.gd")
var checks := 0
var failures := 0
var adjacent_moves := 0
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error("TEST FAIL: SaltTidalPhysicsTest "+label)
func _initialize() -> void: call_deferred("run")
func release() -> void:
	for action in ["move_left","move_right","move_up","move_down","fire","dash_melee"]: Input.action_release(action)
func tick() -> void: await physics_frame; await process_frame
func wait_for(predicate: Callable,seconds: float = 3.5) -> bool:
	var deadline := Time.get_ticks_msec()+int(seconds*1000)
	while not predicate.call() and Time.get_ticks_msec()<deadline: await tick()
	return predicate.call()
func run() -> void:
	var original_hz := Engine.physics_ticks_per_second
	for case in [{"hz":30,"seed":0},{"hz":60,"seed":521},{"hz":120,"seed":20261011}]:
		Engine.physics_ticks_per_second = case.hz
		var host := Node2D.new(); root.add_child(host)
		var map = Map.instantiate(); map.map_seed = case.seed; host.add_child(map)
		var field = map.tidal_field
		var area: Rect2 = field.get_sites()[0]
		var player := Player.new(); player.world_bounds = map.layout.world_bounds
		player.position = area.get_center(); host.add_child(player)
		release(); await tick(); await tick()
		field.bind_player(player); field.set_active(true,1)
		var band = field.get_child(0)
		var before: float = player.health.current_health+player.shield
		check(await wait_for(func(): return band.state==Band.State.WARNING),"normal clock warning at %sHz"%case.hz)
		check(player.health.current_health+player.shield==before,"warning damaged real player")
		for _frame in ceili(case.hz*0.15): await tick()
		var action := "move_right" if area.size.x<area.size.y else "move_down"
		Input.action_press(action)
		var previous := adjacent_moves
		for _frame in ceili(case.hz*0.38):
			var position_before := player.global_position
			await tick()
			adjacent_moves += 1 if player.global_position.distance_to(position_before)>0.01 else 0
			check(map.layout.is_position_walkable(player.global_position,12.5),"escape embeds player in water")
		release()
		check(adjacent_moves>previous+2,"normal movement did not displace player")
		check(player.health.current_health+player.shield==before,"0.15s reaction escape too short at %sHz; position %s remaining %s"%[case.hz,player.position,band.remaining])
		check(not area.grow(13).has_point(player.position),"body still inside danger")
		check(is_equal_approx(player.move_speed,235) and not player.is_stealthed(),"test bypassed normal speed/collision")
		field.set_active(false)
		host.free(); await process_frame
	# Actual damage, pause, entrance and death; these are lifecycle fixtures.
	var host := Node2D.new(); root.add_child(host)
	var map = Map.instantiate(); map.map_seed = 521; host.add_child(map)
	var field = map.tidal_field
	var area: Rect2 = field.get_sites()[0]
	var player := Player.new(); player.world_bounds = map.layout.world_bounds
	player.position = area.get_center(); host.add_child(player)
	release(); await tick(); await tick()
	field.bind_player(player); field.set_active(true,1)
	var band = field.get_child(0)
	var before: float = player.health.current_health+player.shield
	check(await wait_for(func(): return band.state==Band.State.ACTIVE),"real hazard reaches active")
	check(is_equal_approx(before-player.health.current_health-player.shield,18),"real Player take_damage path")
	var damaged: float = player.health.current_health+player.shield
	paused = true; await tick(); await tick()
	check(band.state==Band.State.INACTIVE,"paused tree leaves visible danger")
	await create_timer(0.1,true).timeout
	check(player.health.current_health+player.shield==damaged,"pause damages player")
	paused = false; await tick(); await tick()
	check(band.state==Band.State.COOLDOWN and band.remaining>1.6,"resume without safe interval")
	field.set_active(false); player.begin_entrance(); field.set_active(true,1)
	await tick(); await tick()
	check(band.state==Band.State.INACTIVE,"real entrance does not suppress tide")
	check(await wait_for(func(): return not player.is_entrance_active()),"actual entrance never ends")
	await tick(); await tick()
	check(band.state==Band.State.COOLDOWN and band.remaining>1.6,"entrance restore unsafe")
	player.health.damage(player.health.current_health,true)
	check(not field.active and field.get_children().all(func(child): return not child.enabled),"real death not synchronous")
	host.free(); await process_frame
	# A new, real 2px wall through an otherwise legal strip disarms it entirely.
	host = Node2D.new(); root.add_child(host)
	map = Map.instantiate(); map.map_seed = 521; host.add_child(map)
	field = map.tidal_field; area = field.get_sites()[0]
	player = Player.new(); player.position = area.get_center(); host.add_child(player)
	var wall := StaticBody2D.new(); wall.position = area.get_center()
	var collider := CollisionShape2D.new(); var shape := RectangleShape2D.new()
	shape.size = Vector2(2,60); collider.shape = shape; wall.add_child(collider); host.add_child(wall)
	await tick(); await tick()
	field.bind_player(player); field.set_active(true,1); band = field.get_child(0)
	check(not band.enabled,"physical thin wall not in descriptors permits through-wall tide")
	wall.free(); await tick(); await tick()
	field.set_active(true,1)
	check(band.enabled and band.state==Band.State.COOLDOWN,"removed wall did not permit fresh safe arming")
	map.remove_child(field)
	check(not field.active and field.get_children().all(func(child): return not child.enabled),"owner field detach leaves damage")
	field.free(); host.free(); await process_frame
	Engine.physics_ticks_per_second = original_hz; release()
	if not failures: print("TEST PASS: SaltTidalPhysicsTest %d; %d actual adjacent moves"%[checks,adjacent_moves])
	quit(1 if failures else 0)
