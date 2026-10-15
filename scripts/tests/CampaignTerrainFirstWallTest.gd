extends SceneTree
## Geometry-first normal physics flight: six real maps, constructed high speeds,
## both affiliations/pierce budgets and 30/60/120Hz. No artificial large delta.
const Definitions = preload("res://scripts/campaign/ChapterRunDefinitions.gd")
const Player = preload("res://scripts/actors/Player.gd")
const EnemyActor = preload("res://scripts/actors/Enemy.gd")
const Wall = preload("res://scripts/world/DestructibleObstacle.gd")
const StepTrap = preload("res://scripts/world/ReusableStepTrap.gd")
const Capsule = preload("res://scripts/components/CapsulePlantHazard.gd")

class FlightProbe extends "res://scripts/components/Projectile.gd":
	var flight_trace: Array[Dictionary] = []
	func _physics_process(delta: float) -> void:
		# Passive tracing only. The actual engine supplies delta; all movement and
		# collision/damage remain in production super, with no manual clock call.
		var entry := {"delta":delta,"before":global_position,"intent":velocity*delta}
		super._physics_process(delta)
		entry.after = global_position
		flight_trace.append(entry)

class FlightProbeShard extends "res://scripts/components/RiftShardProjectile.gd":
	var flight_trace: Array[Dictionary] = []
	func _physics_process(delta: float) -> void:
		var entry := {"delta":delta,"before":global_position,"intent":velocity*delta}
		super._physics_process(delta)
		entry.after = global_position
		flight_trace.append(entry)

var checks := 0
var failures := 0
var cases := 0
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("TEST FAIL: CampaignTerrainFirstWallTest "+label)
func _initialize() -> void: call_deferred("run")

func use_physics_rate(hz: int) -> void:
	Engine.physics_ticks_per_second = hz
	# A rate write inside a render frame does not replace physics ticks already
	# scheduled for that frame. Cross completed render/physics boundaries before
	# admitting a case whose first actual delta is asserted below.
	for _step in 3: await process_frame; await physics_frame; await process_frame

func find_safe_wall(map: Node2D) -> Dictionary:
	for body in map.layout.get_children():
		if not body is StaticBody2D or not body.has_method("take_damage"): continue
		var rect: Rect2 = body.get_damage_rect()
		var axis := Vector2.RIGHT if rect.size.x<=rect.size.y else Vector2.DOWN
		var thickness := minf(rect.size.x,rect.size.y)
		var start := rect.get_center()-axis*(thickness/2+20)
		var end := rect.get_center()+axis*(thickness/2+20)
		if not map.layout.is_position_walkable(start,4) or not map.layout.is_position_walkable(end,Player.BODY_RADIUS): continue
		var ray := PhysicsRayQueryParameters2D.create(start,end,1)
		var hit := map.get_world_2d().direct_space_state.intersect_ray(ray)
		if hit.is_empty() or hit.collider!=body: continue
		return {"body":body,"rect":rect,"axis":axis,"thickness":thickness,"start":start,"end":end}
	return {}

func receiver(host: Node2D,at: Vector2,group: StringName) -> CharacterBody2D:
	var actor: CharacterBody2D
	if group==&"player":
		actor = Player.new()
	else:
		actor = EnemyActor.new(); actor.setup(EnemyActor.EnemyKind.SCRAPPER,0,host)
	actor.position = at; host.add_child(actor); actor.set_physics_process(false)
	return actor

func observe_flight(host: Node2D,shot: Projectile) -> Array[Dictionary]:
	var trace: Array[Dictionary] = shot.flight_trace
	host.add_child(shot)
	for _step in 8:
		await physics_frame; await process_frame
		if not is_instance_valid(shot) or shot.is_queued_for_deletion(): break
	await process_frame
	return trace

