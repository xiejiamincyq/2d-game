extends SceneTree
const EnemyScript = preload("res://scripts/actors/Enemy.gd")
const SCENE := "res://scenes/actors/native/folio_lobber_paper_v1.tscn"
class Target extends Node2D:
	var hits: Array[float] = []
	var stealthed := false
	func take_damage(amount: float) -> void:
		hits.append(amount)
	func is_stealthed() -> bool:
		return stealthed
var checks := 0
var failures := 0
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("TEST FAIL: FolioLobberTest "+label)
func _initialize() -> void:
	await process_frame
	# Export remaps text scenes to packed binary resources; query the loader,
	# not existence of the author .tscn file inside the production PCK.
	check(ResourceLoader.exists(SCENE),"new original satchel thrower resource missing")
	if failures:
		quit(1)
		return
	var view = load(SCENE).instantiate()
	root.add_child(view)
	check(view.skeleton.get_bone_count()==16,"satchel/payload/shins lack real bones")
	for clip in ["idle","walk","warning","attack","hit","death"]:
		check(view.sample_clip(clip,view.player.get_animation(clip).length*0.5),"new motion absent "+clip)
		check(view.position==Vector2.ZERO and view.rotation==0,"clip controls collision root")
		if clip!="death":
			view.cancel_action()
			for index in 16:
				check(view.skeleton.get_bone(index).transform.is_equal_approx(view.skeleton.get_bone(index).rest),"cancel doesn't restore payload / bones")
	view.free()
	var arena := Node2D.new()
	root.add_child(arena)
	var target := Target.new()
	target.position = Vector2(300,0)
	arena.add_child(target)
	var shots := Node2D.new()
	arena.add_child(shots)
	var enemy := EnemyScript.new()
	enemy.setup(EnemyScript.EnemyKind.LOBBER,0,shots,target)
	arena.add_child(enemy)
	enemy.set_physics_process(false)
	view = enemy.native_visual
	check(view!=null and enemy.static_visual==null,"actual LOBBER remains raster")
	if view==null:
		arena.free()
		quit(1)
		return
	check(enemy.body_radius==17 and enemy.contact_damage==24 and enemy.health.max_health==72 and enemy.speed==141,"art alters balance")
	check(enemy.should_show_health_bar() and not enemy.should_show_status_marker(),"no small enemy health bar")
	enemy.velocity = Vector2(100,0)
	enemy._update_static_motion(0.12)
	check(view.player.current_animation=="walk" and view.skeleton.get_node("Torso/LegL/ShinL").rotation!=0,"no articulated walking")
	enemy.ranged_is_winding_up = true
	check(enemy.ranged_windup_duration>=0.55,"shared human-reactable warning retained")
	enemy.ranged_windup_remaining = enemy.ranged_windup_duration*0.5
	enemy.ranged_target_position = Vector2(300,0)
	enemy._update_static_motion(0)
	check(view.player.current_animation=="warning" and absf(view.player.current_animation_position-0.175)<0.001 and enemy.should_show_attack_marker(),"warning not real combat clock")
	var release: Node2D = view.get_node("Facing/Skeleton2D/Torso/ArmR/ForearmR/HandR/Payload/Release")
	var origin: Vector2 = release.global_position
	enemy._update_lobber(enemy.ranged_windup_remaining+0.01,target)
	enemy._update_static_motion(0)
	check(shots.get_child_count()==1 and view.player.current_animation=="attack","throw duplicated / no actual recoil")
	var lob = shots.get_child(0)
	lob.set_physics_process(false)
	check(lob.start_position.is_equal_approx(origin) and origin.distance_to(enemy.global_position)>10,"lob doesn't start at held payload")
	check(lob.damage==48 and lob.splash_radius==72 and lob.flight_duration==0.9,"lob changes gameplay numbers")
	# Godot clamps zero Node2D scale to 0.00001; this collapses the 22px pouch
	# below 0.001px without demanding a singular transform from the engine.
	check(release.get_parent().scale.length_squared()<0.00000001,"thrown payload remains visible in hand")
	for index in 6:
		enemy._update_static_motion(0.01)
	check(shots.get_child_count()==1,"visual emits duplicate lob")
	lob._physics_process(0.9)
	lob._explode()
	check(target.hits==[48.0],"landing / repeated explosion damages twice")
	await process_frame
	enemy._update_static_motion(0.25)
	check(view.player.current_animation=="walk" and release.get_parent().scale==Vector2.ONE,"payload doesn't reset after throw")
	# Hand emission must not cross terrain or put the visible pouch outside bounds.
	enemy.world_bounds = Rect2(-20,-20,40,40)
	check(enemy.native_motion.get_safe_release(enemy)==enemy.global_position,"release escapes world bounds")
	enemy.world_bounds = Rect2()
	view.sample_clip("warning",0.175)
	origin = release.global_position
	var wall := StaticBody2D.new()
	wall.collision_layer = enemy.collision_mask
	wall.position = origin*0.5
	var wall_shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(8,8)
	wall_shape.shape = rectangle
	wall.add_child(wall_shape)
	arena.add_child(wall)
	await physics_frame
	check(enemy.native_motion.get_safe_release(enemy)==enemy.global_position,"held release shoots through a wall")
	wall.free()
	await physics_frame
	check(enemy.native_motion.get_safe_release(enemy).is_equal_approx(origin),"clear hand release does not recover")
	# A wall near, but not on, the root-to-hand line still intersects pouch radius.
	wall = StaticBody2D.new()
	wall.collision_layer = enemy.collision_mask
	wall.position = origin+Vector2(0,7)
	wall_shape = CollisionShape2D.new()
	rectangle = RectangleShape2D.new()
	rectangle.size = Vector2(2,2)
	wall_shape.shape = rectangle
	wall.add_child(wall_shape)
	arena.add_child(wall)
	await physics_frame
	check(enemy.native_motion.get_safe_release(enemy)==enemy.global_position,"pouch radius intersects terrain")
	wall.free()
	view.cancel_action()
	enemy.take_damage(1)
	check(view.player.current_animation=="hit","hit pose missing")
	enemy.ranged_is_winding_up = true
	target.stealthed = true
	enemy._physics_process(0.01)
	check(not enemy.ranged_is_winding_up and not enemy.should_show_attack_marker(),"hidden target leaves live throw")
	target.stealthed = false
	enemy.ranged_is_winding_up = true
	enemy.apply_spawn_impulse(Vector2.ZERO,0.1)
	enemy._physics_process(0.01)
	check(not enemy.ranged_is_winding_up,"spawn motion leaves stale throw")
	enemy._update_enemy_facing(Vector2(-300,0))
	check(view.get_node("Facing").scale.x==-1 and enemy.rotation==0,"wrong mirror / spinning actor")
	var pose: Transform2D = view.skeleton.get_bone(0).transform
	paused = true
	await process_frame
	await process_frame
	check(view.skeleton.get_bone(0).transform.is_equal_approx(pose),"paused thrower moves")
	paused = false
	var at: Transform2D = view.global_transform
	enemy.take_damage(1000)
	check(view.get_parent()==arena and view.global_transform.is_equal_approx(at) and view.player.current_animation=="death","death doesn't detach without drift")
	view.player.advance(0.6)
	await process_frame
	check(not is_instance_valid(view),"death leaks")
	arena.free()
	await process_frame
	if not failures:
		print("TEST PASS: FolioLobberTest %d" % checks)
	quit(1 if failures else 0)
