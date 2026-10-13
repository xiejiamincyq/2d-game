extends SceneTree
const EnemyScript = preload("res://scripts/actors/Enemy.gd")
class Target extends Node2D:
	var stealth_active := false
	func is_stealthed() -> bool:
		return stealth_active
var checks := 0
var failures := 0
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("TEST FAIL: SaltNeedlerIntegrationTest "+label)
func _initialize() -> void:
	await process_frame
	var arena := Node2D.new()
	root.add_child(arena)
	var target := Target.new()
	target.position = Vector2(300,0)
	arena.add_child(target)
	var projectiles := Node2D.new()
	arena.add_child(projectiles)
	var enemy := EnemyScript.new()
	enemy.setup(EnemyScript.EnemyKind.MARKSMAN,0,projectiles,target)
	arena.add_child(enemy)
	enemy.set_physics_process(false)
	var view = enemy.native_visual
	check(view != null and enemy.static_visual == null,"actual MARKSMAN remains raster")
	if view == null:
		arena.free()
		quit(1)
		return
	check(view.skeleton.get_bone_count()==16 and view.scene_file_path.ends_with("salt_needler_paper_v1.tscn"),"wrong rig")
	check(enemy.health.max_health==44 and enemy.contact_damage==15 and enemy.body_radius==14 and enemy.speed==enemy.RANGED_ENEMY_SPEED,"art changes stats")
	check(enemy.should_show_health_bar() and not enemy.should_show_status_marker(),"small enemy bar absent")
	check(enemy.get_attack_marker_top()+2 < enemy.get_health_bar_rect().position.y and enemy.get_health_bar_rect().end.y < -49,"markers overlap hood")
	enemy.velocity = Vector2(80,0)
	enemy._update_static_motion(0.12)
	check(view.player.current_animation=="walk" and view.skeleton.get_node("Torso/LegL/ShinL").rotation!=0,"no articulated walking")
	enemy.ranged_is_winding_up = true
	enemy.ranged_windup_remaining = 0.15
	enemy.ranged_target_position = Vector2(1400,0)
	enemy._update_static_motion(0)
	check(view.player.current_animation=="warning" and absf(view.player.current_animation_position-0.15)<0.001,"warning not tied to 0.30s combat clock")
	check(enemy.should_show_attack_marker() and not view.get_node("Warning").visible and projectiles.get_child_count()==0,"duplicate marker / warning damages")
	var muzzle: Node2D = view.get_node("Facing/Skeleton2D/Torso/ArmR/ForearmR/HandR/NeedleGun/Muzzle")
	var emission: Vector2 = muzzle.global_position
	target.position = Vector2(300,80)
	enemy._update_marksman(0.16,target)
	enemy._update_static_motion(0)
	check(projectiles.get_child_count()==1 and view.player.current_animation=="attack","real shot lacks recoil or duplicate shot")
	var shot = projectiles.get_child(0)
	shot.set_physics_process(false)
	check(shot.global_position.is_equal_approx(emission) and emission.distance_to(enemy.global_position)>10,"needle still emitted from body center")
	check(shot.velocity.is_equal_approx((Vector2(1400,0)-emission).normalized()*910) and shot.damage==36 and shot.radius==3 and shot.lifetime==2,"shot changes locked endpoint / damage / speed")
	for index in 6:
		enemy._update_static_motion(0.01)
	check(projectiles.get_child_count()==1,"animation generates extra projectile")
	enemy._update_static_motion(0.25)
	check(view.player.current_animation=="walk","recoil stuck")
	enemy.velocity = Vector2.ZERO
	enemy.take_damage(1)
	check(view.player.current_animation=="hit","hit not bound")
	enemy._update_static_motion(0.17)
	check(view.player.current_animation=="idle","hit not released")
	var wall := StaticBody2D.new()
	wall.position = Vector2(18,0)
	var shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(8,80)
	shape.shape = rectangle
	wall.add_child(shape)
	arena.add_child(wall)
	await physics_frame
	enemy._fire_marksman(target)
	var wall_shot = projectiles.get_child(1)
	wall_shot.set_physics_process(false)
	check(wall_shot.global_position.is_equal_approx(enemy.global_position),"muzzle emits through blocking wall")
	wall.free()
	enemy.ranged_is_winding_up = true
	enemy.ranged_windup_remaining = 0.1
	target.stealth_active = true
	enemy._physics_process(0.01)
	check(not enemy.ranged_is_winding_up and not enemy.should_show_attack_marker() and view.player.current_animation not in ["warning","attack"],"stealth leaves live windup / recoil")
	target.stealth_active = false
	enemy.ranged_is_winding_up = true
	enemy.spawn_impulse_remaining = 0.1
	enemy.spawn_impulse_velocity = Vector2.ZERO
	enemy._physics_process(0.01)
	check(not enemy.ranged_is_winding_up and view.player.current_animation not in ["warning","attack"],"spawn impulse leaves live charge")
	enemy.spawn_impulse_remaining = 0
	enemy.native_motion.shot_remaining = 0
	enemy.velocity = Vector2.ZERO
	target.position = Vector2(100,-200)
	enemy._update_static_motion(0)
	target.stealth_active = true
	enemy._update_static_motion(0)
	check(muzzle.get_parent().transform.is_equal_approx(muzzle.get_parent().rest) and view.skeleton.get_node("Torso/ArmR").transform.is_equal_approx(view.skeleton.get_node("Torso/ArmR").rest),"same idle clip leaves procedural aim after target disappears")
	target.stealth_active = false
	target.position = Vector2(100,-200)
	enemy._update_static_motion(0)
	var gun: Bone2D = muzzle.get_parent()
	check(absf(gun.rotation)<=deg_to_rad(35.01) and absf(view.skeleton.get_node("Torso/ArmR").rotation)<=deg_to_rad(60.01),"gun aim dislocates wrist / shoulder")
	check(muzzle.global_position.y < enemy.global_position.y,"articulated gun doesn't raise toward target")
	for degrees in range(0,360,10):
		target.position = enemy.position+Vector2.RIGHT.rotated(deg_to_rad(degrees))*300
		enemy._update_static_motion(0)
		check(absf(gun.rotation)<=deg_to_rad(35.01) and absf(view.skeleton.get_node("Torso/ArmR").rotation)<=deg_to_rad(60.01) and muzzle.global_position.distance_to(enemy.global_position)<55,"aim rotates detached gun around body")
	target.position = Vector2(-300,0)
	enemy._update_enemy_facing(Vector2(-300,0))
	check(view.get_node("Facing").scale.x==-1 and enemy.rotation==0,"not mirroring / spinning body")
	enemy._update_static_motion(0)
	check(muzzle.global_position.x < enemy.position.x,"muzzle not following left-facing hand")
	var pose: Transform2D = view.skeleton.get_bone(0).transform
	paused = true
	await process_frame
	await process_frame
	check(view.skeleton.get_bone(0).transform.is_equal_approx(pose),"pause moves rig")
	paused = false
	var at: Transform2D = view.global_transform
	enemy.take_damage(1000)
	check(enemy.death_resolved and enemy.is_queued_for_deletion() and view.get_parent()==arena and view.global_transform.is_equal_approx(at),"death delays combat / teleports")
	check(view.player.current_animation=="death" and not view.cancel_action(),"dead ghost resumes attack")
	view.player.advance(0.6)
	await process_frame
	check(not is_instance_valid(view),"death rig leaks")
	arena.free()
	await process_frame
	if not failures:
		print("TEST PASS: SaltNeedlerIntegrationTest %d" % checks)
	quit(1 if failures else 0)
