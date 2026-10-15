extends SceneTree
const PATH := "res://scripts/components/SpaceCutAttack.gd"
class Actor extends CharacterBody2D:
	var contact_damage := 21.0
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
		push_error("TEST FAIL: SpaceCutAttackTest "+label)
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	check(ResourceLoader.exists(PATH),"sixth-region locked thin cut absent")
	if failures:
		quit(1)
		return
	var arena := Node2D.new()
	root.add_child(arena)
	var actor := Actor.new()
	arena.add_child(actor)
	var target := Target.new()
	target.position = Vector2(120,0)
	arena.add_child(target)
	await physics_frame
	var attack = load(PATH).new()
	attack.cooldown = 0
	attack.consider(actor,target,0)
	attack.advance(attack.get_warning_duration()-0.01)
	attack.resolve_hit(actor,target)
	check(attack.stage==attack.Stage.WARNING and target.hits.is_empty(),"thin cut hits during short head warning")
	attack.advance(0.02)
	attack.resolve_hit(actor,target)
	attack.resolve_hit(actor,target)
	check(target.hits==[21.0] and attack.stage==attack.Stage.ACTIVE,"locked cut missing or repeats damage")
	check(attack.origin==Vector2.ZERO and attack.direction==Vector2.RIGHT and attack.line_end==Vector2(170,0),"cut origin/direction/reach inconsistent")
	attack.cancel()
	target.hits.clear()
	attack.cooldown = 0
	attack.consider(actor,target,0)
	target.position = Vector2(0,120)
	attack.advance(attack.get_warning_duration()+0.01)
	attack.resolve_hit(actor,target)
	check(target.hits.is_empty() and attack.direction==Vector2.RIGHT,"cut homes toward escaped player")
	target.position = Vector2(120,0)
	attack.resolve_hit(actor,target)
	check(target.hits==[21.0],"player entering live locked cut is not hit")
	attack.cancel()
	target.hits.clear()
	var wall := StaticBody2D.new()
	wall.position = Vector2(80,0)
	var collision := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(8,100)
	collision.shape = rectangle
	wall.add_child(collision)
	arena.add_child(wall)
	await physics_frame
	await physics_frame
	attack.cooldown = 0
	attack.consider(actor,target,0)
	attack.advance(attack.get_warning_duration()+0.01)
	attack.resolve_hit(actor,target)
	check(target.hits.is_empty() and attack.line_end.x<=76.1 and attack.line_end.x>70,"terrain does not clip visible cut/hits through wall")
	target.position = Vector2(35,0)
	attack.resolve_hit(actor,target)
	check(target.hits==[21.0],"terrain-truncated cut cannot hit before wall")
	wall.free()
	attack.cancel()
	target.hits.clear()
	target.stealth_active = true
	attack.cooldown = 0
	attack.consider(actor,target,0)
	attack.advance(attack.get_warning_duration()+0.01)
	attack.resolve_hit(actor,target)
	check(target.hits.is_empty() and not attack.is_active(),"hidden target still starts or takes cut")
	target.stealth_active = false
	target.position = Vector2(350,0)
	attack.cooldown = 0
	attack.consider(actor,target,0)
	check(not attack.is_active(),"off-range cut starts")
	target.position = Vector2(186,0)
	attack.cooldown = 0
	attack.consider(actor,target,0)
	attack.advance(attack.get_warning_duration()+0.01)
	attack.resolve_hit(actor,target)
	check(target.hits.is_empty(),"cut hits beyond visible reach plus real body radius")
	attack.cancel()
	check(not attack.is_active(),"cancel leaves active line")
	arena.free()
	await process_frame
	if not failures: print("TEST PASS: SpaceCutAttackTest %d" % checks)
	quit(1 if failures else 0)
