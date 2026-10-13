extends SceneTree
const Factory = preload("res://scripts/campaign/RegionalEnemyFactory.gd")
class Target extends CharacterBody2D:
	var hits: Array[float] = []
	func take_damage(amount: float,_source: StringName = &"") -> void: hits.append(amount)
	func is_stealthed() -> bool: return false
var checks := 0
var failures := 0
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("TEST FAIL: RiftEliteClockTest "+label)
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	var arena := Node2D.new()
	root.add_child(arena)
	var shots := Node2D.new()
	arena.add_child(shots)
	var target := Target.new()
	target.position = Vector2(340,200)
	target.add_to_group("player")
	var collision := CollisionShape2D.new()
	collision.name = "PlayerCollision"
	var circle := CircleShape2D.new()
	circle.radius = 13
	collision.shape = circle
	target.add_child(collision)
	arena.add_child(target)
	var actor = Factory.create_actor(6,"rift_elite",0,shots,target)
	check(actor!=null,"real hybrid factory absent")
	if actor==null:
		arena.free()
		quit(1)
		return
	actor.position = Vector2(200,200)
	actor.world_bounds = Rect2(-600,-400,1400,1000)
	arena.add_child(actor)
	actor.basic_attack.cooldown = 0
	var emitted := [0]
	shots.child_entered_tree.connect(func(child):
		if child.get_script().resource_path=="res://scripts/components/RiftShardProjectile.gd": emitted[0]+=1)
	var deadline := Time.get_ticks_msec()+2000
	while not actor.should_show_attack_marker() and Time.get_ticks_msec()<deadline: await physics_frame
	check(actor.should_show_attack_marker() and target.hits.is_empty() and emitted[0]==0,"real release lacks damage-free head warning")
	var at: Vector2 = actor.position
	var elapsed: float = actor.basic_attack.elapsed
	paused = true
	await create_timer(0.05,true,false,true).timeout
	check(actor.position.is_equal_approx(at) and is_equal_approx(elapsed,actor.basic_attack.elapsed) and emitted[0]==0,"pause advances warning/emission")
	paused = false
	while emitted[0]==0 and Time.get_ticks_msec()<deadline: await physics_frame
	check(emitted[0]==2 and actor.basic_attack.elapsed>=0.18 and actor.basic_attack.stage==actor.basic_attack.Stage.ACTIVE,"actual physics fails dual release timing")
	check(actor.native_visual.player.current_animation=="shard_attack" and actor.position.is_equal_approx(at),"release pose missing or firing body skates")
	var corpse = actor.native_visual
	actor.take_damage(1000)
	await process_frame
	await process_frame
	deadline = Time.get_ticks_msec()+1200
	while is_instance_valid(corpse) and Time.get_ticks_msec()<deadline: await physics_frame
	check(not is_instance_valid(corpse) and emitted[0]==2,"death fails terminal cleanup or emits again")
	arena.free()
	await process_frame
	if not failures: print("TEST PASS: RiftEliteClockTest %d" % checks)
	quit(1 if failures else 0)
