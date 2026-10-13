extends SceneTree
const PATH := "res://scripts/components/ShadeAmbushAttack.gd"
class Actor extends CharacterBody2D:
	var body_radius := 15.0
	var contact_damage := 18.0
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
		push_error("TEST FAIL: ShadeAmbushAttackTest "+label)
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	check(ResourceLoader.exists(PATH),"locked ordinary hook/short dash controller absent")
	if failures:
		quit(1)
		return
	var arena := Node2D.new()
	root.add_child(arena)
	var actor := Actor.new()
	arena.add_child(actor)
	var target := Target.new()
	target.position = Vector2(100,0)
	arena.add_child(target)
	await physics_frame
	var attack = load(PATH).new()
	attack.cooldown = 0
	attack.consider(actor,target,0)
	check(attack.stage==attack.Stage.WARNING and attack.move==attack.Move.POUNCE,"midrange target never starts telegraphed dash")
	attack.advance(0.17)
	attack.resolve_hit(actor,target)
	check(target.hits.is_empty() and attack.get_velocity()==Vector2.ZERO,"warning moves or damages")
	target.position = Vector2(100,60)
	attack.advance(0.02)
	check(attack.get_velocity().is_equal_approx(Vector2(500,0)),"dash homes after direction lock")
	actor.position = Vector2(80,0)
	attack.resolve_hit(actor,target)
	check(target.hits.is_empty(),"dash hits player outside locked corridor")
	target.position = Vector2(100,0)
	attack.resolve_hit(actor,target)
	attack.resolve_hit(actor,target)
	check(target.hits==[18.0],"actual contact is missing or repeat damaging")
	attack.finish_motion()
	check(attack.stage==attack.Stage.RECOVERY and attack.get_velocity()==Vector2.ZERO,"wall collision cannot terminate dash")
	attack.cancel()
	actor.position = Vector2.ZERO
	target.position = Vector2(35,0)
	attack.cooldown = 0
	attack.consider(actor,target,0)
	attack.advance(0.2)
	attack.resolve_hit(actor,target)
	check(attack.move==attack.Move.CLAW and target.hits==[18.0,18.0],"near target has no hook strike")
	attack.cancel()
	target.position = Vector2(35,0)
	attack.begin(actor,target,attack.Move.CLAW)
	target.position = Vector2(-35,0)
	attack.advance(0.2)
	attack.resolve_hit(actor,target)
	check(target.hits.size()==2,"hook turns to chase escaped target behind")
	attack.cancel()
	target.position = Vector2(56,0)
	attack.begin(actor,target,attack.Move.CLAW)
	attack.advance(0.2)
	attack.resolve_hit(actor,target)
	check(target.hits.size()==2,"hook reaches beyond visible 37px hook plus target body")
	attack.cancel()
	target.position = Vector2(35,0)
	var wall := StaticBody2D.new()
	wall.position = Vector2(18,0)
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(4,100)
	shape.shape = rect
	wall.add_child(shape)
	arena.add_child(wall)
	await physics_frame
	attack.begin(actor,target,attack.Move.CLAW)
	attack.advance(0.2)
	attack.resolve_hit(actor,target)
	check(target.hits.size()==2,"hook hits through real wall")
	wall.free()
	attack.cancel()
	target.stealth_active = true
	attack.begin(actor,target,attack.Move.CLAW)
	attack.advance(0.2)
	attack.resolve_hit(actor,target)
	check(target.hits.size()==2,"hook damages hidden target")
	attack.cancel()
	check(not attack.is_active() and attack.get_velocity()==Vector2.ZERO,"cancel leaves moving attack")
	arena.free()
	await process_frame
	if not failures: print("TEST PASS: ShadeAmbushAttackTest %d" % checks)
	quit(1 if failures else 0)
