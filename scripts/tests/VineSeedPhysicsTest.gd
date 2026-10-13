extends SceneTree
const Seed = preload("res://scripts/components/VineSeedProjectile.gd")
class Target extends CharacterBody2D:
	var hits: Array[float] = []
	var stealthed := false
	func take_damage(amount: float,_source: StringName = &"") -> void: hits.append(amount)
	func is_stealthed() -> bool: return stealthed
var checks := 0
var failures := 0
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("TEST FAIL: VineSeedPhysicsTest "+label)
func circle_body(actor: CollisionObject2D,radius: float) -> void:
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = radius
	shape.shape = circle
	actor.add_child(shape)
func _initialize() -> void:
	await process_frame
	var host := Node2D.new()
	root.add_child(host)
	var target := Target.new()
	target.position = Vector2(200,100)
	target.add_to_group(&"player")
	circle_body(target,13)
	host.add_child(target)
	var owner := StaticBody2D.new()
	owner.position = Vector2(100,100)
	circle_body(owner,56)
	host.add_child(owner)
	await physics_frame
	await physics_frame
	var shot := Seed.new()
	shot.position = owner.position
	shot.source_actor_id = owner.get_instance_id()
	host.add_child(shot)
	shot.ignore_source(owner)
	check(owner.get_rid() in shot.sweep_query.exclude,"caster exclusion getter copy lost its change")
	shot.set_physics_process(false)
	check(shot.radius==6 and shot.sweep_shape.radius==6 and shot.get_child(0).shape.radius==6,"actual seed footprint disagrees")
	shot._physics_process(0.4)
	check(shot.is_queued_for_deletion() and target.hits==[18.0],"seed hits caster, tunnels or repeats real player damage")
	await process_frame
	owner.free()
	target.hits.clear()
	var wall := StaticBody2D.new()
	wall.position = Vector2(150,100)
	var shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(2,80)
	shape.shape = rectangle
	wall.add_child(shape)
	host.add_child(wall)
	await physics_frame
	await physics_frame
	for hz in [30,60,120]:
		var blocked := Seed.new()
		blocked.position = Vector2(100,100)
		host.add_child(blocked)
		blocked.set_physics_process(false)
		for _frame in hz:
			if blocked.is_queued_for_deletion(): break
			blocked._physics_process(1.0/hz)
		check(blocked.is_queued_for_deletion() and blocked.position.x<150 and target.hits.is_empty(),"thin terrain penetrated at "+str(hz)+"Hz")
		await process_frame
	var fast := Seed.new()
	fast.position = Vector2(100,100)
	host.add_child(fast)
	fast.set_physics_process(false)
	fast._physics_process(0.4)
	check(fast.is_queued_for_deletion() and fast.position.x<150 and target.hits.is_empty(),"large frame tunnels through wall to player")
	var overlap := Seed.new()
	overlap.position = wall.position
	host.add_child(overlap)
	overlap.set_physics_process(false)
	overlap._physics_process(0.01)
	check(overlap.is_queued_for_deletion(),"seed born in wall escapes initial overlap")
	wall.free()
	await physics_frame
	target.stealthed = true
	var hidden := Seed.new()
	hidden.position = Vector2(100,100)
	host.add_child(hidden)
	hidden.set_physics_process(false)
	hidden._physics_process(0.4)
	check(hidden.is_queued_for_deletion() and target.hits.is_empty(),"seed damages hidden player")
	host.free()
	if not failures: print("TEST PASS: VineSeedPhysicsTest %d"%checks)
	quit(1 if failures else 0)
