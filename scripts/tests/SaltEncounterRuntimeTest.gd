extends SceneTree
## Automatic portals/AI/tides and normal input, not forced combat completion.
const Map = preload("res://scenes/world/salt_waterway.tscn")
const Player = preload("res://scripts/actors/Player.gd")
const Growth = preload("res://scripts/systems/UpgradeSystem.gd")
const Director = preload("res://scripts/systems/SaltEncounterDirector.gd")
const Crab = preload("res://scripts/actors/FlankingCrabEnemy.gd")
const EnemyBody = preload("res://scripts/actors/Enemy.gd")
var checks := 0
var failures := 0
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error("TEST FAIL: SaltEncounterRuntimeTest "+label)
func _initialize() -> void: call_deferred("run")
func observe_shot(shot: Node,observations: Dictionary) -> void:
	if not is_instance_valid(shot): return
	if shot.target_group==&"player" and shot.radius==3 and is_equal_approx(shot.velocity.length(),EnemyBody.ENEMY_PROJECTILE_BASE_SPEED*EnemyBody.MARKSMAN_PROJECTILE_SPEED_MULTIPLIER): observations.needles += 1
func choose_movement(player: Node2D,map: Node2D,director: Node,shots: Node2D,opening: bool,claw_seen: bool) -> Vector2:
	# Read world state and press only ordinary WASD. Let a crab approach after
	# the opening walk, then leave its locked warning instead of circling every
	# 280 wall-clock milliseconds in an increasingly crowded 65px square.
	var radius: float = player.get_body_radius()
	var at := player.global_position
	var actors: Array = director.get_active_enemies()
	var nearest_crab: Node2D = null; var nearest_distance := INF
	for enemy in actors:
		if enemy is Crab and enemy.global_position.distance_to(at)<nearest_distance:
			nearest_crab = enemy; nearest_distance = enemy.global_position.distance_to(at)
	var best := Vector2.ZERO; var best_score := -INF
	for index in range(-1,8):
		var direction := Vector2.ZERO if index<0 else Vector2.from_angle(TAU*index/8.0)
		var velocity: Vector2 = direction*player.get_effective_move_speed()
		var future: Vector2 = at+velocity*0.24
		var clear := true
		for fraction in [0.25,0.5,0.75,1.0]:
			if not map.layout.is_position_walkable(at.lerp(future,fraction),radius): clear = false; break
		if not clear: continue
		var score := 24.0 if direction.is_zero_approx() and not opening and not claw_seen else 0.0
		if opening: score += direction.dot(Vector2.RIGHT)*40
		if claw_seen and is_instance_valid(nearest_crab):
			score += future.distance_to(nearest_crab.global_position)-nearest_distance
		for enemy in actors:
			var expected: Vector2 = enemy.global_position+enemy.velocity*0.18
			if future.distance_to(expected)<radius+enemy.body_radius+6: score -= 1200
			if enemy is Crab and enemy.basic_attack.stage in [enemy.basic_attack.Stage.WARNING,enemy.basic_attack.Stage.ACTIVE]:
				var until_hit: float = maxf(0.02,enemy.basic_attack.get_warning_duration()-enemy.basic_attack.elapsed)
				if enemy.basic_attack.is_point_in_warning(enemy,at+velocity*until_hit): score -= 5000
		for shot in shots.get_children():
			if shot.is_queued_for_deletion() or shot.target_group!=&"player": continue
			var first: Vector2 = shot.global_position-at
			var last: Vector2 = first+(shot.velocity-velocity)*0.30
			if Geometry2D.get_closest_point_to_segment(Vector2.ZERO,first,last).length()<radius+shot.radius+7: score -= 4000
		for band in map.tidal_field.get_children():
			if band.state not in [band.State.WARNING,band.State.ACTIVE]: continue
			var local: Vector2 = band.to_local(future)
			if local.distance_to(local.clamp(band.footprint.position,band.footprint.end))<radius+5: score -= 3000
		if score>best_score: best = direction; best_score = score
	return best
func press_movement(direction: Vector2,actions: Array) -> void:
	for action in actions: Input.action_release(action)
	if direction.x>0.2: Input.action_press("move_right")
	elif direction.x< -0.2: Input.action_press("move_left")
	if direction.y>0.2: Input.action_press("move_down")
	elif direction.y< -0.2: Input.action_press("move_up")
