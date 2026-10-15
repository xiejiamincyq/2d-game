extends SceneTree
## Real engine actor steering/attack; nursery collider is a compatibility fixture,
## not a third-chapter map or human/normal-input completion evidence.
const Factory = preload("res://scripts/campaign/RegionalEnemyFactory.gd")
class CountingLayout extends "res://scripts/world/NurseryArenaLayout.gd":
	var builds := 0
	func _build_flow_field(goal: Vector2i,radius: float) -> Dictionary:
		builds += 1
		return super._build_flow_field(goal,radius)
class Target extends Node2D:
	var hits: Array[float] = []
	func take_damage(amount: float) -> void: hits.append(amount)
var checks := 0
var failures := 0
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("TEST FAIL: FlankingCrabMotionTest "+label)
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	Engine.max_fps = 60
	await process_frame
	var arena := Node2D.new()
	root.add_child(arena)
	var target := Target.new()
	target.position = Vector2(180,0)
	arena.add_child(target)
	var crab = Factory.create_actor(3,"flanking_crab",0,arena,target)
	crab.formation_slot_index = 0
	crab.world_bounds = Rect2(-650,-450,1300,900)
	arena.add_child(crab)
	var started := Time.get_ticks_usec()
	var warning_at := 0
	var moves := 0
	var max_side := 0.0
	var before: Vector2 = crab.position
	while target.hits.is_empty() and Time.get_ticks_usec()-started<5000000:
		await process_frame
		moves += 1 if crab.position.distance_to(before)>0.01 else 0
		before = crab.position
		max_side = maxf(max_side,absf(crab.position.y))
		if warning_at==0 and crab.should_show_attack_marker(): warning_at = Time.get_ticks_usec()
	check(moves>30 and max_side>20,"actual engine flanker does not scuttle around target")
	check(target.hits==[21.0] and warning_at>0,"actual engine never closes for unique pincer")
	if not target.hits.is_empty() and warning_at>0:
		var seconds := (Time.get_ticks_usec()-warning_at)/1000000.0
		var expected: float = crab.basic_attack.get_warning_duration()
		check(seconds>=expected-0.035 and seconds<=expected+0.07,"engine pincer warning stalls or has second clock")
		print("FlankingCrabMotionTest actual_warning=%.6f" % seconds)
	arena.free()
	await process_frame
	var query_arena := Node2D.new()
	root.add_child(query_arena)
	var counted := CountingLayout.new()
	query_arena.add_child(counted)
	counted.generate_map(521)
	var rect: Rect2 = counted.get_obstacle_descriptors()[0].rect
	var common_goal := Vector2(rect.end.x+100,rect.get_center().y)
	counted.builds = 0
	for index in 12:
		var subject = Factory.create_actor(3,"flanking_crab",0,query_arena)
		subject.position = Vector2(rect.position.x-35,rect.get_center().y-55+index*10)
		subject.world_bounds = counted.world_bounds
		subject.set_arena_navigation(counted)
		query_arena.add_child(subject)
		subject.set_physics_process(false)
		var wanted: Vector2 = subject._get_melee_desired_velocity(common_goal-subject.position)
		subject._apply_arena_navigation(wanted,common_goal)
	check(counted.builds==1,"blocked same-target crab crowd does not share one real flow grid")
	print("FlankingCrabMotionTest real shared flow builds=",counted.builds)
	query_arena.free()
	await process_frame
	# Exercise real existing map navigation/physical obstacles without new map claims.
	var map = load("res://scenes/world/mist_nursery.tscn").instantiate()
	map.map_seed = 521
	root.add_child(map)
	var layout = map.get_node("Layout")
	var obstacle: Rect2 = layout.get_obstacle_descriptors()[0].rect
	var receiver := Target.new()
	receiver.position = layout.resolve_spawn_position(Vector2(obstacle.end.x+100,obstacle.get_center().y),16)
	map.add_child(receiver)
	var walker = Factory.create_actor(3,"flanking_crab",0,map,receiver)
	walker.position = layout.resolve_spawn_position(Vector2(obstacle.position.x-100,obstacle.get_center().y),16)
	walker.world_bounds = layout.world_bounds
	walker.set_arena_navigation(layout)
	map.add_child(walker)
	var old_scale := Engine.time_scale
	Engine.time_scale = 4
	var initial_distance: float = walker.position.distance_to(receiver.position)
	var crossing_moves := 0
	before = walker.position
	for frame in 480:
		await physics_frame
		await process_frame
		crossing_moves += 1 if walker.position.distance_to(before)>0.01 else 0
		before = walker.position
		# Rounded collider and conservative rectangular path clearance differ at corners.
		check(not obstacle.grow(-1).has_point(walker.position),"actual crab crosses obstacle interior")
		if not receiver.hits.is_empty(): break
	check(crossing_moves>30 and walker.position.distance_to(receiver.position)<initial_distance-100,"real terrain/nav flanker stalls behind obstacle")
	check(not receiver.hits.is_empty(),"actual navigated crab never reaches pincer range")
	Engine.time_scale = old_scale
	map.queue_free()
	await process_frame
	await process_frame
	check(not is_instance_valid(map),"actual motion fixture leaks")
	if not failures:
		print("TEST PASS: FlankingCrabMotionTest %d" % checks)
	quit(1 if failures else 0)
