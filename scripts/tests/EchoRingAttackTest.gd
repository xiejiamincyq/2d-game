extends SceneTree
const PATH := "res://scripts/components/EchoRingAttack.gd"
class Actor extends CharacterBody2D:
	var body_radius := 14.0
	var contact_damage := 15.0
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
		push_error("TEST FAIL: EchoRingAttackTest "+label)
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	check(ResourceLoader.exists(PATH),"expanding once-hit ring controller absent")
	if failures:
		quit(1)
		return
	var arena := Node2D.new()
	root.add_child(arena)
	var actor := Actor.new()
	arena.add_child(actor)
	var target := Target.new()
	target.position = Vector2(80,0)
	var shape := CollisionShape2D.new()
	shape.name = "PlayerCollision"
	var circle := CircleShape2D.new()
	circle.radius = 13
	shape.shape = circle
	target.add_child(shape)
	arena.add_child(target)
	await physics_frame
	var attack = load(PATH).new()
	check(attack.has_method("is_ring_visible"),"final expanding step has no shared visibility contract")
	if failures:
		arena.free()
		quit(1)
		return
	attack.begin(actor,target,attack.Move.CLAW)
	attack.advance(0.17)
	attack.resolve_hit(actor,target)
	check(target.hits.is_empty() and attack.stage==attack.Stage.WARNING,"ring damages before short head warning")
	attack.advance(0.05)
	attack.resolve_hit(actor,target)
	check(target.hits.is_empty() and attack.radius>0 and attack.radius<20,"wave teleports to max radius")
	attack.advance(0.2)
	attack.resolve_hit(actor,target)
	check(target.hits==[15.0],"swept expanding rim misses crossed player")
	for index in 4:
		attack.advance(0.02)
		attack.resolve_hit(actor,target)
	check(target.hits==[15.0],"single wave hits same target repeatedly")
	attack.cancel()
	target.position = Vector2(184,0)
	attack.begin(actor,target,attack.Move.CLAW)
	attack.advance(0.66)
	attack.resolve_hit(actor,target)
	check(target.hits.size()==1,"outer target hit before rim reached it")
	attack.advance(0.03)
	attack.resolve_hit(actor,target)
	check(target.hits.size()==2 and attack.stage==attack.Stage.RECOVERY and attack.is_ring_visible(),"outer-rim hit is invisible at active/recovery boundary")
	attack.advance(0.02)
	check(not attack.is_ring_visible(),"spent maximum rim lingers through recovery")
	attack.cancel()
	target.position = Vector2(400,0)
	attack.begin(actor,target,attack.Move.CLAW)
	attack.advance(0.28)
	attack.resolve_hit(actor,target)
	target.position = Vector2(10,0)
	attack.advance(0.05)
	attack.resolve_hit(actor,target)
	check(target.hits.size()==2,"hollow wave treats behind-rim player as filled disk")
	attack.cancel()
	target.position = Vector2(80,0)
	attack.begin(actor,target,attack.Move.CLAW)
	actor.position = Vector2(100,0)
	attack.advance(0.42)
	attack.resolve_hit(actor,target)
	check(target.hits==[15.0,15.0,15.0] and attack.origin==Vector2.ZERO,"crowd displacement drags wave origin")
	attack.cancel()
	actor.position = Vector2.ZERO
	target.position = Vector2(80,0)
	var wall := StaticBody2D.new()
	wall.position = Vector2(40,0)
	var wall_shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(6,300)
	wall_shape.shape = rectangle
	wall.add_child(wall_shape)
	arena.add_child(wall)
	await physics_frame
	attack.begin(actor,target,attack.Move.CLAW)
	attack.advance(0.42)
	attack.resolve_hit(actor,target)
	check(target.hits.size()==3,"ring damages through physical wall")
	wall.free()
	attack.cancel()
	target.stealth_active = true
	attack.begin(actor,target,attack.Move.CLAW)
	attack.advance(0.42)
	attack.resolve_hit(actor,target)
	check(target.hits.size()==3,"ring hits hidden target")
	attack.cancel()
	check(attack.radius==0 and not attack.is_active() and attack.get_velocity()==Vector2.ZERO,"cancel retains ring/motion")
	arena.free()
	await process_frame
	if not failures: print("TEST PASS: EchoRingAttackTest %d" % checks)
	quit(1 if failures else 0)
