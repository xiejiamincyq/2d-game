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
		push_error("TEST FAIL: EchoSentinelIntegrationTest "+label)
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	var arena := Node2D.new()
	root.add_child(arena)
	var target := Target.new()
	target.position = Vector2(300,200)
	arena.add_child(target)
	var actor = Factory.create_actor(5,"echo_sentinel",0,arena,target)
	check(actor!=null,"fifth-region actual sentry absent")
	if failures:
		arena.free()
		quit(1)
		return
	actor.position = Vector2(200,200)
	actor.world_bounds = Rect2(-600,-400,1400,1000)
	arena.add_child(actor)
	actor.set_physics_process(false)
	check(actor.native_visual.skeleton.get_bone_count()==20 and actor.should_show_health_bar(),"actual bell rig/healthy bar missing")
	check(actor.health.current_health==38 and actor.body_radius==16 and actor.scale==Vector2.ONE,"physical root/HP incorrect")
	actor.basic_attack.cooldown = 0
	actor._physics_process(0.01)
	check(actor.should_show_attack_marker() and actor.native_visual.player.current_animation=="warning" and target.hits.is_empty(),"head warning lacks native anticipation")
	actor._physics_process(0.14)
	check(target.hits.is_empty() and actor.basic_attack.radius==0,"warning hurts early")
	actor._physics_process(actor.basic_attack.get_warning_duration()-actor.basic_attack.elapsed+0.02)
	check(not actor.should_show_attack_marker() and actor.native_visual.player.current_animation=="attack" and target.hits.is_empty(),"wave bypasses expansion/attack clip")
	actor._physics_process(0.25)
	check(target.hits==[15.0],"actual ring misses nearby player")
	actor._physics_process(0.30)
	check(target.hits==[15.0],"ring repeats damage in recovery")
	actor.basic_attack.cancel()
	actor.basic_attack.cooldown = 0
	actor._physics_process(0.01)
	target.stealth_active = true
	actor._physics_process(0.4)
	check(not actor.basic_attack.is_active() and actor.basic_attack.radius==0 and target.hits.size()==1,"hidden target retains sound wave")
	target.stealth_active = false
	actor.basic_attack.cooldown = 0
	actor._physics_process(0.01)
	actor.apply_spawn_impulse(Vector2.ZERO,0.3)
	actor._physics_process(0.1)
	check(not actor.basic_attack.is_active() and not actor.should_show_attack_marker(),"spawn impulse leaves live wave")
	actor.spawn_impulse_remaining = 0
	actor.take_damage(1)
	check(actor.native_visual.player.current_animation=="hit","nonlethal hit lacks new recoil")
	actor.basic_attack.cooldown = 100
	target.position = actor.position+Vector2(50,0)
	actor._physics_process(0.05)
	check(actor.velocity.x<0,"close sentry does not retreat for ring spacing")
	var actual_view = actor.native_visual
	actor.take_damage(1000)
	check(actor.death_resolved and actual_view.player.current_animation=="death" and not actual_view.is_in_group("enemies"),"death retains attack/old corpse")
	arena.free()
	await process_frame
	if not failures: print("TEST PASS: EchoSentinelIntegrationTest %d" % checks)
	quit(1 if failures else 0)
