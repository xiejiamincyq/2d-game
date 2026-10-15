extends SceneTree
const Factory = preload("res://scripts/campaign/RegionalEnemyFactory.gd")
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
		push_error("TEST FAIL: RiftEliteIntegrationTest "+label)
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	var arena := Node2D.new()
	root.add_child(arena)
	var shots := Node2D.new()
	arena.add_child(shots)
	var target := Target.new()
	target.position = Vector2(340,200)
	arena.add_child(target)
	var actor = Factory.create_actor(6,"rift_elite",0,shots,target)
	check(actor!=null,"sixth-region hybrid ordinary actor absent")
	if actor==null:
		arena.free()
		quit(1)
		return
	actor.position = Vector2(200,200)
	actor.world_bounds = Rect2(-600,-400,1400,1000)
	arena.add_child(actor)
	actor.set_physics_process(false)
	check(actor.native_visual.skeleton.get_bone_count()==20 and actor.static_visual==null,"actor still raster/placeholder")
	check(actor.body_radius<24 and actor.should_show_health_bar() and actor.scale==Vector2.ONE,"ordinary body/bar/root contract broken")
	actor.basic_attack.cooldown = 0
	actor._physics_process(0.01)
	check(actor.should_show_attack_marker() and actor.native_visual.player.current_animation=="warning" and shots.get_child_count()==0,"shards ignore head warning")
	actor._physics_process(0.16)
	check(shots.get_child_count()==0,"shards released too early")
	target.position = Vector2(200,340)
	actor._physics_process(actor.basic_attack.get_warning_duration()-actor.basic_attack.elapsed+0.01)
	check(shots.get_child_count()==2 and actor.native_visual.player.current_animation=="shard_attack","dual emission missing/new clip absent")
	if shots.get_child_count()!=2:
		arena.free()
		quit(1)
		return
	for shot in shots.get_children():
		shot.set_physics_process(false)
		var locked: Vector2 = shot.global_position.direction_to(actor.basic_attack.target_position)
		check(shot.get_script().resource_path=="res://scripts/components/RiftShardProjectile.gd" and is_equal_approx(shot.velocity.length(),320) and is_equal_approx(shot.velocity.normalized().dot(locked),cos(deg_to_rad(12))) and actor.basic_attack.target_position==Vector2(340,200) and shot.damage==12,"shard old visual/homes/incorrect damage")
	check(shots.get_child(0).velocity.cross(shots.get_child(1).velocity)>0,"paired shards overlap rather than diverge")
	var wall := StaticBody2D.new()
	var wall_shape := CollisionShape2D.new()
	var wall_rect := RectangleShape2D.new()
	wall_rect.size = Vector2(4,100)
	wall_shape.shape = wall_rect
	wall.add_child(wall_shape)
	wall.position = Vector2(225,185)
	arena.add_child(wall)
	await physics_frame
	await physics_frame
	check(actor.native_motion.get_safe_muzzle(actor).is_equal_approx(actor.global_position),"bone emitter passes through nearby wall")
	wall.free()
	var saved_bounds: Rect2 = actor.world_bounds
	actor.world_bounds = Rect2(actor.position-Vector2(18,18),Vector2(36,36))
	check(actor.native_motion.get_safe_muzzle(actor).is_equal_approx(actor.global_position),"emitter goes outside projectile-safe world bounds")
	actor.world_bounds = saved_bounds
	actor._update_spitter(0,target)
	check(shots.get_child_count()==2,"dual emission repeated in same activation")
	actor.basic_attack.cancel()
	actor.basic_attack.cooldown = 0
	target.position = actor.position+Vector2(35,0)
	actor._physics_process(0.01)
	actor._physics_process(actor.basic_attack.get_warning_duration())
	check(target.hits==[24.0] and actor.native_visual.player.current_animation=="attack" and shots.get_child_count()==2,"close sweep lacks unique hit or also emits")
	actor._update_spitter(0,target)
	check(target.hits==[24.0],"two blades stack repeated hits")
	actor.basic_attack.cancel()
	actor.basic_attack.cooldown = 0
	target.position = actor.position+Vector2(140,0)
	actor._physics_process(0.01)
	target.stealth_active = true
	actor._physics_process(0.2)
	check(not actor.basic_attack.is_active() and shots.get_child_count()==2,"hidden target leaves stale emission")
	target.stealth_active = false
	actor.basic_attack.cooldown = 0
	actor._physics_process(0.01)
	actor.apply_spawn_impulse(Vector2.ZERO,0.1)
	actor._physics_process(0.2)
	check(not actor.basic_attack.is_active() and shots.get_child_count()==2,"spawn guard fails to cancel")
	actor.spawn_impulse_remaining = 0
	var observed := [false]
	actor.died.connect(func(_actor,_coins,_source): observed[0]=not actor.basic_attack.is_active())
	actor.take_damage(1000)
	check(observed[0],"death notification retains active hybrid attack")
	await process_frame
	await process_frame
	arena.free()
	await process_frame
	if not failures: print("TEST PASS: RiftEliteIntegrationTest %d" % checks)
	quit(1 if failures else 0)
