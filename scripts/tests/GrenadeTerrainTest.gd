extends SceneTree
## Real six-map colliders, not visual pivots. Manual blast controls plus natural
## flight; no player build stats or human playthrough are inferred from this.
const Definitions = preload("res://scripts/campaign/ChapterRunDefinitions.gd")
const Grenade = preload("res://scripts/components/GrenadeProjectile.gd")
const Trap = preload("res://scripts/world/ReusableStepTrap.gd")
const Obstacle = preload("res://scripts/world/ArenaObstacle.gd")
var checks:=0
var failures:=0
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		push_error("TEST FAIL: GrenadeTerrainTest "+label)
func _initialize() -> void: call_deferred("run")
func tick() -> void: await physics_frame; await process_frame
func blast(parent: Node,at: Vector2,amount: float=9) -> Node:
	var grenade:=Grenade.new(); grenade.position=at; grenade.damage=amount
	grenade.enemy_provider=func(): return []
	parent.add_child(grenade); grenade.set_physics_process(false)
	return grenade
func wait_for(predicate: Callable,seconds: float=0.5) -> bool:
	var first:=Engine.get_physics_frames()
	while float(Engine.get_physics_frames()-first)/Engine.physics_ticks_per_second<seconds:
		if predicate.call(): return true
		await tick()
	return predicate.call()
func run() -> void:
	for chapter in range(1,7): await map_case(chapter)
	await trap_and_world_isolation()
	await crowded_targets()
	await thin_wall_flight()
	if failures==0: print("TEST PASS: GrenadeTerrainTest %d"%checks)
	quit(1 if failures else 0)
func map_case(chapter: int) -> void:
	var host:=Node2D.new(); root.add_child(host)
	var definition: Dictionary=Definitions.get_definition(chapter)
	var map: Node2D=definition.map.instantiate(); map.map_seed=521; host.add_child(map)
	var wall: Node2D=map.layout.get_child(0)
	var rect: Rect2=wall.get_damage_rect()
	await tick(); await tick()
	var hp: float=wall.health.current_health
	var at:=Vector2(rect.position.x-81,rect.get_center().y)
	check(at.distance_to(wall.global_position)>82,"chapter%d fixture exposes bottom-pivot range error"%chapter)
	var grenade:=blast(host,at)
	var emissions: Array[Vector2]=[]
	grenade.exploded.connect(func(position: Vector2,_radius: float): emissions.append(position))
	grenade._explode(); grenade._explode()
	check(wall.health.current_health==hp-9,"chapter%d blast intersects actual left edge exactly once"%chapter)
	check(emissions.size()==1,"chapter%d explosion event not duplicated"%chapter)
	await process_frame
	hp=wall.health.current_health
	grenade=blast(host,Vector2(rect.position.x-84,rect.get_center().y)); grenade._explode()
	check(wall.health.current_health==hp,"chapter%d blast outside82px does not inflate building radius"%chapter)
	await process_frame
	# Even an explicit provider alias must not apply a second hit to terrain.
	hp=wall.health.current_health
	grenade=blast(host,at); grenade.enemy_provider=func(): return [wall,wall]
	grenade._explode()
	check(wall.health.current_health==hp-9,"chapter%d provider/query duplicate damages building only once"%chapter)
	await process_frame
	# Ordinary engine flight, not a manual call to the collision callback.
	grenade=Grenade.new(); grenade.damage=9; grenade.enemy_provider=func(): return []
	grenade.position=Vector2(rect.position.x-60,rect.get_center().y); grenade.velocity=Vector2(360,0)
	var impacts: Array[Vector2]=[]
	grenade.exploded.connect(func(position: Vector2,_radius: float): impacts.append(position))
	host.add_child(grenade)
	check(await wait_for(func(): return not impacts.is_empty()),"chapter%d natural grenade actually detonates at building"%chapter)
	check(impacts.size()==1 and impacts[0].x<=rect.position.x-6.8,"chapter%d flight stops at first collision face"%chapter)
	check(wall.health.current_health==hp-18,"chapter%d impact blast applies one9HP hit, not direct-plus-blast"%chapter)
	host.free(); await process_frame
func trap_and_world_isolation() -> void:
	var a:=SubViewport.new(); a.world_2d=World2D.new(); root.add_child(a)
	var b:=SubViewport.new(); b.world_2d=World2D.new(); root.add_child(b)
	var own:=Trap.new(); var other:=Trap.new(); a.add_child(own); b.add_child(other)
	await tick(); await tick()
	var grenade:=blast(a,Vector2(90,0)); grenade._explode()
	check(own.health.current_health==71,"explosion grazes actual12px trap body at90px")
	check(other.health.current_health==80,"same-position other World2D never receives damage")
	await process_frame
	grenade=blast(a,Vector2.ZERO)
	grenade.damage_multiplier_provider=func(): grenade.queue_free(); return 2.0
	grenade._explode()
	check(own.health.current_health==71,"queued multiplier callback cancels terrain damage")
	await process_frame
	grenade=blast(a,Vector2.ZERO)
	grenade.damage_multiplier_provider=func(): a.remove_child(grenade); return 2.0
	grenade._explode()
	check(grenade.is_queued_for_deletion() and own.health.current_health==71,"detached multiplier callback retires without damage or orphan")
	if not grenade.is_queued_for_deletion(): grenade.free()
	var outside:=Trap.new(); outside.position=Vector2(120,0); a.add_child(outside)
	await tick(); await tick()
	grenade=blast(a,Vector2(120,0)); grenade.world_bounds=Rect2(-100,-100,200,200); grenade.lifetime=0
	var emitted:=[0]; grenade.exploded.connect(func(_at,_radius): emitted[0]+=1)
	grenade._physics_process(0.01)
	check(outside.health.current_health==80 and emitted[0]==0 and grenade.is_queued_for_deletion(),"expired birth outside legal bounds cannot detonate")
	a.free(); b.free(); await process_frame
func crowded_targets() -> void:
	var host:=Node2D.new(); root.add_child(host)
	var traps: Array[Node]=[]
	for index in 65:
		var trap:=Trap.new(); trap.position=Vector2((index%9)*2,(index/9)*2); host.add_child(trap); traps.append(trap)
	await tick(); await tick()
	var grenade:=blast(host,Vector2.ZERO); grenade._explode()
	check(traps.all(func(trap): return trap.health.current_health==71),"all65 overlapped terrain receivers damaged, not a silent32/64 result cap")
	host.free(); await process_frame
func thin_wall_flight() -> void:
	var host:=Node2D.new(); root.add_child(host)
	var wall:=Obstacle.new(); wall.setup(Rect2(-1,-50,2,100),&"planter"); host.add_child(wall)
	await tick(); await tick()
	var grenade:=Grenade.new(); grenade.position=Vector2(-80,0); grenade.velocity=Vector2(9600,0)
	grenade.damage=9; grenade.enemy_provider=func(): return []
	var impacts: Array[Vector2]=[]; grenade.exploded.connect(func(at: Vector2,_radius: float): impacts.append(at))
	host.add_child(grenade)
	check(await wait_for(func(): return not impacts.is_empty()),"natural fast grenade cannot skip2px wall")
	check(impacts.size()==1 and impacts[0].x<=-7.8,"fast grenade explodes at swept first wall, not final position: "+str(impacts))
	check(wall.health.current_health==wall.health.max_health-9,"fast first wall receives exactly one explosion")
	host.free(); await process_frame
