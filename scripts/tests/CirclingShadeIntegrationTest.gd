extends SceneTree
const Factory = preload("res://scripts/campaign/RegionalEnemyFactory.gd")
class Target extends Node2D:
	var stealth_active := false
	var hits: Array[float] = []
	func take_damage(amount: float) -> void: hits.append(amount)
	func is_stealthed() -> bool: return stealth_active
var checks := 0
var failures := 0
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("TEST FAIL: CirclingShadeIntegrationTest "+label)
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	var arena := Node2D.new()
	root.add_child(arena)
	var target := Target.new()
	target.position = Vector2(300,200)
	arena.add_child(target)
	var actor = Factory.create_actor(5,"circling_shade",0,arena,target)
	check(actor!=null,"fifth-region second original actor absent")
	if actor==null:
		arena.free()
		quit(1)
		return
	actor.position = Vector2(200,200)
	actor.world_bounds = Rect2(-600,-400,1400,1000)
	arena.add_child(actor)
	actor.set_physics_process(false)
	check(actor.native_visual.skeleton.get_bone_count()==18 and actor.static_visual==null,"actor still raster/placeholder")
	check(actor.should_show_health_bar() and actor._uses_flocking() and actor.scale==Vector2.ONE,"healthy bar/social steering/root contract broken")
	actor.formation_slot_index = 0
	var left: Vector2 = actor._get_melee_desired_velocity(Vector2(250,0))
	actor.formation_slot_index = 1
	var right: Vector2 = actor._get_melee_desired_velocity(Vector2(250,0))
	check(left.x>0.3 and right.x>0.3 and left.y< -0.6 and right.y>0.6,"all shadows pursue straight line")
	check(actor._get_melee_desired_velocity(Vector2(600,0)).x>0.99,"distant shade endlessly orbits")
	actor.basic_attack.cooldown = 0
	actor._physics_process(0.01)
	check(actor.should_show_attack_marker() and actor.native_visual.player.current_animation=="warning" and target.hits.is_empty(),"short head warning absent")
	actor._physics_process(0.16)
	check(target.hits.is_empty() and actor.velocity==Vector2.ZERO,"shade moves/damages during warning")
	target.stealth_active = true
	actor._physics_process(0.03)
	check(not actor.basic_attack.is_active() and not actor.should_show_attack_marker(),"hidden target retains dash")
	target.stealth_active = false
	actor.basic_attack.cooldown = 0
	actor._physics_process(0.01)
	actor.apply_spawn_impulse(Vector2.ZERO,0.1)
	actor._physics_process(0.03)
	check(not actor.basic_attack.is_active(),"spawn guard leaves ambush active")
	actor.spawn_impulse_remaining = 0
	actor.take_damage(1)
	actor._physics_process(0.01)
	check(actor.native_visual.player.current_animation=="hit","actual hit lacks new recoil")
	actor.basic_attack.cooldown = 0
	actor._physics_process(0.01)
	var observed := [false]
	actor.died.connect(func(_actor,_coins,_source): observed[0]=not actor.basic_attack.is_active())
	actor.take_damage(1000)
	check(observed[0],"death callback sees live ambush")
	await process_frame
	await process_frame
	check(not is_instance_valid(actor),"dead shade remains actor")
	arena.free()
	await process_frame
	if not failures: print("TEST PASS: CirclingShadeIntegrationTest %d" % checks)
	quit(1 if failures else 0)
