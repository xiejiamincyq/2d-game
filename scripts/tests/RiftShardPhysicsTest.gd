extends SceneTree
const PATH := "res://scripts/components/RiftShardProjectile.gd"
class Target extends CharacterBody2D:
	var hits: Array[float] = []
	var stealth_active := false
	func take_damage(amount: float,_source: StringName = &"") -> void: hits.append(amount)
	func is_stealthed() -> bool: return stealth_active
var checks := 0
var failures := 0
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("TEST FAIL: RiftShardPhysicsTest "+label)
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	check(ResourceLoader.exists(PATH),"original opaque shard with terrain impact absent")
	if failures:
		quit(1)
		return
	var arena := Node2D.new()
	root.add_child(arena)
	var target := Target.new()
	target.position = Vector2(200,200)
	target.add_to_group("player")
	var collision := CollisionShape2D.new()
	collision.name = "PlayerCollision"
	var circle := CircleShape2D.new()
	circle.radius = 13
	collision.shape = circle
	target.add_child(collision)
	arena.add_child(target)
	await physics_frame
	var shot = load(PATH).new()
	shot.position = Vector2(100,200)
	arena.add_child(shot)
	var deadline := Time.get_ticks_msec()+1600
	while is_instance_valid(shot) and Time.get_ticks_msec()<deadline: await physics_frame
	check(not is_instance_valid(shot) and target.hits==[12.0],"actual shard misses/duplicates player or never ends")
	target.hits.clear()
	var wall := StaticBody2D.new()
	wall.position = Vector2(150,200)
	var wall_shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(8,90)
	wall_shape.shape = rectangle
	wall.add_child(wall_shape)
	arena.add_child(wall)
	await physics_frame
	await physics_frame
	var query := PhysicsRayQueryParameters2D.create(Vector2(100,200),Vector2(190,200),1)
	check(wall.get_world_2d().direct_space_state.intersect_ray(query).get("collider")==wall,"fixture wall absent from actual physics space")
	var blocked = load(PATH).new()
	blocked.position = Vector2(100,200)
	arena.add_child(blocked)
	deadline = Time.get_ticks_msec()+1600
	while is_instance_valid(blocked) and Time.get_ticks_msec()<deadline: await physics_frame
	check(not is_instance_valid(blocked) and target.hits.is_empty(),"real terrain lets shard penetrate")
	var fast = load(PATH).new()
	fast.position = Vector2(100,200)
	arena.add_child(fast)
	fast.set_physics_process(false)
	fast._physics_process(0.35)
	check(fast.is_queued_for_deletion() and fast.position.x<145 and target.hits.is_empty(),"large-step first wall impact tunnels to player")
	var overlap = load(PATH).new()
	overlap.position = Vector2(150,200)
	arena.add_child(overlap)
	overlap.set_physics_process(false)
	overlap._physics_process(0.016)
	check(overlap.is_queued_for_deletion() and target.hits.is_empty(),"blocked shard birth escapes cast-motion overlap omission")
	await process_frame
	wall.free()
	target.hits.clear()
	target.stealth_active = true
	var hidden_shot = load(PATH).new()
	hidden_shot.position = Vector2(100,200)
	arena.add_child(hidden_shot)
	deadline = Time.get_ticks_msec()+1600
	while is_instance_valid(hidden_shot) and Time.get_ticks_msec()<deadline: await physics_frame
	check(not is_instance_valid(hidden_shot) and target.hits.is_empty(),"shard hits stealthed body")
	var paused_shot = load(PATH).new()
	paused_shot.position = Vector2(100,350)
	arena.add_child(paused_shot)
	await physics_frame
	var before: Vector2 = paused_shot.position
	var before_life: float = paused_shot.lifetime
	paused = true
	await create_timer(0.05,true,false,true).timeout
	check(paused_shot.position==before and is_equal_approx(paused_shot.lifetime,before_life),"paused shard moves/ages")
	paused = false
	deadline = Time.get_ticks_msec()+1600
	while is_instance_valid(paused_shot) and Time.get_ticks_msec()<deadline: await physics_frame
	check(not is_instance_valid(paused_shot),"missed shard has unbounded lifetime")
	arena.free()
	await process_frame
	if not failures: print("TEST PASS: RiftShardPhysicsTest %d" % checks)
	quit(1 if failures else 0)