func map_case(host: Node2D,map: Node2D,wall: Dictionary,hz: int,group: StringName,pierce: int,chapter: int) -> void:
	var label := "chapter%d/%dHz/%s/pierce%d "%[chapter,hz,group,pierce]
	var target := receiver(host,wall.end,group)
	await physics_frame; await physics_frame
	var body = wall.body
	var wall_before: float = body.health.current_health
	var target_before: float = target.health.current_health
	var shot := FlightProbe.new(); shot.damage = 9; shot.target_group = group; shot.pierce = pierce
	shot.position = wall.start; shot.world_bounds = map.layout.world_bounds
	# Deliberately not the game's default bullet speed: one actual fixed physics
	# tick intends to cross the complete real wall +20px clearance on each side.
	shot.velocity = wall.axis*(wall.thickness+40)*hz
	var trace := await observe_flight(host,shot)
	check(not trace.is_empty() and is_equal_approx(trace[0].delta,1.0/hz) and trace[0].intent.length()>wall.thickness+8,label+"constructed normal-physics full-wall step positive control missing")
	check(body.health.current_health==wall_before-9,label+"geometric first wall did not receive original 9 damage exactly once")
	check(target.health.current_health==target_before,label+"actual target behind the first wall received damage")
	check(not is_instance_valid(shot) or shot.is_queued_for_deletion(),label+"terrain failed to stop shot independently of enemy pierce budget")
	check(not trace.is_empty() and (trace.back().after-wall.rect.get_center()).dot(wall.axis)<=-wall.thickness/2+0.2,label+"projectile center crossed the first wall entry face")
	cases += 1
	if is_instance_valid(shot): shot.queue_free()
	target.queue_free(); await process_frame; await process_frame

func test_six_maps() -> void:
	for chapter in range(1,7):
		var host := Node2D.new(); root.add_child(host)
		var definition: Dictionary = Definitions.get_definition(chapter)
		var map = definition.map.instantiate(); map.map_seed = 521; host.add_child(map)
		await physics_frame; await physics_frame
		var wall := find_safe_wall(map)
		check(not wall.is_empty(),"chapter%d lacks a safe actual first-wall/behind-target lane"%chapter)
		if not wall.is_empty():
			for hz in [30,60,120]:
				await use_physics_rate(hz)
				for group in [&"enemies",&"player"]:
					for pierce in [0,1]: await map_case(host,map,wall,hz,group,pierce,chapter)
		host.free(); await process_frame; await process_frame

func thin_wall(host: Node2D) -> StaticBody2D:
	var wall := Wall.new(); wall.collision_layer = 3; wall.collision_mask = 0
	wall.set_layout_footprint(Rect2(-1,-60,2,120))
	var collider := CollisionShape2D.new(); collider.name = "CollisionShape2D"
	var shape := RectangleShape2D.new(); shape.size = Vector2(2,120)
	collider.shape = shape; wall.add_child(collider); host.add_child(wall)
	return wall

func test_thin_wall_fairness() -> void:
	await use_physics_rate(60)
	for direction in [Vector2.RIGHT,Vector2.LEFT]:
		for pierce in [0,1]:
			var host := Node2D.new(); root.add_child(host)
			var wall = thin_wall(host)
			var target := receiver(host,direction*(Player.BODY_RADIUS+2),&"player")
			await physics_frame; await physics_frame
			var label := "2px-wall/60Hz/360speed/%s/pierce%d "%[direction,pierce]
			check(absf(target.global_position.x)-Player.BODY_RADIUS>1,label+"real Player overlaps the wall")
			var before: float = wall.health.current_health
			var shot := FlightProbe.new(); shot.damage = 9; shot.target_group = &"player"; shot.pierce = pierce
			shot.position = -direction*7.5; shot.velocity = direction*360
			var trace := await observe_flight(host,shot)
			check(not trace.is_empty() and is_equal_approx(trace[0].intent.length(),6),label+"standard-speed actual 6px-step positive control missing")
			check(wall.health.current_health==before-9 and target.health.current_health==100,label+"unordered Area overlaps chose the rear Player instead of geometric first wall")
			check(not is_instance_valid(shot) or shot.is_queued_for_deletion(),label+"pierce continued through solid first wall")
			check(not trace.is_empty() and trace.back().after.dot(direction)<=-1+0.2,label+"center crossed the first wall entry face before retirement")
			cases += 1
			host.free(); await process_frame; await process_frame

