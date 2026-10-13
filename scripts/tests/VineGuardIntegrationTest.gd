extends SceneTree
const Director = preload("res://scripts/systems/NurseryEncounterDirector.gd")
const Legacy = preload("res://scripts/actors/OverseerBoss.gd")
var checks := 0
var failures := 0
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("TEST FAIL: VineGuardIntegrationTest "+label)
func _initialize() -> void:
	await process_frame
	var arena := Node2D.new()
	root.add_child(arena)
	var target := Node2D.new()
	target.position = Vector2(300,0)
	arena.add_child(target)
	var director := Director.new()
	arena.add_child(director)
	director.set_process(false)
	director.player = target
	director.enemy_parent = arena
	director.projectile_parent = arena
	director.world_bounds = Rect2(-1000,-1000,2000,2000)
	var boss = director._spawn_boss_at(Vector2.ZERO)
	boss.set_physics_process(false)
	var view = boss.get("native_visual")
	check(view!=null and boss.boss_visual==null,"actual chapter factory still spawns raster Overseer")
	if view==null:
		arena.free()
		quit(1)
		return
	check(view.skeleton.get_bone_count()==22,"actual rig is incomplete")
	check(boss.health.max_health==10800 and boss.body_radius==56 and boss.MOVE_SPEED==63.8,"art alters transitional combat numbers")
	check(boss.get_visual_node()==view and boss.get_visual_rect()==view.body_rect,"camera/occlusion visual contract absent")
	var entrance_signals := [0]
	boss.entrance_finished.connect(func(): entrance_signals[0]+=1)
	for step in 13:
		boss._physics_process(0.1)
		check(boss.scale==Vector2.ONE and boss.rotation==0 and boss.modulate.a==1,"entrance shrinks/rotates/translucent collision root")
		check(not boss.take_damage(1),"entrance immunity changed")
	check(view.player.current_animation=="entrance" and not boss.entrance_resolved,"entrance isn't controlled by real boss clock")
	boss._physics_process(0.11)
	check(boss.entrance_resolved and entrance_signals[0]==1,"real entrance did not finish once")
	var at: Transform2D = boss.global_transform
	boss.velocity = Vector2(60,0)
	boss._update_boss_motion(0.3)
	check(view.player.current_animation=="walk" and absf(view.skeleton.get_node("Torso/LegL/ShinL").rotation)>0.05,"actual gait lacks knees")
	check(boss.global_transform==at,"visual gait moves hitbox")
	var health_before: float = boss.health.current_health
	boss.take_damage(1)
	check(boss.health.current_health==health_before-1 and view.player.current_animation=="hit","real damage fails to drive recoil")
	boss.velocity = Vector2.ZERO
	boss._update_boss_motion(0.3)
	check(view.player.current_animation=="idle","recoil never settles")
	boss._update_visual_facing(Vector2(-100,0))
	check(view.get_node("Facing").scale.x==-1 and boss.rotation==0,"boss spins instead of mirroring")
	check(boss.get_visual_rect()==Transform2D(0,Vector2(-1,1),0,Vector2.ZERO)*view.body_rect,"mirrored camera/occlusion bounds wrong")
	var pose: Transform2D = view.skeleton.get_bone(0).transform
	paused = true
	await process_frame
	await process_frame
	check(view.skeleton.get_bone(0).transform.is_equal_approx(pose),"paused boss skeleton moves")
	paused = false
	var deaths := [0]
	boss.died.connect(func(_actor,_coins,_source): deaths[0]+=1)
	var corpse_at: Transform2D = view.global_transform
	boss.take_damage(1e9)
	check(view.get_parent()==arena and view.global_transform.is_equal_approx(corpse_at) and view.player.current_animation=="death","death corpse drift/lifecycle")
	boss.take_damage(1e9)
	check(deaths[0]==1,"death duplicated")
	view.player.advance(1.0)
	await process_frame
	check(not is_instance_valid(view),"corpse leaked")
	var legacy := Legacy.new()
	legacy.setup(0,arena,target)
	arena.add_child(legacy)
	legacy.set_physics_process(false)
	check(legacy.get_visual_node()==legacy.boss_visual and legacy.boss_visual.scene_file_path=="res://scenes/actors/native/root_overseer_paper_v1.tscn" and legacy.get_visual_rect()==legacy.boss_visual.get_node("Facing").transform*legacy.boss_visual.body_rect,"old-wave native visual interface broken")
	arena.free()
	await process_frame
	if not failures:
		print("TEST PASS: VineGuardIntegrationTest %d" % checks)
	quit(1 if failures else 0)
