extends SceneTree
## Actual six-map walls and actual Player drone damage. Controlled passive ticks,
## not normal-input campaign completion or final performance/GPU acceptance.
const Definitions = preload("res://scripts/campaign/ChapterRunDefinitions.gd")
const Player = preload("res://scripts/actors/Player.gd")
const Enemy = preload("res://scripts/actors/Enemy.gd")
const Obstacle = preload("res://scripts/world/ArenaObstacle.gd")
const Trap = preload("res://scripts/world/ReusableStepTrap.gd")
class UnownedStatic extends StaticBody2D:
	var damage_taken:=0.0
	func take_damage(amount: float,_source: StringName,_direction: Vector2=Vector2.ZERO) -> void: damage_taken+=amount
var checks:=0
var failures:=0
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		push_error("TEST FAIL: LaserTerrainTest "+label)
func _initialize() -> void: call_deferred("run")
func tick() -> void: await physics_frame; await process_frame
func player_at(parent: Node,at: Vector2) -> Node2D:
	var player:=Player.new(); player.position=at; player.projectile_parent=parent
	parent.add_child(player); player.set_physics_process(false)
	return player
func enemy_at(parent: Node,at: Vector2) -> Node2D:
	var actor:=Enemy.new(); actor.setup(Enemy.EnemyKind.SCRAPPER,0,parent)
	actor.position=at; parent.add_child(actor); actor.set_physics_process(false)
	return actor
func wall_at(parent: Node,rect: Rect2) -> Node2D:
	var wall:=Obstacle.new(); wall.setup(rect,&"planter"); parent.add_child(wall)
	return wall
func run() -> void:
	var player_source: Script=load("res://scripts/actors/Player.gd")
	check(player_source.can_instantiate(),"production Player dependency compiles")
	if failures: quit(1); return
	for chapter in range(1,7): await map_case(chapter)
	await ordered_targets()
	await pressure_plate()
	for width in [4.0,6.0]:
		for gap in [2.0,5.0]: await grazing(width,gap)
	await many_receivers()
	await rotated_corner()
	await world_isolation()
	await next_cover()
	await unowned_static()
	if failures==0: print("TEST PASS: LaserTerrainTest %d"%checks)
	quit(1 if failures else 0)
func map_case(chapter: int) -> void:
	var host:=Node2D.new(); root.add_child(host)
	var definition: Dictionary=Definitions.get_definition(chapter)
	var map: Node2D=definition.map.instantiate(); map.map_seed=521; host.add_child(map)
	# Rift equipment deliberately overlaps into a stair. Select an actual wall
	# lane without a second module behind it, rather than embedding the rear
	# actor in that module and incorrectly expecting one removal to clear both.
	var wall: Node2D
	var rect:=Rect2()
	var lane_y:=0.0
	for candidate in map.layout.get_children():
		var candidate_rect: Rect2=candidate.get_damage_rect()
		for fraction in [0.5,0.2,0.8]:
			var y: float=candidate_rect.position.y+candidate_rect.size.y*fraction
			var corridor:=Rect2(candidate_rect.position.x-80,y-4,candidate_rect.size.x+160,8)
			var clear: bool=map.layout.is_position_walkable(Vector2(corridor.position.x,y),player_radius()) and map.layout.is_position_walkable(Vector2(corridor.end.x,y),14)
			for other in map.layout.get_children():
				if other!=candidate and corridor.intersects(other.get_damage_rect()): clear=false
			if clear: wall=candidate; rect=candidate_rect; lane_y=y; break
		if wall!=null: break
	check(wall!=null,"chapter%d has a genuine isolated wall lane for one-removal control"%chapter)
	if wall==null: host.free(); await process_frame; return
	var origin:=Vector2(rect.position.x-80,lane_y)
	var player:=player_at(host,origin)
	var rear:=enemy_at(host,Vector2(rect.end.x+80,origin.y))
	player.set_enemy_provider(func(): return [rear])
	await tick(); await tick()
	var rear_hp: float=rear.health.current_health
	for piercing in [false,true]:
		player.drone_laser_piercing=piercing
		var hp: float=wall.health.current_health
		var ray: Dictionary=player._resolve_drone_ray(origin,Vector2.RIGHT,4,[rear])
		check(ray.targets.has(wall) and not ray.targets.has(rear),"chapter%d pierce%s selects wall receiver, not rear actor"%[chapter,piercing])
		check(ray.end.x<=rect.position.x+0.1,"chapter%d pierce%s visual end never crosses first wall"%[chapter,piercing])
		player._damage_enemies_on_laser(origin,Vector2.RIGHT,rect.size.x+300,1,4,[rear])
		check(wall.health.current_health==hp-1 and rear.health.current_health==rear_hp,"chapter%d pierce%s actual finite beam damages only wall"%[chapter,piercing])
	check(player._get_enemies()==[rear] and not wall.is_in_group(&"enemies"),"chapter%d damage candidate not automatic aim/clear debt"%chapter)
	# Once the wall-routing prerequisite has failed, report that semantic RED
	# without driving a doomed rear actor through hundreds of later fixture ticks.
	var gate: Dictionary=player._resolve_drone_ray(origin,Vector2.RIGHT,4,[rear])
	if not gate.targets.has(wall) or rear.health.current_health!=rear_hp:
		host.free(); await process_frame; return
	# Exercise the production drone update, not only the resolver/helper.
	player.drone_count=1; player._sync_drone_visuals(); player._sync_drone_lasers()
	player.drone_visuals[0].global_position=origin; player.drone_aim_directions[0]=Vector2.RIGHT
	var hp: float=wall.health.current_health
	player._update_drone_lasers(0.1)
	check(is_equal_approx(wall.health.current_health,hp-player.drone_damage*0.1),"chapter%d production drone applies unchanged DPS to cover"%chapter)
	check(rear.health.current_health==rear_hp and player.drone_targets==[rear],"chapter%d wall intercept preserves actual enemy lock"%chapter)
	for step in 240:
		if wall.is_queued_for_deletion(): break
		player._update_drone_lasers(0.1)
	check(wall.is_queued_for_deletion() and rear.health.current_health==rear_hp,"chapter%d sustained real laser destroys cover before harming rear"%chapter)
	await tick(); await tick()
	player._update_drone_lasers(0.1)
	check(rear.health.current_health<rear_hp,"chapter%d removed cover releases laser to actual enemy"%chapter)
	host.free(); await process_frame