func test_legal_flight_segment() -> void:
	await use_physics_rate(60)
	for kind in ["base","rift-shard"]:
		var modes := ["short-lifetime","world-boundary"]
		if kind=="rift-shard": modes.append_array(["expired-birth","out-of-world-birth"])
		for mode in modes:
			var host := Node2D.new(); root.add_child(host)
			var wall = thin_wall(host); await physics_frame; await physics_frame
			var before: float = wall.health.current_health
			var shot = FlightProbe.new() if kind=="base" else FlightProbeShard.new()
			if kind=="base": shot.damage = 9 # RiftShard retains its original 12.
			shot.position = Vector2(-20,0); shot.velocity = Vector2(1800,0)
			# Controlled legal configurations, not default lifetime/bounds/speed.
			# The unconstrained actual tick crosses this wall, but its legal segment
			# ends before the wall (or does not exist for an invalid birth).
			match mode:
				"short-lifetime": shot.lifetime = 0.003
				"world-boundary": shot.world_bounds = Rect2(-100,-100,90,200)
				"expired-birth": shot.lifetime = 0
				"out-of-world-birth": shot.world_bounds = Rect2(-15,-100,10,200)
			var label: String = kind+"/"+mode
			var trace := await observe_flight(host,shot)
			check(not trace.is_empty() and is_equal_approx(trace[0].delta,1.0/60) and is_equal_approx(trace[0].intent.x,30),label+" actual crossing-intent positive control missing")
			check(wall.health.current_health==before,label+" swept expired or out-of-world segment and damaged unreachable wall")
			check(not is_instance_valid(shot) or shot.is_queued_for_deletion(),label+" projectile survived expired/outside legal flight")
			cases += 1; host.free(); await process_frame; await process_frame

func test_nearer_target_before_wall() -> void:
	await use_physics_rate(60)
	for group in [&"enemies",&"player"]:
		for pierce in [0,1]:
			var host := Node2D.new(); root.add_child(host)
			var wall = thin_wall(host)
			var front := receiver(host,Vector2(-40,0),group)
			var rear := receiver(host,Vector2(40,0),group)
			await physics_frame; await physics_frame
			var target_radius: float = front.get_body_radius() if group==&"player" else front.body_radius
			var label := "nearer-%s-before-wall/60Hz/pierce%d "%[group,pierce]
			check(front.global_position.x+target_radius<-1 and rear.global_position.x-target_radius>1,label+"real front/rear target overlaps wall")
			var front_before: float = front.health.current_health
			var rear_before: float = rear.health.current_health
			var wall_before: float = wall.health.current_health
			var shot := FlightProbe.new(); shot.damage = 9; shot.target_group = group; shot.pierce = pierce
			shot.position = Vector2(-100,0); shot.velocity = Vector2(7200,0)
			# Actual normal 60Hz engine tick intends 120px: front body first, then
			# solid wall, then the rear body's expanded entry at the intended endpoint.
			var trace := await observe_flight(host,shot)
			check(not trace.is_empty() and is_equal_approx(trace[0].delta,1.0/60) and is_equal_approx(trace[0].intent.x,120),label+"normal engine 120px-step positive control missing")
			check(front.health.current_health==front_before-9,label+"terrain-only sweep skipped nearer actual target")
			var expected_wall_loss := 0 if pierce==0 else 9
			check(wall.health.current_health==wall_before-expected_wall_loss,label+"wall damage ignored geometrically earlier target/pierce budget")
			check(rear.health.current_health==rear_before,label+"shot damaged real target behind solid wall")
			check(not is_instance_valid(shot) or shot.is_queued_for_deletion(),label+"legal first-contact/pierce sequence did not retire shot")
			var stop_face: float = front.global_position.x-target_radius if pierce==0 else -1.0
			check(not trace.is_empty() and trace.back().after.x<=stop_face+0.2,label+"projectile moved past the impact that exhausted its flight")
			cases += 1; host.free(); await process_frame; await process_frame

