extends SceneTree
const PATH := "res://scripts/components/CapsulePlantHazard.gd"
const ProjectileSource = preload("res://scripts/components/Projectile.gd")
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
		push_error("TEST FAIL: CapsulePlantHazardTest "+label)
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	check(ResourceLoader.exists(PATH),"persistent destructible capsule absent")
	if failures:
		quit(1)
		return
	var arena := Node2D.new()
	root.add_child(arena)
	var target := Target.new()
	target.position = Vector2(24,0)
	arena.add_child(target)
	var hazard = load(PATH).new()
	hazard.target_player = target
	arena.add_child(hazard)
	hazard.set_physics_process(false)
	check(hazard.health.current_health==16 and hazard.is_in_group("enemies"),"capsule cannot be targeted/destroyed")
	hazard._physics_process(0.54)
	check(target.hits.is_empty(),"capsule hurts during incubation")
	hazard._physics_process(0.02)
	check(target.hits.is_empty() and not hazard.resolved,"incubator retains obsolete ground pulse")
	hazard._physics_process(0.3)
	check(target.hits.is_empty(),"incubator deals damage every frame")
	hazard._physics_process(0.31)
	check(target.hits.is_empty(),"incubator retains obsolete repeat pulse")
	target.stealth_active = true
	hazard._physics_process(0.61)
	check(target.hits.is_empty(),"incubator attacks hidden player")
	target.stealth_active = false
	target.position = Vector2(33,0)
	hazard._physics_process(0.61)
	check(target.hits.is_empty(),"incubator has an invisible damage disk")
	var shot := ProjectileSource.new()
	shot.damage = 20
	arena.add_child(shot)
	shot.set_physics_process(false)
	shot._try_hit(hazard)
	check(hazard.resolved and not hazard.is_in_group("enemies"),"real player projectile does not disarm capsule")
	hazard._physics_process(0.61)
	check(target.hits.is_empty(),"destroyed capsule still attacks")
	await process_frame
	check(not is_instance_valid(hazard),"destroyed capsule leaks")
	var expiry = load(PATH).new()
	expiry.target_player = target
	arena.add_child(expiry)
	expiry.set_physics_process(false)
	expiry._physics_process(3.0)
	check(expiry.resolved and target.hits.is_empty(),"orphan capsule creates a catch-up attack")
	await process_frame
	check(not is_instance_valid(expiry),"expired capsule remains")
	# Incubation is harmless on either side of a real static wall.
	target.position = Vector2(24,0)
	var wall := StaticBody2D.new()
	wall.position = Vector2(12,0)
	var wall_shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(4,40)
	wall_shape.shape = rectangle
	wall.add_child(wall_shape)
	arena.add_child(wall)
	var blocked = load(PATH).new()
	blocked.target_player = target
	arena.add_child(blocked)
	blocked.set_physics_process(false)
	await physics_frame
	blocked._physics_process(0.56)
	check(not blocked.resolved and target.hits.is_empty(),"incubator hurts through a physical wall")
	blocked.disarm()
	arena.free()
	await process_frame
	if not failures: print("TEST PASS: CapsulePlantHazardTest %d" % checks)
	quit(1 if failures else 0)
