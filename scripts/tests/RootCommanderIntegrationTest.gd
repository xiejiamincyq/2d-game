extends SceneTree
const EnemySource = preload("res://scripts/actors/Enemy.gd")
class Target extends Node2D:
	var hits: Array[float] = []
	func take_damage(amount: float) -> void:
		hits.append(amount)
var checks := 0
var failures := 0
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("TEST FAIL: RootCommanderIntegrationTest "+label)
func _initialize() -> void:
	await process_frame
	var arena := Node2D.new()
	root.add_child(arena)
	var shots := Node2D.new()
	arena.add_child(shots)
	var target := Target.new()
	target.position = Vector2(200,0)
	arena.add_child(target)
	var enemy := EnemySource.new()
	enemy.setup(EnemySource.EnemyKind.OVERSEER,0,shots,target)
	arena.add_child(enemy)
	enemy.set_physics_process(false)
	var view = enemy.native_visual
	check(view!=null and enemy.static_visual==null,"actual OVERSEER still uses legacy raster")
	if view==null:
		arena.free()
		quit(1)
		return
	check(view.skeleton.get_bone_count()==23,"actual commander rig incomplete")
	check(enemy.body_radius==40 and enemy.contact_damage==72 and enemy.health.max_health==1800 and enemy.attack_range==64,"visual migration changes combat values")
	check(is_equal_approx(enemy.speed,46.2),"visual migration changes speed")
	check(enemy.should_show_health_bar() and not enemy.should_show_status_marker(),"healthy overseer bar/status policy lost")
	enemy.apply_spawn_impulse(Vector2.ZERO,0.3)
	enemy._physics_process(0.1)
	check(view.player.current_animation=="entrance" and target.hits.is_empty(),"spawn lacks non-attack entrance")
	enemy.spawn_impulse_remaining = 0
	var at: Transform2D = enemy.global_transform
	enemy.velocity = Vector2(100,0)
	enemy._update_static_motion(0.26)
	check(view.player.current_animation=="walk" and absf(view.skeleton.get_node("Torso/LegR/ShinR").rotation)>0.05,"actual articulated gait absent")
	check(enemy.global_transform==at,"gait moves collision root")
	enemy.take_damage(1)
	check(view.player.current_animation=="hit" and enemy.should_show_health_bar(),"hit pose/bar absent")
	check(enemy.get_health_bar_rect().end.y<-82,"health bar overlaps hood/horns")
	enemy.velocity = Vector2.ZERO
	enemy._update_static_motion(0.3)
	check(view.player.current_animation=="idle","recoil does not settle")
	enemy.shoot_cooldown = 0
	enemy._update_overseer(0.01,target,200)
	check(enemy.ranged_is_winding_up and shots.get_child_count()==0,"old burst windup changed")
	enemy._update_static_motion(0)
	check(view.player.current_animation=="burst_warning","reviewed native core warning absent after rig checkpoint")
	enemy._update_overseer(0.91,target,200)
	check(shots.get_child_count()==12,"native view changes actual burst count")
	for shot in shots.get_children():
		shot.set_physics_process(false)
		check(shot.damage==30 and is_equal_approx(shot.velocity.length(),310) and shot.lifetime==3,"native view changes radial shot numbers")
	enemy._update_overseer(0,target,200)
	check(shots.get_child_count()==12,"visual playback duplicates burst")
	var requests: Array[int] = []
	enemy.reinforcements_requested.connect(func(_actor: Node,count: int): requests.append(count))
	enemy.health.current_health = 1170
	enemy._request_boss_reinforcements_at_health_thresholds()
	enemy._request_boss_reinforcements_at_health_thresholds()
	enemy.health.current_health = 576
	enemy._request_boss_reinforcements_at_health_thresholds()
	enemy._request_boss_reinforcements_at_health_thresholds()
	check(requests==[18,24],"reinforcement thresholds repeat or disappear")
	target.position = Vector2(20,0)
	enemy._update_melee_attack(0.1,target,20)
	check(enemy.is_attacking and target.hits.is_empty(),"old melee windup changed")
	enemy._update_static_motion(0)
	# This direct melee fixture intentionally bypasses the production arbiter.
	enemy.overseer_burst_recovery_remaining = 0
	enemy._update_static_motion(0)
	check(view.player.current_animation=="melee_warning","reviewed native staff warning absent after rig checkpoint")
	enemy._update_melee_attack(0.23,target,20)
	enemy._update_melee_attack(0.05,target,20)
	check(target.hits==[72.0] and enemy.global_transform==at,"art changes hit timing or duplicates melee damage")
	enemy._update_enemy_facing(Vector2(-100,0))
	check(view.get_node("Facing").scale.x==-1 and enemy.rotation==0,"overseer spins rather than mirrors")
	check(enemy.get_visual_rect().is_equal_approx(view.get_node("Facing").transform*view.body_rect),"left-facing asymmetric staff occlusion bounds not mirrored")
	var pose: Transform2D = view.skeleton.get_bone(0).transform
	paused = true
	await process_frame
	await process_frame
	check(view.skeleton.get_bone(0).transform.is_equal_approx(pose),"paused overseer moves")
	paused = false
	var corpse_at: Transform2D = view.global_transform
	enemy.take_damage(5000)
	check(view.get_parent()==arena and view.global_transform.is_equal_approx(corpse_at) and view.player.current_animation=="death","corpse detachment drifts")
	check(not enemy.take_damage(1),"death resolves twice")
	view.player.advance(1.2)
	await process_frame
	check(not is_instance_valid(view),"commander corpse leaks")
	arena.free()
	await process_frame
	if not failures:
		print("TEST PASS: RootCommanderIntegrationTest %d" % checks)
	quit(1 if failures else 0)