func test_two_ordered_enemies_before_wall() -> void:
	await use_physics_rate(60)
	for pierce in [1,2]:
		var host := Node2D.new(); root.add_child(host)
		var wall = thin_wall(host)
		var first := receiver(host,Vector2(-100,0),&"enemies")
		var second := receiver(host,Vector2(-45,0),&"enemies")
		var rear := receiver(host,Vector2(40,0),&"enemies")
		await physics_frame; await physics_frame
		var label := "two-real-enemies/60Hz/pierce%d "%pierce
		check(first.global_position.distance_to(second.global_position)>first.body_radius+second.body_radius and second.global_position.x+second.body_radius<-1 and rear.global_position.x-rear.body_radius>1,label+"real targets overlap each other or wall")
		var first_before: float = first.health.current_health
		var second_before: float = second.health.current_health
		var rear_before: float = rear.health.current_health
		var wall_before: float = wall.health.current_health
		var order: Array[StringName] = []
		first.damage_resolved.connect(func(_actor,_source,_amount,_at,_direction,_killed): order.append(&"first"))
		second.damage_resolved.connect(func(_actor,_source,_amount,_at,_direction,_killed): order.append(&"second"))
		var shot := FlightProbe.new(); shot.damage = 9; shot.target_group = &"enemies"; shot.pierce = pierce
		shot.position = Vector2(-150,0); shot.velocity = Vector2(12000,0)
		var trace := await observe_flight(host,shot)
		check(not trace.is_empty() and is_equal_approx(trace[0].delta,1.0/60) and is_equal_approx(trace[0].intent.x,200),label+"normal engine 200px-step positive control missing")
		check(order.size()==2 and order[0]==&"first" and order[1]==&"second",label+"real enemy damage signals did not follow near-to-far geometric order")
		check(first.health.current_health==first_before-9 and second.health.current_health==second_before-9,label+"each earlier actual enemy did not receive exactly 9")
		var wall_loss := 0 if pierce==1 else 9
		check(wall.health.current_health==wall_before-wall_loss,label+"wall ignored preceding two-target pierce budget")
		check(rear.health.current_health==rear_before,label+"rear actual enemy was hit beyond solid wall")
		check(not is_instance_valid(shot) or shot.is_queued_for_deletion(),label+"two-enemy/wall sequence did not retire shot")
		var stop_face: float = second.global_position.x-second.body_radius if pierce==1 else -1.0
		check(not trace.is_empty() and trace.back().after.x<=stop_face+0.2,label+"shot flew beyond the impact that exhausted flight")
		cases += 1; host.free(); await process_frame; await process_frame

func test_actual_areas_before_wall() -> void:
	await use_physics_rate(60)
	for kind in ["step-trap","capsule"]:
		for pierce in [0,1]:
			var host := Node2D.new(); root.add_child(host)
			var wall = thin_wall(host)
			var area = StepTrap.new() if kind=="step-trap" else Capsule.new()
			area.position = Vector2(-40,0); host.add_child(area)
			# Only isolate the mechanism/incubation clock. Its real physics Area,
			# collision circle, membership, Health and damage method stay unchanged.
			area.set_physics_process(false)
			var rear := receiver(host,Vector2(40,0),&"enemies")
			await physics_frame; await physics_frame
			var label := "real-%s-Area/60Hz/pierce%d "%[kind,pierce]
			check(area.global_position.x+area.body_radius<-1 and rear.global_position.x-rear.body_radius>1,label+"real Area/rear target overlaps solid wall")
			check(area is Area2D and area.monitorable and area.health.current_health>9 and (area.is_in_group(&"enemies") or area.is_in_group(&"destructible_terrain")),label+"actual destructible Area prerequisite missing")
			var area_before: float = area.health.current_health
			var rear_before: float = rear.health.current_health
			var wall_before: float = wall.health.current_health
			var shot := FlightProbe.new(); shot.damage = 9; shot.target_group = &"enemies"; shot.pierce = pierce
			shot.position = Vector2(-100,0); shot.velocity = Vector2(7200,0)
			var trace := await observe_flight(host,shot)
			check(not trace.is_empty() and is_equal_approx(trace[0].delta,1.0/60) and is_equal_approx(trace[0].intent.x,120),label+"normal engine 120px-step positive control missing")
			check(area.health.current_health==area_before-9,label+"front actual Area did not receive exactly 9")
			var wall_loss := 0 if pierce==0 else 9
			check(wall.health.current_health==wall_before-wall_loss,label+"Area/wall geometric sequence ignored pierce budget")
			check(rear.health.current_health==rear_before,label+"actual rear enemy was hit beyond wall")
			check(not is_instance_valid(shot) or shot.is_queued_for_deletion(),label+"front Area/wall sequence did not retire shot")
			var stop_face: float = area.global_position.x-area.body_radius if pierce==0 else -1.0
			check(not trace.is_empty() and trace.back().after.x<=stop_face+0.2,label+"shot flew beyond the impact that exhausted flight")
			cases += 1; host.free(); await process_frame; await process_frame

func run() -> void:
	var previous_hz := Engine.physics_ticks_per_second
	await test_six_maps()
	await test_thin_wall_fairness()
	await test_legal_flight_segment()
	await test_nearer_target_before_wall()
	await test_two_ordered_enemies_before_wall()
	await test_actual_areas_before_wall()
	Engine.physics_ticks_per_second = previous_hz
	check(cases==92,"original86 or six final ordered-enemy/Area cases missing")
	print("FIRST WALL CHECKS: %d cases=%d failures=%d"%[checks,cases,failures])
	if not failures: print("TEST PASS: CampaignTerrainFirstWallTest %d"%checks)
	quit(1 if failures else 0)
