extends SceneTree
const Factory = preload("res://scripts/campaign/RegionalEnemyFactory.gd")
const Roster = preload("res://scripts/campaign/RegionalEnemyRoster.gd")
const Damage = preload("res://scripts/components/DamageTypes.gd")
class Target extends Node2D:
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
		push_error("TEST FAIL: SplittingMoteLifecycleTest "+label)
func actor(parent: Node2D,target: Node2D = null):
	var result = Factory.create_actor(4,"splitting_mote",0,parent,target)
	result.world_bounds = Rect2(-650,-450,1300,900)
	parent.add_child(result)
	result.set_physics_process(false)
	return result
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	var arena := Node2D.new()
	root.add_child(arena)
	var target := Target.new()
	target.position = Vector2(40,0)
	target.add_to_group("player")
	arena.add_child(target)
	var parent = actor(arena,target)
	parent.basic_attack.cooldown = 0
	parent._physics_process(0.01)
	check(parent.should_show_attack_marker() and parent.native_visual.player.current_animation=="warning" and target.hits.is_empty(),"pulse lacks head warning or damages early")
	parent._physics_process(0.13)
	check(target.hits.is_empty(),"pulse hits during warning")
	parent._physics_process(parent.basic_attack.get_warning_duration()-parent.basic_attack.elapsed+0.01)
	for index in 3: parent._physics_process(0.01)
	check(target.hits==[21.0] and parent.native_visual.player.current_animation=="attack","actual pulse damage is not unique/bound to attack")
	parent.basic_attack.cancel()
	parent.basic_attack.cooldown = 0
	parent._physics_process(0.01)
	target.stealth_active = true
	parent._physics_process(0.2)
	check(not parent.basic_attack.is_active() and not parent.should_show_attack_marker(),"hidden target retains live pulse")
	target.stealth_active = false
	parent.basic_attack.cooldown = 0
	parent._physics_process(0.01)
	parent.apply_spawn_impulse(Vector2.ZERO,0.3)
	parent._physics_process(0.1)
	check(not parent.basic_attack.is_active() and target.hits==[21.0],"birth guard releases stale pulse")
	parent.spawn_impulse_remaining = 0
	parent.take_damage(1)
	check(parent.native_visual.player.current_animation=="hit","real nonlethal hit lacks new recoil")
	var pose: Transform2D = parent.native_visual.skeleton.get_bone(0).transform
	paused = true
	await process_frame
	await process_frame
	check(parent.native_visual.skeleton.get_bone(0).transform.is_equal_approx(pose),"paused cluster moves")
	paused = false
	# Queued/removal cancellation must not create a successful encounter.
	var rejected := Roster.new()
	rejected.register_actor(parent)
	var false_rewards := [0]
	var false_clears := [0]
	rejected.enemy_defeated.connect(func(_actor,coins,_source): false_rewards[0]+=coins)
	rejected.cleared.connect(func(): false_clears[0]+=1)
	parent.died.emit(parent,999,Damage.GENERIC)
	check(rejected.get_active_count()==1 and false_rewards[0]==0,"roster accepts forged alive death/reward")
	parent.queue_free()
	await process_frame
	check(rejected.failed and rejected.get_active_count()==0 and false_clears[0]==0,"uncleared actor removal becomes success")
	arena.free()
	await process_frame
	# A cancelled encounter must reject deferred descendants, not spawn untracked ones.
	var cancelled_arena := Node2D.new()
	root.add_child(cancelled_arena)
	var cancelled_roster := Roster.new()
	var cancelled_mother = actor(cancelled_arena)
	var removed_member = actor(cancelled_arena)
	cancelled_roster.register_actor(cancelled_mother)
	cancelled_roster.register_actor(removed_member)
	removed_member.queue_free()
	await process_frame
	var rejected_children: Array[CharacterBody2D] = []
	cancelled_mother.offspring_prepared.connect(func(values): rejected_children.assign(values))
	cancelled_mother.take_damage(1000)
	await process_frame
	await process_frame
	check(cancelled_roster.failed and cancelled_roster.get_active_count()==0,"failed roster retains dead parent membership")
	check(rejected_children.size()==2 and rejected_children.all(func(child): return not is_instance_valid(child)),"failed roster spawns untracked descendants")
	cancelled_arena.free()
	await process_frame
	# Register AFTER a reentrant subscriber: death must wait for all birth registration.
	var reentrant_arena := Node2D.new()
	root.add_child(reentrant_arena)
	var mother = actor(reentrant_arena)
	mother.offspring_prepared.connect(func(_children): mother._die(Damage.GENERIC))
	var tracked := Roster.new()
	tracked.register_actor(mother)
	var early_clears := [0]
	tracked.cleared.connect(func(): early_clears[0]+=1)
	var children: Array[CharacterBody2D] = []
	mother.offspring_prepared.connect(func(values): children.assign(values))
	mother.take_damage(1000)
	check(tracked.get_active_count()==2 and early_clears[0]==0,"reentrant split listener settles before pending descendants")
	reentrant_arena.queue_free()
	await process_frame
	await process_frame
	check(children.all(func(child): return not is_instance_valid(child)) and tracked.get_active_count()==0 and tracked.failed,"queued owner leaves pending orphan enemies")
	# Immediate owner destruction also cancels deferred births, without orphan nodes.
	var removed_arena := Node2D.new()
	root.add_child(removed_arena)
	var orphan_parent = actor(removed_arena)
	var pending: Array[CharacterBody2D] = []
	orphan_parent.offspring_prepared.connect(func(values): pending.assign(values))
	orphan_parent.take_damage(1000)
	removed_arena.free()
	await process_frame
	check(pending.size()==2 and pending.all(func(child): return not is_instance_valid(child)),"freed birth owner leaks actual unparented fragment nodes")
	# Real map/edge shape queries; inspect actual children, not only planned points.
	var map = load("res://scenes/world/mist_nursery.tscn").instantiate()
	map.map_seed = 521
	root.add_child(map)
	var layout = map.get_node("Layout")
	var rect: Rect2 = layout.get_obstacle_descriptors()[0].rect
	var near_wall = actor(map)
	near_wall.world_bounds = layout.world_bounds
	near_wall.set_arena_navigation(layout)
	near_wall.position = Vector2(rect.position.x-20,rect.get_center().y)
	await physics_frame
	var wall_children: Array[CharacterBody2D] = []
	near_wall.offspring_prepared.connect(func(values): wall_children.assign(values))
	near_wall.take_damage(1000)
	await process_frame
	check(wall_children.size()==2,"safe wall-side splitting loses valid births")
	for child in wall_children:
		child.set_physics_process(false)
		check(layout.is_position_walkable(child.global_position,9),"fragment born inside actual nursery wall")
		check(child.arena_navigation==layout and child.spawn_impulse_remaining>0,"fragment loses navigation/birth cancellation guard")
	map.free()
	await process_frame
	var edge_arena := Node2D.new()
	root.add_child(edge_arena)
	var edge = actor(edge_arena)
	edge.world_bounds = Rect2(0,0,100,100)
	edge.position = Vector2(82,82)
	var edge_children: Array[CharacterBody2D] = []
	edge.offspring_prepared.connect(func(values): edge_children.assign(values))
	edge.take_damage(1000)
	await process_frame
	check(edge_children.size()==2,"edge ignores available safe inner births")
	for child in edge_children:
		child.set_physics_process(false)
		check(Rect2(9,9,82,82).has_point(child.global_position),"fragment born outside playable world")
	check(edge_children[0].global_position.distance_to(edge_children[1].global_position)>=22,"two fragments born overlapping")
	edge_arena.free()
	await process_frame
	if not failures: print("TEST PASS: SplittingMoteLifecycleTest %d" % checks)
	quit(1 if failures else 0)
