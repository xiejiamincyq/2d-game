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
		push_error("TEST FAIL: CirclingShadeClockTest "+label)
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	var arena := Node2D.new()
	root.add_child(arena)
	var target := Target.new()
	target.position = Vector2(300,200)
	var collision := CollisionShape2D.new()
	collision.name = "PlayerCollision"
	var circle := CircleShape2D.new()
	circle.radius = 13
	collision.shape = circle
	target.add_child(collision)
	arena.add_child(target)
	var actor = Factory.create_actor(5,"circling_shade",0,arena,target)
	actor.position = Vector2(200,200)
	actor.world_bounds = Rect2(-600,-400,1400,1000)
	arena.add_child(actor)
	actor.basic_attack.cooldown = 0
	var deadline := Time.get_ticks_msec()+2000
	while not actor.should_show_attack_marker() and Time.get_ticks_msec()<deadline: await physics_frame
	check(actor.should_show_attack_marker() and target.hits.is_empty(),"real ambush lacks damage-free head warning")
	var before_position: Vector2 = actor.position
	var before_time: float = actor.basic_attack.elapsed
	paused = true
	await create_timer(0.05,true,false,true).timeout
	check(actor.position.is_equal_approx(before_position) and is_equal_approx(actor.basic_attack.elapsed,before_time),"paused real ambush moves/advances")
	paused = false
	while target.hits.is_empty() and Time.get_ticks_msec()<deadline: await physics_frame
	check(target.hits==[18.0] and actor.position.x>=270 and actor.position.x<300,"real collision dash fails to reach target or teleports through it")
	check(actor.native_visual.player.current_animation=="attack","actual dash lacks new attack pose")
	actor.take_damage(1000)
	await process_frame
	await process_frame
	target.position = Vector2(300,400)
	target.hits.clear()
	var wall := StaticBody2D.new()
	wall.position = Vector2(250,400)
	var wall_collision := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(8,100)
	wall_collision.shape = rectangle
	wall.add_child(wall_collision)
	arena.add_child(wall)
	await physics_frame
	var blocked = Factory.create_actor(5,"circling_shade",0,arena,target)
	blocked.position = Vector2(200,400)
	blocked.world_bounds = Rect2(-600,-400,1400,1000)
	arena.add_child(blocked)
	blocked.basic_attack.cooldown = 0
	deadline = Time.get_ticks_msec()+2000
	while blocked.basic_attack.stage!=blocked.basic_attack.Stage.RECOVERY and Time.get_ticks_msec()<deadline: await physics_frame
	check(blocked.basic_attack.stage==blocked.basic_attack.Stage.RECOVERY and blocked.position.x<=231.1 and blocked.position.x>220,"real terrain does not stop dash at body margin")
	check(target.hits.is_empty(),"wall-blocked real dash damages through obstacle")
	blocked.take_damage(1000)
	await process_frame
	await process_frame
	arena.free()
	await process_frame
	if not failures: print("TEST PASS: CirclingShadeClockTest %d" % checks)
	quit(1 if failures else 0)
