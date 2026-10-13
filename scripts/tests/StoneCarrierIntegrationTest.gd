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
		push_error("TEST FAIL: StoneCarrierIntegrationTest "+label)
func _initialize() -> void:
	await process_frame
	var arena := Node2D.new()
	root.add_child(arena)
	var target := Target.new()
	target.position = Vector2(200,0)
	arena.add_child(target)
	var enemy := EnemySource.new()
	enemy.setup(EnemySource.EnemyKind.BRUISER,0,arena,target)
	arena.add_child(enemy)
	enemy.set_physics_process(false)
	var view = enemy.native_visual
	check(view!=null and enemy.static_visual==null,"actual BRUISER still uses legacy raster")
	if view==null:
		arena.free()
		quit(1)
		return
	check(view.skeleton.get_bone_count()==17,"large rig incomplete")
	check(view.body_rect.has_point(Vector2(-30,43)),"runtime/export entrance occlusion bounds lost")
	check(enemy.body_radius==24 and enemy.contact_damage==54 and enemy.health.max_health==300 and enemy.attack_range==46,"art changes combat numbers")
	check(not enemy.should_show_health_bar() and not enemy.should_show_status_marker(),"healthy large enemy feedback policy changed")
	enemy.apply_spawn_impulse(Vector2.ZERO,0.3)
	enemy._physics_process(0.1)
	check(view.player.current_animation=="entrance" and target.hits.is_empty(),"actual spawn has no non-attack entrance")
	enemy.spawn_impulse_remaining = 0
	check(is_equal_approx(enemy.speed,59.4),"art changes large enemy speed")
	var at: Transform2D = enemy.global_transform
	enemy.velocity = Vector2(100,0)
	enemy._update_static_motion(0.25)
	check(view.player.current_animation=="walk" and absf(view.skeleton.get_node("Torso/LegL/ShinL").rotation)>0.05,"not genuine articulated gait")
	check(enemy.global_transform==at,"visual sampling moves hitbox")
	enemy.take_damage(1)
	check(view.player.current_animation=="hit" and enemy.should_show_health_bar(),"hit pose/bar absent")
	check(enemy.get_health_bar_rect().end.y<-70,"bar intersects stone crown")
	enemy.velocity = Vector2.ZERO
	enemy._update_static_motion(0.20)
	check(view.player.current_animation=="idle","hit recovery remains stuck")
	target.position = Vector2(20,0)
	enemy._physics_process(0.1)
	check(enemy.is_attacking and target.hits.is_empty(),"original windup / hit moment changed")
	check(view.player.current_animation=="slam_warning","reviewed post-rig large warning missing")
	enemy._physics_process(0.41)
	for index in 10:
		enemy._update_static_motion(0.01)
	check(target.hits==[54.0],"native animation produces duplicate melee hit")
	check(enemy.global_transform==at,"stationary melee visual shifts collision root")
	enemy._update_enemy_facing(Vector2(-100,0))
	check(view.get_node("Facing").scale.x==-1 and enemy.rotation==0,"large actor spins rather than mirrors")
	var pose: Transform2D = view.skeleton.get_bone(0).transform
	paused = true
	await process_frame
	await process_frame
	check(view.skeleton.get_bone(0).transform.is_equal_approx(pose),"paused large actor moves")
	paused = false
	var corpse_at: Transform2D = view.global_transform
	enemy.take_damage(1000)
	check(view.get_parent()==arena and view.global_transform.is_equal_approx(corpse_at) and view.player.current_animation=="death","corpse detachment drifts")
	view.player.advance(0.8)
	await process_frame
	check(not is_instance_valid(view),"large corpse leaks")
	arena.free()
	await process_frame
	if not failures:
		print("TEST PASS: StoneCarrierIntegrationTest %d" % checks)
	quit(1 if failures else 0)
