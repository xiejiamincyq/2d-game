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
		push_error("TEST FAIL: SpaceCutterIntegrationTest "+label)
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	var arena := Node2D.new()
	root.add_child(arena)
	var target := Target.new()
	target.position = Vector2(330,200)
	arena.add_child(target)
	var shots := Node2D.new()
	arena.add_child(shots)
	var actor = Factory.create_actor(6,"space_cutter",0,shots,target)
	check(actor!=null,"sixth-region cut actor absent")
	if actor==null:
		arena.free()
		quit(1)
		return
	actor.position = Vector2(200,200)
	actor.world_bounds = Rect2(-600,-400,1400,1000)
	arena.add_child(actor)
	actor.set_physics_process(false)
	check(actor.native_visual.skeleton.get_bone_count()==19 and actor.static_visual==null and actor.should_show_health_bar(),"body or healthy bar remains old")
	actor.basic_attack.cooldown = 0
	actor._physics_process(0.01)
	var origin: Vector2 = actor.position
	check(actor.should_show_attack_marker() and actor.native_visual.player.current_animation=="warning" and target.hits.is_empty(),"cut misses head warning")
	actor._physics_process(0.14)
	check(target.hits.is_empty() and actor.position.is_equal_approx(origin),"warning hits or body skates")
	actor._physics_process(actor.basic_attack.get_warning_duration()-actor.basic_attack.elapsed+0.01)
	check(target.hits==[21.0] and actor.native_visual.player.current_animation=="attack" and shots.get_child_count()==0,"cut missing/also old spit")
	actor._update_spitter(0,target)
	check(target.hits==[21.0] and actor.position.is_equal_approx(origin),"live cut repeats or moves root")
	actor.basic_attack.cancel()
	actor.basic_attack.cooldown = 0
	actor._physics_process(0.01)
	target.stealth_active = true
	actor._physics_process(0.2)
	check(not actor.basic_attack.is_active(),"hidden target does not cancel")
	target.stealth_active = false
	actor.basic_attack.cooldown = 0
	actor._physics_process(0.01)
	actor.apply_spawn_impulse(Vector2.ZERO,0.1)
	actor._physics_process(0.2)
	check(not actor.basic_attack.is_active(),"spawn protection leaves cut active")
	actor.spawn_impulse_remaining = 0
	actor.basic_attack.cooldown = 0
	actor._physics_process(0.01)
	var stopped := [false]
	actor.died.connect(func(_actor,_coins,_source): stopped[0]=not actor.basic_attack.is_active())
	actor.take_damage(1000)
	check(stopped[0],"death reward callback retains active cut")
	await process_frame
	await process_frame
	arena.free()
	await process_frame
	if not failures: print("TEST PASS: SpaceCutterIntegrationTest %d" % checks)
	quit(1 if failures else 0)
