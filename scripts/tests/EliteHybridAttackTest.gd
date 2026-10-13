extends SceneTree
const PATH := "res://scripts/components/EliteHybridAttack.gd"
class Actor extends CharacterBody2D:
	var contact_damage := 24.0
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
		push_error("TEST FAIL: EliteHybridAttackTest "+label)
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	check(ResourceLoader.exists(PATH),"ordinary two-mode controller absent")
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
	check(attack.stage==attack.Stage.WARNING and attack.mode==attack.Mode.SHARDS,"ranged mode lacks locked warning")
	attack.advance(0.17)
	check(not attack.take_release(),"shards released during warning")
	target.position = Vector2(-120,0)
	attack.advance(0.02)
	check(attack.direction==Vector2.RIGHT and attack.take_release() and not attack.take_release(),"locked shard release missing/repeated/homing")
	check("target_position" in attack and attack.target_position==Vector2(120,0),"bone muzzle lacks original locked target point")
	attack.cancel()
	check(not attack.is_active() and not attack.take_release(),"cancel retains release")
	target.position = Vector2(35,0)
	attack.cooldown = 0
	attack.consider(actor,target,0)
	attack.advance(0.17)
	attack.resolve_hit(actor,target)
	check(target.hits.is_empty() and attack.mode==attack.Mode.SWEEP,"nearby double blade ignores warning")
	attack.advance(0.02)
	attack.resolve_hit(actor,target)
	attack.resolve_hit(actor,target)
	check(target.hits==[24.0] and not attack.take_release(),"double blade stacks damage or also shoots")
	attack.cancel()
	target.position = Vector2(35,0)
	attack.cooldown = 0
	attack.consider(actor,target,0)
	target.position = Vector2(-35,0)
	attack.advance(0.20)
	attack.resolve_hit(actor,target)
	check(target.hits.size()==1,"sweep tracks escaped target behind")
	attack.cancel()
	target.position = Vector2(35,0)
	var wall := StaticBody2D.new()
	wall.position = Vector2(18,0)
	var collision := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(4,90)
	collision.shape = rectangle
	wall.add_child(collision)
	arena.add_child(wall)
	await physics_frame
	attack.cooldown = 0
	attack.consider(actor,target,0)
	attack.advance(0.2)
	attack.resolve_hit(actor,target)
	check(target.hits.size()==1,"cross blades hit through terrain")
	wall.free()
	attack.cancel()
	target.stealth_active = true
	attack.cooldown = 0
	attack.consider(actor,target,0)
	attack.advance(0.2)
	attack.resolve_hit(actor,target)
	check(target.hits.size()==1,"cross blades hit hidden target")
	attack.cancel()
	attack.cooldown = 0
	target.stealth_active = false
	target.position = Vector2(400,0)
	attack.consider(actor,target,0)
	check(not attack.is_active(),"off-range enemy starts futile fire")
	arena.free()
	await process_frame
	if not failures: print("TEST PASS: EliteHybridAttackTest %d" % checks)
	quit(1 if failures else 0)
