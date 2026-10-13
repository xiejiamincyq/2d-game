extends SceneTree
const Factory = preload("res://scripts/campaign/RegionalEnemyFactory.gd")
class Target extends CharacterBody2D:
	var hits: Array[float] = []
	func take_damage(amount: float) -> void: hits.append(amount)
	func is_stealthed() -> bool: return false
var checks := 0
var failures := 0
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("TEST FAIL: SpaceCutterClockTest "+label)
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	var arena := Node2D.new()
	root.add_child(arena)
	var target := Target.new()
	target.position = Vector2(330,200)
	var shape := CollisionShape2D.new()
	shape.name = "PlayerCollision"
	var circle := CircleShape2D.new()
	circle.radius = 13
	shape.shape = circle
	target.add_child(shape)
	arena.add_child(target)
	var actor = Factory.create_actor(6,"space_cutter",0,arena,target)
	actor.position = Vector2(200,200)
	actor.world_bounds = Rect2(-600,-400,1400,1000)
	arena.add_child(actor)
	actor.basic_attack.cooldown = 0
	var deadline := Time.get_ticks_msec()+1800
	while not actor.should_show_attack_marker() and Time.get_ticks_msec()<deadline: await physics_frame
	check(actor.should_show_attack_marker() and target.hits.is_empty(),"real cut lacks damage-free short warning")
	var at: Vector2 = actor.position
	var elapsed: float = actor.basic_attack.elapsed
	paused = true
	await create_timer(0.05,true,false,true).timeout
	check(actor.position.is_equal_approx(at) and is_equal_approx(actor.basic_attack.elapsed,elapsed),"paused cut advances")
	paused = false
	while target.hits.is_empty() and Time.get_ticks_msec()<deadline: await physics_frame
	check(target.hits==[21.0] and actor.position.is_equal_approx(at),"real cut misses/repeats/skates")
	check(actor.native_visual.player.current_animation=="attack" and actor.basic_attack.line_end.distance_to(actor.basic_attack.origin)>169,"real cut stops at player instead of terrain/end")
	var corpse = actor.native_visual
	actor.take_damage(1000)
	await process_frame
	await process_frame
	deadline = Time.get_ticks_msec()+1200
	while is_instance_valid(corpse) and Time.get_ticks_msec()<deadline: await physics_frame
	check(not is_instance_valid(corpse),"real terminal corpse never ends")
	target.hits.clear()
	target.position = Vector2(330,400)
	var wall := StaticBody2D.new()
	wall.position = Vector2(260,400)
	var wall_shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(8,100)
	wall_shape.shape = rectangle
	wall.add_child(wall_shape)
	arena.add_child(wall)
	await physics_frame
	await physics_frame
	var blocked = Factory.create_actor(6,"space_cutter",0,arena,target)
	blocked.position = Vector2(200,400)
	blocked.world_bounds = Rect2(-600,-400,1400,1000)
	arena.add_child(blocked)
	blocked.basic_attack.cooldown = 0
	deadline = Time.get_ticks_msec()+1800
	while blocked.basic_attack.stage!=blocked.basic_attack.Stage.RECOVERY and Time.get_ticks_msec()<deadline: await physics_frame
	check(blocked.basic_attack.stage==blocked.basic_attack.Stage.RECOVERY and blocked.basic_attack.line_end.x<=256.1 and target.hits.is_empty(),"real cut penetrates registered wall")
	blocked.take_damage(1000)
	await process_frame
	await process_frame
	arena.free()
	await process_frame
	if not failures: print("TEST PASS: SpaceCutterClockTest %d" % checks)
	quit(1 if failures else 0)
