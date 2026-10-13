extends SceneTree
const Factory = preload("res://scripts/campaign/RegionalEnemyFactory.gd")
class Target extends Node2D:
	var hits: Array[float] = []
	func take_damage(amount: float) -> void: hits.append(amount)
	func is_stealthed() -> bool: return false
var checks := 0
var failures := 0
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("TEST FAIL: EchoSentinelClockTest "+label)
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	var arena := Node2D.new()
	root.add_child(arena)
	var target := Target.new()
	target.position = Vector2(300,200)
	arena.add_child(target)
	var actor = Factory.create_actor(5,"echo_sentinel",0,arena,target)
	actor.position = Vector2(200,200)
	actor.world_bounds = Rect2(-600,-400,1400,1000)
	arena.add_child(actor)
	actor.basic_attack.cooldown = 0
	var deadline := Time.get_ticks_msec()+2000
	while not actor.should_show_attack_marker() and Time.get_ticks_msec()<deadline: await physics_frame
	check(actor.should_show_attack_marker() and target.hits.is_empty(),"real physics ring lacks damage-free head warning")
	var warning_started := Time.get_ticks_msec()
	while actor.basic_attack.radius<20 and Time.get_ticks_msec()<deadline: await physics_frame
	check(actor.native_visual.player.current_animation=="attack" and target.hits.is_empty(),"actual wave starts with instant damage or wrong animation")
	var before: float = actor.basic_attack.elapsed
	var before_radius: float = actor.basic_attack.radius
	paused = true
	await create_timer(0.05,true,false,true).timeout
	check(is_equal_approx(actor.basic_attack.elapsed,before) and is_equal_approx(actor.basic_attack.radius,before_radius),"paused real wave advances attack/render clock")
	paused = false
	while target.hits.is_empty() and Time.get_ticks_msec()<deadline: await physics_frame
	var elapsed := (Time.get_ticks_msec()-warning_started)/1000.0-0.05
	check(target.hits==[15.0] and elapsed>=0.30 and elapsed<0.70,"real ring does not honor warning plus travel time")
	var death_observed_radius := [-1.0]
	actor.died.connect(func(_actor,_coins,_source): death_observed_radius[0]=actor.basic_attack.radius)
	actor.take_damage(1000)
	check(death_observed_radius[0]==0,"death notification exposes a still-active sound wave")
	await process_frame
	await process_frame
	check(not is_instance_valid(actor) and target.hits==[15.0],"dead sentry damages again or remains")
	arena.free()
	await process_frame
	if not failures: print("TEST PASS: EchoSentinelClockTest %d, real warning+travel %.3fs" % [checks,elapsed])
	quit(1 if failures else 0)
