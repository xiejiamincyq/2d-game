extends SceneTree
## Real low-speed production swept flight in six maps + real RiftShard sweep.
## No direct _try_hit calls; not the complete high-speed sweep/weapon acceptance.
const Definitions = preload("res://scripts/campaign/ChapterRunDefinitions.gd")
const Player = preload("res://scripts/actors/Player.gd")
const Growth = preload("res://scripts/systems/UpgradeSystem.gd")
const Shot = preload("res://scripts/components/Projectile.gd")
const Shard = preload("res://scripts/components/RiftShardProjectile.gd")

class DropRecorder extends Node2D:
	var coins := 0
	func spawn_coins(_at: Vector2,count: int) -> void: coins += count
	func spawn_shield(_at: Vector2,_amount: float) -> void: pass
	func spawn_heart(_at: Vector2,_amount: float) -> void: pass

var checks := 0
var failures := 0
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("TEST FAIL: CampaignTerrainProjectileTest "+label)
func _initialize() -> void:
	call_deferred("diagnose_area_pairs" if "--area-diagnostic" in OS.get_cmdline_user_args() else "run")

func diagnose_area_pairs() -> void:
	# Diagnostic only: public mask/monitorable controls localize signal admission.
	# Formal map acceptance below keeps production collision properties unchanged.
	for mask in [0,1]:
		for monitorable in [false,true]:
			var host := Node2D.new(); root.add_child(host)
			var wall := StaticBody2D.new(); wall.collision_layer = 3; wall.collision_mask = mask
			var collision := CollisionShape2D.new(); var shape := RectangleShape2D.new(); shape.size = Vector2(40,40)
			collision.shape = shape; wall.add_child(collision); host.add_child(wall)
			await physics_frame; await physics_frame
			var shot := Shot.new(); shot.position = Vector2(-40,0); shot.velocity = Vector2(120,0)
			var entered := [0]; shot.body_entered.connect(func(body):
				if body==wall: entered[0] += 1)
			host.add_child(shot); shot.monitorable = monitorable
			# Diagnostic isolates Area admission, not the production swept flight.
			shot.set_physics_process(false)
			for _step in 45:
				shot.position += shot.velocity/Engine.physics_ticks_per_second
				await physics_frame
			print("AREA PAIR CONTROL body-mask=%d area-monitorable=%s area-mask=%d entered=%d world-equal=%s"%[mask,monitorable,shot.collision_mask,entered[0],shot.get_world_2d()==wall.get_world_2d()])
			host.free(); await process_frame; await process_frame
	quit(0)

func fixture(chapter: int) -> Dictionary:
	var definition: Dictionary = Definitions.get_definition(chapter)
	var host := DropRecorder.new(); root.add_child(host)
	var map = definition.map.instantiate(); map.map_seed = 521; host.add_child(map)
	var player := Player.new(); player.world_bounds = map.layout.world_bounds
	host.add_child(player); player.set_physics_process(false)
	var enemies := Node2D.new(); var shots := Node2D.new(); var portals := Node2D.new()
	for layer in [enemies,shots,portals]: host.add_child(layer)
	var growth := Growth.new(); host.add_child(growth); growth.setup(player)
	var director = definition.director.new(); host.add_child(director); director.set_process(false)
	var bound := true
	match chapter:
		2: bound = director.bind_heat_field(map.heat_field)
		3: bound = director.bind_tidal_field(map.tidal_field)
		4: bound = director.bind_spore_field(map.spore_field)
		5: bound = director.bind_echo_field(map.echo_field)
		6: bound = director.bind_rift_field(map.rift_field)
	check(bound and director.start_run(521,player,enemies,shots,portals,growth,map.layout),"chapter %d actual map/encounter start"%chapter)
	var kills := [0]; var clears := [0]
	director.enemy_killed.connect(func(_actor,_source,_coins): kills[0] += 1)
	director.chapter_cleared.connect(func(_number): clears[0] += 1)
	return {"host":host,"map":map,"player":player,"growth":growth,"director":director,"shots":shots,"kills":kills,"clears":clears}

func rect_of(actor: StaticBody2D) -> Rect2:
	var collider := actor.get_node("CollisionShape2D") as CollisionShape2D
	var shape := collider.shape as RectangleShape2D
	return Rect2(collider.global_position-shape.size/2,shape.size)

