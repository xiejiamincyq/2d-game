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
		push_error("TEST FAIL: StoneCarrierAttackIntegrationTest "+label)
func _initialize() -> void:
	await process_frame
	var host := Node2D.new()
	root.add_child(host)
	var target := Target.new()
	target.position = Vector2(20,0)
	host.add_child(target)
	var actor := EnemySource.new()
	actor.setup(EnemySource.EnemyKind.BRUISER,0,host,target)
	host.add_child(actor)
	actor.set_physics_process(false)
	var view = actor.native_visual
	check(view.scene_file_path.ends_with("stone_carrier_paper_v2.tscn"),"actual BRUISER not migrated to reviewed slam")
	if failures:
		host.free()
		quit(1)
		return
	var root_at: Transform2D = actor.global_transform
	actor._physics_process(0.1)
	check(view.player.current_animation=="slam_warning" and target.hits.is_empty(),"warning not driven by actual attack timer")
	check(actor.should_show_attack_marker(),"large attack lacks compact head warning")
	actor.take_damage(1)
	check(view.player.current_animation=="slam_warning","incoming bullets hide attack telegraph")
	target.position = Vector2(-20,0)
	actor._physics_process(0.1)
	check(view.get_node("Facing").scale.x==1,"raised attack snaps to chasing target side")
	actor._physics_process(0.31)
	check(target.hits==[54.0] and view.player.current_animation=="slam_attack","actual damage/impact window not aligned")
	check(not actor.should_show_attack_marker(),"warning remains after hit")
	for i in 10:
		actor._update_static_motion(0.01)
	check(target.hits==[54.0],"visual sampler emits additional damage")
	actor._physics_process(0.15)
	check(view.player.current_animation=="slam_recovery","recovery not read from gameplay timer")
	check(actor.global_transform==root_at and actor.body_radius==24 and actor.health.max_health==300 and actor.attack_windup==0.5 and actor.attack_recovery==0.75,"animation alters physical root/combat")
	var pose: Transform2D = view.skeleton.get_bone(0).transform
	actor._update_static_motion(NAN)
	check(view.skeleton.get_bone(0).transform==pose,"invalid visual delta changes pose")
	paused = true
	await process_frame
	await process_frame
	check(view.skeleton.get_bone(0).transform==pose,"native attack has independent paused clock")
	paused = false
	target.stealthed = true
	actor._physics_process(0.1)
	check(not actor.is_attacking and not actor.attack_has_hit and actor.attack_timer==0,"hidden player leaves stale slam armed")
	check(view.player.current_animation not in ["slam_warning","slam_attack","slam_recovery"] and actor.attack_cooldown>=0.4,"hidden cancellation fails to reset visual/rearm delay")
	target.stealthed = false
	target.position = actor.position+Vector2(20,0)
	actor.attack_cooldown = 0
	actor._physics_process(0.1)
	check(actor.is_attacking,"carrier never resumes new attack")
	actor.apply_spawn_impulse(Vector2.ZERO,0.2)
	actor._physics_process(0.05)
	check(not actor.is_attacking and view.player.current_animation=="entrance" and target.hits==[54.0],"birth impulse retains old attack/damage")
	actor.spawn_impulse_remaining = 0
	actor.attack_cooldown = 0
	actor._physics_process(0.1)
	actor.take_damage(1000)
	check(view.player.current_animation=="death" and not actor.should_show_attack_marker() and not actor.is_attacking and not actor.attack_has_hit,"death retains warning/slam")
	view.player.advance(0.8)
	await process_frame
	check(not is_instance_valid(view),"slam corpse survives terminal clip")
	host.free()
	if not failures:
		print("TEST PASS: StoneCarrierAttackIntegrationTest %d" % checks)
	quit(1 if failures else 0)