func rotated_corner() -> void:
	var host:=Node2D.new(); root.add_child(host)
	var wall:=wall_at(host,Rect2(-30,-10,60,20)); wall.rotation=0.73
	var collider: CollisionShape2D=wall.get_node("CollisionShape2D")
	var corner: Vector2=collider.to_global(collider.shape.size/2)
	var player:=player_at(host,Vector2(-100,corner.y+2))
	var rear:=enemy_at(host,Vector2(150,corner.y+2))
	await tick(); await tick()
	for gap in [2.0,5.0]:
		var origin:=Vector2(-100,corner.y+gap)
		for width in [4.0,6.0]:
			var ray: Dictionary=player._resolve_drone_ray(origin,Vector2.RIGHT,width,[rear])
			check(ray.targets.has(wall)==(gap<width) and ray.targets.has(rear)==(gap>=width),"rotated actual corner uses rounded thick-ray geometry, not world AABB")
	host.free(); await process_frame
func world_isolation() -> void:
	var a:=SubViewport.new(); a.world_2d=World2D.new(); root.add_child(a)
	var b:=SubViewport.new(); b.world_2d=World2D.new(); root.add_child(b)
	var player:=player_at(a,Vector2(-100,0))
	var own:=Trap.new(); a.add_child(own); var other:=Trap.new(); b.add_child(other)
	await tick(); await tick()
	var ray: Dictionary=player._resolve_drone_ray(player.position,Vector2.RIGHT,4,[])
	check(ray.targets==[own] and not ray.targets.has(other),"beam terrain query cannot leak across same-position World2D")
	a.free(); b.free(); await process_frame
func next_cover() -> void:
	var host:=Node2D.new(); root.add_child(host)
	var first:=wall_at(host,Rect2(-1,-50,2,100)); var second:=wall_at(host,Rect2(79,-50,2,100))
	var player:=player_at(host,Vector2(-100,0)); player.drone_laser_piercing=true
	var rear:=enemy_at(host,Vector2(150,0))
	await tick(); await tick()
	first.take_damage(first.health.max_health); await tick(); await tick()
	var ray: Dictionary=player._resolve_drone_ray(player.position,Vector2.RIGHT,4,[rear])
	check(ray.targets.has(second) and not ray.targets.has(rear),"destroying first cover does not release beam through surviving second cover")
	second.take_damage(second.health.max_health); await tick(); await tick()
	ray=player._resolve_drone_ray(player.position,Vector2.RIGHT,4,[rear])
	check(ray.targets==[rear],"both actual cover removals release ray to actor")
	host.free(); await process_frame