func run() -> void:
	var actions := ["move_up","move_right","move_down","move_left"]
	for action in actions: Input.action_release(action)
	var host := Node2D.new(); host.process_mode = Node.PROCESS_MODE_PAUSABLE; root.add_child(host)
	var map = Map.instantiate(); map.map_seed = 521; host.add_child(map)
	var player := Player.new(); player.world_bounds = map.layout.world_bounds; host.add_child(player)
	var enemies := Node2D.new(); var shots := Node2D.new(); var portals := Node2D.new()
	for layer in [enemies,shots,portals]: host.add_child(layer)
	var growth := Growth.new(); host.add_child(growth); growth.setup(player)
	var director := Director.new(); host.add_child(director)
	await physics_frame; await process_frame
	check(director.bind_tidal_field(map.tidal_field) and director.start_run(521,player,enemies,shots,portals,growth,map.layout) and director.begin_encounter(),"automatic salt encounter starts")
	var observations := {"needles":0}
	shots.child_entered_tree.connect(func(shot): observe_shot.call_deferred(shot,observations))
	var moved := 0
	var claw_warning := false; var claw_active := false; var needle_warning := false; var tide_active := false
	var started := Time.get_ticks_msec(); var direction := Vector2.INF
	var first_physics_frame := Engine.get_physics_frames()
	var simulation_seconds := 0.0
	while Time.get_ticks_msec()-started<12000 and player.health.current_health>0:
		var next := choose_movement(player,map,director,shots,simulation_seconds<0.65,claw_warning)
		if not next.is_equal_approx(direction):
			press_movement(next,actions); direction = next
		var previous := player.position
		await physics_frame; await process_frame
		simulation_seconds = float(Engine.get_physics_frames()-first_physics_frame)/Engine.physics_ticks_per_second
		moved += 1 if player.position.distance_to(previous)>0.01 else 0
		for enemy in director.get_active_enemies():
			if enemy is Crab:
				claw_warning = claw_warning or enemy.basic_attack.stage==enemy.basic_attack.Stage.WARNING
				claw_active = claw_active or enemy.basic_attack.stage==enemy.basic_attack.Stage.ACTIVE
			else: needle_warning = needle_warning or enemy.ranged_is_winding_up
		tide_active = tide_active or map.tidal_field.get_children().any(func(band): return band.state==band.State.ACTIVE)
		if claw_active and needle_warning and observations.needles>0 and tide_active: break
	for action in actions: Input.action_release(action)
	check(moved>30,"normal movement stuck")
	check(claw_warning and claw_active,"real spawned crab never performs pincer")
	check(needle_warning and observations.needles>0,"real spawned needler never aims/emits fast shot")
	check(tide_active,"encounter-owned tide never activates")
	check(player.health.current_health>0 and director.state==director.State.COMBAT,"witness died or fabricated clear")
	check(not director.finish_reward() and not director.choose_route(&"supply"),"unfinished encounter grants reward")
	var actors := director.get_active_enemies().duplicate(); var positions: Array[Vector2] = []
	for enemy in actors: positions.append(enemy.position)
	var health: float = player.health.current_health+player.shield
	paused = true; await physics_frame; await physics_frame
	check(map.tidal_field.get_children().all(func(band): return band.state==band.State.INACTIVE),"paused encounter retains danger")
	await create_timer(0.12,true).timeout
	check(player.health.current_health+player.shield==health,"paused encounter damages player")
	for index in actors.size(): check(actors[index].position==positions[index],"paused salt enemy moves")
	paused = false; await physics_frame; await physics_frame
	check(map.tidal_field.get_children().filter(func(band): return band.enabled).all(func(band): return band.state==band.State.COOLDOWN and band.remaining>1.6),"resume lacks safe interval")
	var final_health: float = player.health.current_health
	host.free(); await process_frame
	print("SaltEncounterRuntimeTest actual_moves=%d needle_shots=%d elapsed_ms=%d simulation_seconds=%s hp=%s claw_warning=%s claw_active=%s tide_active=%s"%[moved,observations.needles,Time.get_ticks_msec()-started,simulation_seconds,final_health,claw_warning,claw_active,tide_active])
	if not failures: print("TEST PASS: SaltEncounterRuntimeTest %d"%checks)
	quit(1 if failures else 0)
