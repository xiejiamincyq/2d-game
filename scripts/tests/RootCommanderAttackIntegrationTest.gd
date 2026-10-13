extends SceneTree
const EnemySource = preload("res://scripts/actors/Enemy.gd")
class Target extends Node2D:
	var hits: Array[float] = []
	var stealthed := false
	func take_damage(amount: float) -> void: hits.append(amount)
	func is_stealthed() -> bool: return stealthed
var checks := 0
var failures := 0
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("TEST FAIL: RootCommanderAttackIntegrationTest "+label)
func _initialize() -> void:
	await process_frame
	var host := Node2D.new()
	root.add_child(host)
	var shots := Node2D.new()
	host.add_child(shots)
	var target := Target.new()
	target.position = Vector2(200,0)
	host.add_child(target)
	var actor := EnemySource.new()
	actor.setup(EnemySource.EnemyKind.OVERSEER,0,shots,target)
	host.add_child(actor)
	actor.set_physics_process(false)
	var view = actor.native_visual
	check(view.scene_file_path.ends_with("root_commander_paper_v2.tscn"),"actual commander not using new staff/core actions")
	if failures:
		host.free()
		quit(1)
		return
	check(actor.body_radius==40 and actor.health.max_health==1800 and actor.contact_damage==72 and is_equal_approx(actor.speed,46.2),"new action alters basic combat values")
	actor.shoot_cooldown = 0
	actor._physics_process(0.01)
	check(actor.ranged_is_winding_up and view.player.current_animation=="burst_warning" and actor.should_show_attack_marker(),"actual core windup/head warning absent")
	actor.take_damage(1)
	check(view.player.current_animation=="burst_warning","incoming fire hides active windup")
	target.position = Vector2(-200,0)
	actor._physics_process(0.25)
	check(view.get_node("Facing").scale.x==1,"windup flips back and forth")
	actor._physics_process(0.66)
	check(shots.get_child_count()==12 and view.player.current_animation=="burst_attack" and not actor.should_show_attack_marker(),"actual burst/action count mismatch")
	var origin: Vector2 = actor.native_motion.get_safe_core_origin(actor)
	check(origin.distance_to(actor.position)>1 and origin.distance_to(actor.position)<20,"burst still ignores actual core socket")
	for shot in shots.get_children():
		shot.set_physics_process(false)
		check(shot.global_position.is_equal_approx(origin) and shot.radius==5 and shot.damage==30 and is_equal_approx(shot.velocity.length(),310) and shot.lifetime==3,"actual emitter/numbers disagree")
	actor._update_static_motion(0.1)
	check(shots.get_child_count()==12,"visual sampling duplicates shots")
	target.position = actor.position+Vector2(20,0)
	actor._physics_process(0.1)
	check(not actor.is_attacking and view.player.current_animation=="burst_attack","melee interrupts explicit burst recovery")
	actor._physics_process(0.21)
	actor._physics_process(0.1)
	check(actor.is_attacking and view.player.current_animation=="melee_warning" and target.hits.is_empty(),"staff warning not driven by real melee")
	actor.shoot_cooldown = 0
	actor._physics_process(0.23)
	check(target.hits==[72.0] and not actor.ranged_is_winding_up and view.player.current_animation=="melee_attack","burst interrupts staff before hit or melee damage repeated")
	actor._physics_process(0.14)
	check(view.player.current_animation=="melee_recovery","staff recovery missing")
	target.stealthed = true
	actor._physics_process(0.05)
	check(not actor.is_attacking and not actor.attack_has_hit and not actor.ranged_is_winding_up and actor.overseer_burst_recovery_remaining==0,"hidden target retains armed action")
	var count: int = shots.get_child_count()
	actor._fire_overseer_burst()
	check(shots.get_child_count()==count,"hidden target can still trigger direct late emission")
	target.stealthed = false
	actor.shoot_cooldown = 0
	actor._physics_process(0.01)
	actor.apply_spawn_impulse(Vector2.ZERO,0.2)
	actor._physics_process(0.05)
	check(not actor.ranged_is_winding_up and view.player.current_animation=="entrance","birth retains old ranged windup")
	actor.spawn_impulse_remaining = 0
	var requests: Array[int] = []
	actor.reinforcements_requested.connect(func(_actor,count_value): requests.append(count_value))
	actor.health.current_health = 1100
	actor._request_boss_reinforcements_at_health_thresholds()
	actor._update_static_motion(0.1)
	check(view.player.current_animation=="command","reinforcement request has no seed-pack gesture")
	actor._request_boss_reinforcements_at_health_thresholds()
	actor.health.current_health = 500
	actor._request_boss_reinforcements_at_health_thresholds()
	actor._request_boss_reinforcements_at_health_thresholds()
	check(requests==[18,24],"new command animation changes/repeats thresholds")
	actor.world_bounds = Rect2(-100,actor.position.y-5,200,200)
	check(actor.native_motion.get_safe_core_origin(actor).is_equal_approx(actor.position),"core socket outside world has no safe fallback")
	actor.world_bounds = Rect2()
	var wall := StaticBody2D.new()
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(4,4)
	shape.shape = rect
	wall.add_child(shape)
	wall.position = actor.position+Vector2(0,-5)
	host.add_child(wall)
	await physics_frame
	check(actor.native_motion.get_safe_core_origin(actor).is_equal_approx(actor.position),"core emits through real wall")
	wall.free()
	var pose: Transform2D = view.skeleton.get_bone(0).transform
	actor._update_static_motion(NAN)
	check(view.skeleton.get_bone(0).transform==pose,"invalid delta changes pose")
	paused = true
	await process_frame
	await process_frame
	check(view.skeleton.get_bone(0).transform==pose,"paused commander runs independent animation")
	paused = false
	actor.shoot_cooldown = 0
	actor._physics_process(0.01)
	actor.take_damage(5000)
	check(view.player.current_animation=="death" and not actor.ranged_is_winding_up and not actor.is_attacking and actor.overseer_burst_recovery_remaining==0,"death retains armed action")
	actor._fire_overseer_burst()
	check(shots.get_child_count()==count,"death emits late burst")
	view.player.advance(1.2)
	await process_frame
	check(not is_instance_valid(view),"new commander corpse leaks")
	host.free()
	if not failures: print("TEST PASS: RootCommanderAttackIntegrationTest %d" % checks)
	quit(1 if failures else 0)
