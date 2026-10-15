extends SceneTree
const FACTORY := "res://scripts/campaign/RegionalEnemyFactory.gd"
class Target extends Node2D:
	var stealth_active := false
	var hits: Array[float] = []
	func is_stealthed() -> bool: return stealth_active
	func take_damage(amount: float,_source: StringName = &"") -> void: hits.append(amount)
var checks := 0
var failures := 0
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("TEST FAIL: EmberSparkIntegrationTest "+label)
func _initialize() -> void:
	await process_frame
	check(ResourceLoader.exists(FACTORY),"regional actor factory missing")
	if failures:
		quit(1)
		return
	var factory = load(FACTORY)
	var arena := Node2D.new()
	root.add_child(arena)
	var shots := Node2D.new()
	arena.add_child(shots)
	var target := Target.new()
	target.position = Vector2(250,0)
	arena.add_child(target)
	target.add_to_group(&"player")
	check(factory.create_actor(2,"missing",0,shots,target)==null and factory.create_actor(6,"unknown_role",0,shots,target)==null,"factory pretends unknown regional enemies exist")
	for spec in [[1,"root_pursuer","rootling_paper_v3"],[1,"spore_spitter","sporeling_paper_v1"],[2,"slag_charger","cinder_runner_paper_v2"]]:
		var existing = factory.create_actor(spec[0],spec[1],0,shots,target)
		arena.add_child(existing)
		existing.set_physics_process(false)
		check(existing.get_visual_node().scene_file_path=="res://scenes/actors/native/"+spec[2]+".tscn","regional factory mixes a family or keeps a raster")
		existing.free()
	var enemy = factory.create_actor(2,"spark_gunner",0,shots,target)
	check(enemy!=null,"second-region scatterer cannot instantiate")
	if enemy==null:
		arena.free()
		quit(1)
		return
	enemy.world_bounds = Rect2(-600,-400,1200,800)
	arena.add_child(enemy)
	enemy.set_physics_process(false)
	var view = enemy.native_visual
	check(view!=null and view.scene_file_path=="res://scenes/actors/native/ember_spark_paper_v1.tscn" and enemy.static_visual==null,"factory still uses recolored spitter")
	check(view.skeleton.get_bone_count()==16 and enemy.should_show_health_bar(),"native skin or permanent ordinary bar missing")
	var body_at: Transform2D = enemy.global_transform
	enemy.velocity = Vector2(80,0)
	enemy._update_static_motion(0.2)
	check(view.player.current_animation=="walk" and absf(view.skeleton.get_node("Torso/LegR/ShinR").rotation)>0.01,"actual adapter lacks foot articulation")
	check(enemy.global_transform.is_equal_approx(body_at),"gait shifts hitbox")
	enemy.shoot_cooldown = 0
	enemy._update_spitter(0.01,target)
	enemy._update_static_motion(0)
	check(enemy.ranged_is_winding_up and enemy.should_show_attack_marker() and view.player.current_animation=="warning" and shots.get_child_count()==0,"short head warning absent or fires early")
	var locked_target: Vector2 = enemy.ranged_target_position
	target.position = Vector2(250,100)
	enemy._update_spitter(0.17,target)
	check(shots.get_child_count()==0 and enemy.ranged_target_position==locked_target,"fan tracks target after commitment or fires early")
	enemy._update_static_motion(0)
	var nozzle: Vector2 = enemy.native_motion.get_safe_muzzle(enemy)
	check(enemy.ranged_windup_duration>=0.55,"scatterer warning is shorter than the human reaction floor")
	enemy._update_spitter(enemy.ranged_windup_remaining+0.001,target)
	enemy._update_static_motion(0)
	check(shots.get_child_count()==3 and not enemy.should_show_attack_marker() and view.player.current_animation=="attack","warning does not release one three-spark fan")
	if shots.get_child_count()!=3:
		arena.free()
		quit(1)
		return
	for i in 3:
		var shot = shots.get_child(i)
		shot.set_physics_process(false)
		var axis := (locked_target-nozzle).angle()
		check(is_equal_approx(wrapf(shot.velocity.angle()-axis,-PI,PI),deg_to_rad([-15,0,15][i])),"fan angles or locked origin drift")
		check(shot.damage==9 and shot.radius==4 and is_equal_approx(shot.velocity.length(),280) and is_equal_approx(shot.lifetime,1.1),"short spark becomes long-range blanket")
		check(shot.global_position.is_equal_approx(nozzle) and shot.target_group==&"player","spark bypasses real nozzle or hostile target")
		shot._try_hit(target)
		shot._try_hit(target)
	check(target.hits==[9.0,9.0,9.0],"spark repeats damage")
	enemy._update_spitter(0.01,target)
	check(shots.get_child_count()==3,"released fan repeats in recovery")
	await process_frame
	enemy._update_static_motion(0.3)
	enemy.shoot_cooldown = 0
	enemy._update_spitter(0.01,target)
	target.stealth_active = true
	enemy._physics_process(0.3)
	check(not enemy.ranged_is_winding_up and not enemy.should_show_attack_marker() and shots.get_child_count()==0 and view.player.current_animation!="attack","hidden target leaves a stale fan")
	target.stealth_active = false
	target.position = Vector2(250,0)
	enemy.shoot_cooldown = 0
	enemy._update_spitter(0.01,target)
	enemy.apply_spawn_impulse(Vector2.ZERO,0.2)
	enemy._physics_process(0.3)
	check(not enemy.ranged_is_winding_up and shots.get_child_count()==0,"spawn impulse releases a canceled fan")
	enemy.spawn_impulse_remaining = 0
	var arm: Bone2D = view.skeleton.get_node("Torso/ArmR")
	var gun: Bone2D = arm.get_node("Nozzle")
	for at in [Vector2(200,-400),Vector2(-200,-400),Vector2(-200,400),Vector2(200,400)]:
		target.position = at
		enemy._update_enemy_facing(at)
		enemy._update_static_motion(0.1)
		check(absf(arm.rotation)<=PI/3+0.001 and absf(gun.rotation)<=deg_to_rad(35)+0.001 and enemy.rotation==0,"nozzle orbits body")
	target.position = enemy.position+Vector2(250,0)
	enemy.velocity = Vector2.ZERO
	enemy._update_static_motion(0.3)
	var muzzle_node: Marker2D = view.get_node("Facing/Skeleton2D/Torso/ArmR/Nozzle/Muzzle")
	var clear: Vector2 = muzzle_node.global_position
	check(enemy.native_motion.get_safe_muzzle(enemy).is_equal_approx(clear) and clear.distance_to(enemy.global_position)>25,"clear nozzle falls back to center")
	var saved_bounds: Rect2 = enemy.world_bounds
	enemy.world_bounds = Rect2(enemy.position-Vector2(20,20),Vector2(40,40))
	check(enemy.native_motion.get_safe_muzzle(enemy).is_equal_approx(enemy.global_position),"nozzle crosses playable world boundary")
	enemy.world_bounds = saved_bounds
	var blocker := StaticBody2D.new()
	var blocker_shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 1
	blocker_shape.shape = circle
	blocker.add_child(blocker_shape)
	arena.add_child(blocker)
	var line: Vector2 = (clear-enemy.global_position).normalized()
	blocker.global_position = clear+line.orthogonal()*4.5
	await physics_frame
	check(enemy.get_world_2d().direct_space_state.intersect_ray(PhysicsRayQueryParameters2D.create(enemy.global_position,clear,enemy.collision_mask,[enemy.get_rid()])).is_empty(),"clear centerline fixture invalid")
	check(enemy.native_motion.get_safe_muzzle(enemy).is_equal_approx(enemy.global_position),"spark radius ignores adjacent obstruction")
	blocker.global_position = enemy.global_position.lerp(clear,0.5)
	await physics_frame
	check(enemy.native_motion.get_safe_muzzle(enemy).is_equal_approx(enemy.global_position),"nozzle emits through wall")
	blocker.free()
	await physics_frame
	enemy.shoot_cooldown = 0
	target.position = enemy.position+Vector2(500,0)
	enemy._update_spitter(0.01,target)
	check(not enemy.ranged_is_winding_up and shots.get_child_count()==0,"short-range enemy fires at long range")
	target.position = enemy.position+Vector2(250,0)
	enemy._update_spitter(0.01,target)
	enemy._update_static_motion(0)
	enemy._update_spitter(enemy.ranged_windup_duration+0.01,target)
	check(shots.get_child_count()==3,"scatterer does not resume after cancellation")
	for shot in shots.get_children():
		shot.set_physics_process(false)
		shot._physics_process(1.101)
	await process_frame
	check(shots.get_child_count()==0,"short sparks outlive their local threat window")
	enemy._update_static_motion(0.3)
	enemy.take_damage(1)
	enemy._update_static_motion(0)
	check(view.player.current_animation=="hit" and enemy.should_show_health_bar(),"actual damage lacks recoil/bar")
	var before: Transform2D = view.skeleton.get_bone(0).transform
	paused = true
	await process_frame
	await process_frame
	check(view.skeleton.get_bone(0).transform.is_equal_approx(before),"paused furnace enemy moves")
	paused = false
	var deaths := [0]
	enemy.died.connect(func(_enemy,_coins,_source): deaths[0]+=1)
	var corpse_at: Transform2D = view.global_transform
	enemy.take_damage(1000)
	enemy.take_damage(1000)
	check(deaths[0]==1 and view.get_parent()==arena and view.global_transform.is_equal_approx(corpse_at),"native death duplicates/drifts")
	view.player.advance(1)
	await process_frame
	check(not is_instance_valid(view),"native spark corpse leaks")
	arena.free()
	await process_frame
	if not failures:
		print("TEST PASS: EmberSparkIntegrationTest %d" % checks)
	quit(1 if failures else 0)
