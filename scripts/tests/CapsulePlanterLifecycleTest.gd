extends SceneTree
const Factory = preload("res://scripts/campaign/RegionalEnemyFactory.gd")
const Plant = preload("res://scripts/components/CapsulePlantHazard.gd")
const Shot = preload("res://scripts/components/Projectile.gd")
class Target extends CharacterBody2D:
	var hits: Array[float] = []
	var stealth_active := false
	func take_damage(amount: float) -> void: hits.append(amount)
	func is_stealthed() -> bool: return stealth_active
var checks := 0
var failures := 0
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("TEST FAIL: CapsulePlanterLifecycleTest "+label)
func create_actor(arena: Node2D,shots: Node2D,target: Node2D):
	var actor = Factory.create_actor(4,"capsule_planter",0,shots,target)
	actor.world_bounds = Rect2(-600,-400,1400,1000)
	arena.add_child(actor)
	actor.set_physics_process(false)
	actor.shoot_cooldown = 0
	return actor
func _initialize() -> void: call_deferred("_run")
func finish_windup(actor: Node) -> void:
	for step in 120:
		if not actor.ranged_is_winding_up: break
		actor._physics_process(1.0/120.0)
func _run() -> void:
	var arena := Node2D.new()
	root.add_child(arena)
	var shots := Node2D.new()
	arena.add_child(shots)
	var target := Target.new()
	target.position = Vector2(240,0)
	arena.add_child(target)
	var actor = create_actor(arena,shots,target)
	actor._physics_process(0.01)
	target.stealth_active = true
	actor._physics_process(0.3)
	check(not actor.ranged_is_winding_up and not actor.pending_plant and shots.get_child_count()==0,"hidden target retains pending plant")
	target.stealth_active = false
	actor.shoot_cooldown = 0
	actor._physics_process(0.01)
	actor.apply_spawn_impulse(Vector2.ZERO,0.3)
	actor._physics_process(0.1)
	check(not actor.pending_plant and shots.get_child_count()==0,"spawn guard emits stale capsule")
	actor.spawn_impulse_remaining = 0
	actor.take_damage(1)
	check(actor.native_visual.player.current_animation=="hit","nonlethal hit lacks new recoil")
	# A pending placement owned by a dying actor must never enter the tree.
	actor.shoot_cooldown = 0
	actor._physics_process(0.01)
	finish_windup(actor)
	check(actor.get_owned_plant_count()==1,"pending cleanup fixture lacks reserved plant")
	actor.take_damage(1000)
	await process_frame
	await process_frame
	check(shots.get_child_count()==0 and get_nodes_in_group("capsule_plants").is_empty(),"death before admission leaks capsule")
	# Removed/queued projectile containers cannot receive new physics Areas.
	var cancelled = create_actor(arena,shots,target)
	cancelled._physics_process(0.01)
	finish_windup(cancelled)
	shots.queue_free()
	await process_frame
	await process_frame
	check(cancelled.get_owned_plant_count()==0 and get_nodes_in_group("capsule_plants").is_empty(),"queued destination leaves pending plant")
	arena.free()
	await process_frame
	# Real map wall blocks all local placements; no through-wall capsule.
	var map = load("res://scenes/world/mist_nursery.tscn").instantiate()
	map.map_seed = 521
	root.add_child(map)
	var layout = map.get_node("Layout")
	var rect: Rect2 = layout.get_obstacle_descriptors()[0].rect
	var wall_shots := Node2D.new()
	map.add_child(wall_shots)
	var wall_target := Target.new()
	wall_target.position = Vector2(rect.position.x+70,rect.get_center().y)
	map.add_child(wall_target)
	var wall_actor = create_actor(map,wall_shots,wall_target)
	wall_actor.position = Vector2(rect.position.x-20,rect.get_center().y)
	wall_actor.world_bounds = layout.world_bounds
	wall_actor.set_arena_navigation(layout)
	await physics_frame
	wall_actor._physics_process(0.01)
	wall_actor._physics_process(0.2)
	await process_frame
	check(wall_actor.get_owned_plant_count()==0 and not wall_actor.should_show_attack_marker(),"blocked placement ignores actual nursery wall")
	map.free()
	await process_frame
	# An unsafe edge placement cannot silently extend a 32px rim outside the world.
	var edge_arena := Node2D.new()
	root.add_child(edge_arena)
	var edge_shots := Node2D.new()
	edge_arena.add_child(edge_shots)
	var edge_target := Target.new()
	edge_target.position = Vector2(78,45)
	edge_arena.add_child(edge_target)
	var edge = create_actor(edge_arena,edge_shots,edge_target)
	edge.position = Vector2(16,45)
	edge.world_bounds = Rect2(0,0,90,90)
	check(not edge._is_safe_plant_position(Vector2(70,45)) and edge._is_safe_plant_position(Vector2(45,45)),"placement ignores complete danger rim world margin")
	edge_arena.free()
	await process_frame
	# Actual Area2D player-shot collision, not a direct take_damage surrogate.
	var collision_arena := Node2D.new()
	root.add_child(collision_arena)
	var plant := Plant.new()
	collision_arena.add_child(plant)
	plant.set_physics_process(false)
	var bullet := Shot.new()
	bullet.position = Vector2(-30,0)
	bullet.velocity = Vector2(120,0)
	bullet.damage = 20
	collision_arena.add_child(bullet)
	var deadline := Time.get_ticks_msec()+1500
	while is_instance_valid(plant) and Time.get_ticks_msec()<deadline: await physics_frame
	check(not is_instance_valid(plant),"actual projectile Area collision cannot destroy seed")
	check(not is_instance_valid(bullet) or bullet.is_queued_for_deletion(),"capsule does not consume non-piercing player shot")
	# Actual pause freezes a live capsule; teardown leaves no physics objects.
	var paused_plant := Plant.new()
	collision_arena.add_child(paused_plant)
	await physics_frame
	var before: float = paused_plant.age
	paused = true
	await create_timer(0.05,true,false,true).timeout
	check(is_equal_approx(paused_plant.age,before),"paused ground seed advances its attack clock")
	paused = false
	paused_plant.disarm()
	collision_arena.free()
	await process_frame
	if not failures: print("TEST PASS: CapsulePlanterLifecycleTest %d" % checks)
	quit(1 if failures else 0)