func fire_projectile(f: Dictionary,actor: StaticBody2D,rect: Rect2,axis: Vector2,damage: float,group: StringName,label: String) -> void:
	var before: float = actor.health.current_health
	var player_before: float = f.player.health.current_health
	var shot := Shot.new(); shot.damage = damage; shot.target_group = group
	shot.velocity = axis*120; shot.pierce = 0; shot.lifetime = 3
	shot.world_bounds = f.map.layout.world_bounds
	shot.position = rect.get_center()-axis*(minf(rect.size.x,rect.size.y)/2+20)
	var damage_events := [0]; var moved := [false]; var start := shot.position
	var last := [start]
	var on_damage := func(_current, _maximum): damage_events[0] += 1
	actor.health.health_changed.connect(on_damage)
	f.shots.add_child(shot)
	shot.tree_exiting.connect(func():
		last[0] = shot.global_position
		moved[0] = moved[0] or last[0].distance_to(start)>0.1)
	for _step in 90:
		await physics_frame
		if is_instance_valid(shot):
			moved[0] = moved[0] or shot.position.distance_to(start)>0.1
			last[0] = shot.global_position
		if damage_events[0]>0 or not is_instance_valid(shot): break
	await process_frame; await physics_frame; await process_frame
	actor.health.health_changed.disconnect(on_damage)
	check(moved[0] and damage_events[0]==1 and (last[0]-rect.get_center()).dot(axis)<=-minf(rect.size.x,rect.size.y)/2+0.2,label+" physical flight did not resolve one real Health hit at the wall entry face")
	check(is_equal_approx(actor.health.current_health,before-damage),label+" actual projectile did not damage the building exactly once")
	check(not is_instance_valid(shot) or shot.is_queued_for_deletion(),label+" nonpiercing actual projectile was not consumed by wall")
	check(f.player.health.current_health==player_before,label+" wall impact damaged neighboring actual player")
	if is_instance_valid(shot): shot.queue_free()
	await process_frame

func fire_shard(f: Dictionary,actor: StaticBody2D,rect: Rect2,axis: Vector2) -> void:
	var before: float = actor.health.current_health
	var player_before: float = f.player.health.current_health
	var shard := Shard.new()
	check(shard.damage==12 and shard.radius==4 and shard.target_group==&"player","RiftShard fixture changed original damage/radius/target")
	shard.velocity = axis*shard.velocity.length()
	shard.world_bounds = f.map.layout.world_bounds
	shard.position = rect.get_center()-axis*(minf(rect.size.x,rect.size.y)/2+20)
	var start := shard.position; var moved := [false]; var last := [start]
	f.shots.add_child(shard)
	shard.tree_exiting.connect(func(): last[0] = shard.global_position)
	for _step in 60:
		await physics_frame
		if not is_instance_valid(shard): break
		moved[0] = moved[0] or shard.position.distance_to(start)>0.1
		last[0] = shard.global_position
		if shard.is_queued_for_deletion(): break
	await process_frame; await physics_frame; await process_frame
	check(moved[0],"RiftShard positive control did not physically fly")
	check(is_equal_approx(actor.health.current_health,before-12),"RiftShard actual circle-sweep wall branch did not apply original 12 damage")
	check(not is_instance_valid(shard) or shard.is_queued_for_deletion(),"RiftShard passed through building instead of retiring at first wall")
	check((last[0]-rect.get_center()).dot(axis)<=-minf(rect.size.x,rect.size.y)/2+0.2,"RiftShard crossed the wall's entry face before retirement")
	check(f.player.health.current_health==player_before,"RiftShard wall branch damaged player behind building")
	if is_instance_valid(shard): shard.queue_free()
	await process_frame

func test_chapter(chapter: int) -> void:
	var f := fixture(chapter); var label := "chapter %d "%chapter
	await physics_frame; await physics_frame
	var bodies: Array = f.map.layout.get_children().filter(func(n): return n is StaticBody2D and n.is_in_group(&"arena_obstacles"))
	check(bodies.size()>=2,label+"missing real physical buildings")
	if bodies.size()<2: f.host.free(); await process_frame; return
	var actor: StaticBody2D = bodies[0]; var other: StaticBody2D = bodies[1]
	check(actor.has_method("take_damage") and is_instance_valid(actor.get("health")),label+"destructible building prerequisite absent")
	if not actor.has_method("take_damage") or not is_instance_valid(actor.get("health")):
		f.host.free(); await process_frame; return
	var rect := rect_of(actor); var axis := Vector2.RIGHT if rect.size.x<=rect.size.y else Vector2.DOWN
	f.player.global_position = rect.get_center()+axis*(minf(rect.size.x,rect.size.y)/2+40)
	check(f.map.layout.is_position_walkable(f.player.global_position,16.9),label+"nearby real player fixture is inside another building")
	await physics_frame; await physics_frame
	var other_hp: float = other.health.current_health
	var count_before: int = f.map.layout.get_obstacle_descriptors().size()
	var coins_before: int = f.growth.coins; var state_before: int = f.director.state
	await fire_projectile(f,actor,rect,axis,9,&"enemies",label+"friendly")
	await fire_projectile(f,actor,rect,axis,21,&"player",label+"hostile")
	if chapter==6: await fire_shard(f,actor,rect,axis)
	check(other.health.current_health==other_hp and f.map.layout.get_obstacle_descriptors().size()==count_before,label+"impact damaged unrelated building/changed navigation footprint")
	check(not actor.is_in_group(&"enemies") and f.director.get_active_enemies().is_empty() and f.kills[0]==0 and f.clears[0]==0 and f.host.coins==0 and f.growth.coins==coins_before and f.director.state==state_before,label+"wall shot manufactured enemy kill/coin/progression")
	f.host.free(); await process_frame; await process_frame

func run() -> void:
	for chapter in range(1,7): await test_chapter(chapter)
	print("TERRAIN PROJECTILE CHECKS: %d failures=%d"%[checks,failures])
	if not failures: print("TEST PASS: CampaignTerrainProjectileTest %d"%checks)
	quit(1 if failures else 0)
