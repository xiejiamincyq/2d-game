extends SceneTree
## Real six-region StaticBodies + physics/nav/encounter authority. This first
## stage uses direct modest hits; it does not claim weapon-bridge or playtest proof.
const Definitions = preload("res://scripts/campaign/ChapterRunDefinitions.gd")
const Player = preload("res://scripts/actors/Player.gd")
const Growth = preload("res://scripts/systems/UpgradeSystem.gd")
const Terrain = preload("res://scripts/world/TerrainSweep.gd")

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
		push_error("TEST FAIL: CampaignTerrainDestructionTest "+label)
func _initialize() -> void: call_deferred("run")

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
	check(bound and director.start_run(521,player,enemies,shots,portals,growth,map.layout),"chapter %d real map/encounter context"%chapter)
	var kills := [0]; var clears := [0]
	director.enemy_killed.connect(func(_actor,_source,_coins): kills[0] += 1)
	director.chapter_cleared.connect(func(_number): clears[0] += 1)
	return {"host":host,"map":map,"layout":map.layout,"player":player,"growth":growth,"director":director,"kills":kills,"clears":clears}

func footprint(actor: StaticBody2D) -> Rect2:
	var collider: CollisionShape2D = actor.get_node("CollisionShape2D")
	var shape: RectangleShape2D = collider.shape
	return Rect2(collider.global_position-shape.size/2,shape.size)

func circle_hits(f: Dictionary,at: Vector2) -> Array[Dictionary]:
	var shape := CircleShape2D.new(); shape.radius = 9
	var query := PhysicsShapeQueryParameters2D.new(); query.shape = shape
	query.transform = Transform2D(0,at); query.collision_mask = Terrain.QUERY_LAYER
	return f.host.get_world_2d().direct_space_state.intersect_shape(query,32)

func ray_hit(f: Dictionary,rect: Rect2) -> Dictionary:
	var axis := Vector2.RIGHT if rect.size.x<=rect.size.y else Vector2.DOWN
	var distance: float = minf(rect.size.x,rect.size.y)/2+4
	var query := PhysicsRayQueryParameters2D.create(rect.get_center(),rect.get_center()+axis*distance,Terrain.QUERY_LAYER)
	query.hit_from_inside = true
	return f.host.get_world_2d().direct_space_state.intersect_ray(query)

func has_health(actor: Node) -> bool:
	return actor.get_property_list().any(func(p): return p.name==&"health") and is_instance_valid(actor.get("health"))

func test_chapter(chapter: int) -> void:
	var f := fixture(chapter); var label := "chapter %d "%chapter
	await physics_frame; await physics_frame
	var bodies: Array = f.layout.get_children().filter(func(n): return n is StaticBody2D and n.is_in_group(&"arena_obstacles"))
	check(bodies.size()>=2,label+"fixture lacks real buildings")
	if bodies.size()<2:
		f.host.free(); await process_frame; return
	var actor: StaticBody2D = bodies[0]; var other: StaticBody2D = bodies[1]
	var rect := footprint(actor); var other_rect := footprint(other)
	var initial: Array[Dictionary] = f.layout.get_obstacle_descriptors()
	var matches: Array = initial.filter(func(d): return d.rect.is_equal_approx(rect))
	check(matches.size()==1,label+"physical footprint does not match exactly one descriptor")
	if matches.size()==1 and matches[0].rect!=rect:
		print("TERRAIN FOOTPRINT ROUNDING: %s physical=%s descriptor=%s"%[label,rect,matches[0].rect])
	check(not f.layout.is_position_walkable(rect.get_center(),9),label+"initial building does not block navigation")
	check(circle_hits(f,rect.get_center()).any(func(h): return h.collider==actor),label+"initial real circle query misses building")
	var ray := ray_hit(f,rect)
	check(not ray.is_empty() and ray.collider==actor,label+"initial real ray misses building")
	check(not actor.is_in_group(&"enemies") and not f.director.get_active_enemies().has(actor),label+"building is fake enemy/clearance debt")
	f.layout.get_navigation_direction(Vector2(0,100),Vector2.ZERO,9)
	f.layout.get_navigation_direction(Vector2(0,100),Vector2.ZERO,56)
	check(f.layout.flow_fields.size()==2,label+"actual two-radius flow caches did not warm")
	check(actor.has_method("take_damage") and has_health(actor),label+"real building missing independent health/take_damage")
	if not actor.has_method("take_damage") or not has_health(actor):
		f.host.free(); await process_frame; await process_frame; return
	var health = actor.get("health")
	check(has_health(other) and health!=other.get("health"),label+"neighbor shares building health")
	var maximum: float = health.max_health
	check(is_finite(maximum) and maximum>9 and health.current_health==maximum,label+"building must survive one ordinary 9-point hit")
	var state_before: int = f.director.state; var coins_before: int = f.growth.coins
	var queue_before: Array = f.director.spawn_queue.duplicate()
	actor.call("take_damage",9)
	check(is_instance_valid(health) and health.current_health<maximum and health.current_health>0,label+"small nonlethal hit did not reduce independent HP")
	var hits := 1
	for _hit in 512:
		if not is_instance_valid(actor) or not is_instance_valid(health) or health.current_health<=0 or actor.is_queued_for_deletion(): break
		actor.call("take_damage",9); hits += 1
	check(not is_instance_valid(health) or health.current_health==0,label+"continuous modest attacks did not destroy building")
	check(hits>1,label+"building was one-shot instead of continuous damage")
	# Observe actual physics authority after queued/deferred shape retirement.
	await process_frame; await physics_frame; await physics_frame; await process_frame
	check(circle_hits(f,rect.get_center()).is_empty() and ray_hit(f,rect).is_empty(),label+"destroyed building remains a real circle/ray obstruction")
	var remaining: Array[Dictionary] = f.layout.get_obstacle_descriptors()
	check(remaining.size()==initial.size()-1 and not remaining.any(func(d): return d.rect.is_equal_approx(rect)),label+"destroyed footprint remains in authoritative obstacle descriptors")
	check(f.layout.is_position_walkable(rect.get_center(),9),label+"destroyed center remains nonwalkable")
	check(f.layout.flow_fields.is_empty(),label+"destruction retained stale two-radius flow caches")
	f.layout.get_navigation_direction(Vector2(0,100),Vector2.ZERO,9)
	check(f.layout.flow_fields.size()==1,label+"navigation could not rebuild cache after destruction")
	check(is_instance_valid(other) and not other.is_queued_for_deletion() and remaining.any(func(d): return d.rect.is_equal_approx(other_rect)) and not f.layout.is_position_walkable(other_rect.get_center(),9),label+"destroying one building removed another physical/nav owner")
	check(circle_hits(f,other_rect.get_center()).any(func(h): return h.collider==other),label+"other building lost its real collider")
	check(f.kills[0]==0 and f.clears[0]==0 and f.host.coins==0 and f.growth.coins==coins_before and f.director.state==state_before and f.director.spawn_queue==queue_before,label+"terrain damage manufactured kill/coins/progression")
	check(f.director.get_active_enemies().is_empty() and (not is_instance_valid(actor) or not actor.is_in_group(&"enemies")),label+"destroyed terrain entered enemy ledger")
	f.host.free(); await process_frame; await process_frame

func run() -> void:
	for chapter in range(1,7): await test_chapter(chapter)
	print("TERRAIN DESTRUCTION CHECKS: %d failures=%d"%[checks,failures])
	if not failures: print("TEST PASS: CampaignTerrainDestructionTest %d"%checks)
	quit(1 if failures else 0)