func player_radius() -> float: return Player.BODY_RADIUS
func unowned_static() -> void:
	var host:=Node2D.new(); root.add_child(host)
	var player:=player_at(host,Vector2(-100,0)); player.drone_laser_piercing=true
	var rear:=enemy_at(host,Vector2(100,0))
	var blocker:=UnownedStatic.new()
	var collider:=CollisionShape2D.new(); var shape:=RectangleShape2D.new(); shape.size=Vector2(2,100)
	collider.shape=shape; blocker.add_child(collider); host.add_child(blocker)
	await tick(); await tick()
	var hp: float=rear.health.current_health
	player._damage_enemies_on_laser(player.position,Vector2.RIGHT,300,1,4,[rear])
	check(blocker.damage_taken==0 and rear.health.current_health==hp,"unowned StaticBody blocks beam but method name alone is not damage authorization")
	host.free(); await process_frame
func ordered_targets() -> void:
	var host:=Node2D.new(); root.add_child(host)
	var wall:=wall_at(host,Rect2(-1,-60,2,120))
	var player:=player_at(host,Vector2(-150,0))
	var front:=enemy_at(host,Vector2(-90,0)); var second:=enemy_at(host,Vector2(-40,0)); var rear:=enemy_at(host,Vector2(40,0))
	await tick(); await tick()
	var a: float=front.health.current_health; var b: float=second.health.current_health; var c: float=rear.health.current_health
	var hp: float=wall.health.current_health
	player._damage_enemies_on_laser(player.position,Vector2.RIGHT,300,1,4,[rear,second,front])
	check(front.health.current_health==a-1 and second.health.current_health==b and rear.health.current_health==c and wall.health.current_health==hp,"ordinary beam resolves nearest receiver despite reversed input order")
	player.drone_laser_piercing=true
	player._damage_enemies_on_laser(player.position,Vector2.RIGHT,300,1,4,[rear,second,front])
	check(front.health.current_health==a-2 and second.health.current_health==b-1 and rear.health.current_health==c and wall.health.current_health==hp-1,"pierce crosses two front actors then damages/stops at wall")
	host.free(); await process_frame
func pressure_plate() -> void:
	var host:=Node2D.new(); root.add_child(host)
	var player:=player_at(host,Vector2(-100,0)); var rear:=enemy_at(host,Vector2(100,0))
	var plate:=Trap.new(); host.add_child(plate)
	await tick(); await tick()
	var hp: float=rear.health.current_health
	player.set_enemy_provider(func(): return [rear])
	player._damage_enemies_on_laser(player.position,Vector2.RIGHT,300,9,4,[rear])
	check(plate.health.current_health==71 and rear.health.current_health==hp,"ordinary beam hits monitorable ground receiver before actor")
	player.drone_laser_piercing=true
	player._damage_enemies_on_laser(player.position,Vector2.RIGHT,300,9,4,[plate,plate,rear])
	check(plate.health.current_health==62 and rear.health.current_health==hp-9,"pierce crosses non-solid plate but damages it only once")
	check(player._get_enemies()==[rear] and not plate.is_in_group(&"enemies"),"pressure receiver stays outside canonical aim roster")
	host.free(); await process_frame
func grazing(width: float,gap: float) -> void:
	var host:=Node2D.new(); root.add_child(host)
	var wall:=wall_at(host,Rect2(-1,-50,2,100))
	var origin:=Vector2(-80,50+gap)
	var player:=player_at(host,origin); var rear:=enemy_at(host,Vector2(70,origin.y))
	await tick(); await tick()
	for piercing in [false,true]:
		player.drone_laser_piercing=piercing
		var ray: Dictionary=player._resolve_drone_ray(origin,Vector2.RIGHT,width,[rear])
		if gap<width:
			check(ray.targets.has(wall) and not ray.targets.has(rear) and ray.end.x<0,"actual beam width%.0f grazes corner with gap%.0f despite center-line miss"%[width,gap])
		else:
			check(not ray.targets.has(wall) and ray.targets.has(rear),"outside width%.0f gap%.0f does not inflate collider"%[width,gap])
	host.free(); await process_frame
func many_receivers() -> void:
	var host:=Node2D.new(); root.add_child(host)
	var player:=player_at(host,Vector2(-100,0)); player.drone_laser_piercing=true
	var plates: Array[Node]=[]
	for index in 65:
		var plate:=Trap.new(); plate.position=Vector2(index*20,0); host.add_child(plate); plates.append(plate)
	await tick(); await tick()
	var ray: Dictionary=player._resolve_drone_ray(player.position,Vector2.RIGHT,4,[])
	check(ray.targets.size()==65 and plates.all(func(plate): return ray.targets.has(plate)),"piercing beam does not silently truncate65 terrain Areas")
	host.free(); await process_frame
