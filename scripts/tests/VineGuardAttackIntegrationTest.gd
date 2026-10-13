extends SceneTree
func advance_actor_warning(actor, seconds: float) -> void:
	var remaining := seconds
	while remaining > 0.0:
		var step := minf(remaining, 1.0/120.0)
		actor._physics_process(step)
		remaining = maxf(0.0, remaining-step)
const Actor = preload("res://scripts/actors/NurseryVineBoss.gd")
class Target extends Node2D:
	var stealthed := false
	var hits: Array[float] = []
	func take_damage(amount: float,_source: StringName = &"") -> void: hits.append(amount)
	func is_stealthed() -> bool: return stealthed
var checks := 0
var failures := 0
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("TEST FAIL: VineGuardAttackIntegrationTest "+label)
func _initialize() -> void:
	await process_frame
	var host := Node2D.new()
	root.add_child(host)
	var shots := Node2D.new()
	host.add_child(shots)
	var target := Target.new()
	target.position = Vector2(120,0)
	host.add_child(target)
	var boss := Actor.new()
	boss.setup(5,shots,target)
	boss.world_bounds = Rect2(-2000,-2000,4000,4000)
	host.add_child(boss)
	boss.set_physics_process(false)
	var view = boss.get_visual_node()
	check(view.scene_file_path.ends_with("vine_guard_paper_v2.tscn"),"actual first-chapter Boss still uses non-attack v1")
	if failures: host.free(); quit(1); return
	var combat = boss.get_attack_director()
	check(combat.get_script().resource_path.ends_with("VineGuardAttackDirector.gd") and boss.get_tentacle_attack()==null,"chapter Boss still instantiates old tentacle/pattern controllers")
	check(boss.health.max_health==10800 and boss.body_radius==56 and boss.scale==Vector2.ONE and boss.modulate.a==1,"new actions change physical body or baseline HP")
	var entered := [0]
	boss.entrance_finished.connect(func(): entered[0]+=1)
	boss._physics_process(1.3)
	check(view.player.current_animation=="entrance" and not boss.take_damage(1),"entrance lacks native reveal/immunity")
	boss._physics_process(0.11)
	check(boss.entrance_resolved and entered[0]==1,"entrance signal not exact")
	combat.attack_gap = 99
	# The authored clips keep their approved lengths. Gameplay warnings sample
	# the same normalized bone pose even when their authoritative duration grows.
	for kind in [&"lash",&"roots",&"seeds"]:
		check(combat.start_action(kind),"normalized warning fixture cannot arm "+str(kind))
		advance_actor_warning(boss,combat.DURATIONS[kind][0]*0.5)
		var warning_clip := str(kind)+"_warning"
		var actual_pose: Array[Transform2D] = []
		for index in view.skeleton.get_bone_count(): actual_pose.append(view.skeleton.get_bone(index).transform)
		view.sample_clip(warning_clip,view.player.get_animation(warning_clip).length*0.5)
		for index in actual_pose.size():
			check(actual_pose[index].is_equal_approx(view.skeleton.get_bone(index).transform),"warning bones do not follow normalized authoritative time "+str(kind))
		combat.cancel_action()
	check(combat.start_action(&"lash"),"actual lash cannot start")
	advance_actor_warning(boss,0.1)
	check(view.player.current_animation=="lash_warning" and boss.velocity==Vector2.ZERO and target.hits.is_empty(),"actual native warning/movement/damage mismatch")
	boss.take_damage(1)
	check(view.player.current_animation=="lash_warning","dense fire hides armed attack")
	target.position = Vector2(-120,0)
	advance_actor_warning(boss,combat.DURATIONS[&"lash"][0]-0.1+0.01)
	check(view.get_node("Facing").scale.x==1 and view.player.current_animation=="lash_attack" and target.hits.is_empty(),"warning tracks target or native impact absent")
	target.position = Vector2(120,0)
	boss._physics_process(0.03)
	check(target.hits==[54.0],"entering active vine arc never hits once")
	boss._physics_process(0.2)
	check(view.player.current_animation=="lash_recovery" and target.hits==[54.0],"native recovery/unique damage missing")
	var requests: Array[int] = []
	boss.reinforcements_requested.connect(func(_boss,count): requests.append(count))
	boss.take_damage(3300)
	check(combat.get_state_name()=="TRANSITION_1" and not combat.is_attacking() and requests==[6],"actual damage does not cancel attack/start phase transition")
	boss._physics_process(0.65)
	combat.attack_gap = 99
	check(combat.current_phase==2 and combat.start_action(&"roots"),"second phase/root action missing")
	advance_actor_warning(boss,0.2)
	check(view.player.current_animation=="roots_warning" and combat.root_centers.size()==3,"actual root warning lacks locked centers")
	advance_actor_warning(boss,combat.DURATIONS[&"roots"][0]-0.2-0.01)
	check(view.player.current_animation=="roots_warning" and target.hits==[54.0],"root warning hurts before configured duration")
	boss._physics_process(0.02)
	check(view.player.current_animation=="roots_attack" and target.hits==[54.0,60.0],"root impact/damage mismatch")
	combat.cancel_action()
	target.position = Vector2(400,0)
	combat.start_action(&"seeds")
	advance_actor_warning(boss,0.1)
	check(view.player.current_animation=="seeds_warning","actual crown preparation missing")
	var firing_origins: Array[Vector2] = []
	var record_origin := func(_shot: Node): firing_origins.append(boss.get_safe_seed_origin())
	shots.child_entered_tree.connect(record_origin)
	advance_actor_warning(boss,combat.DURATIONS[&"seeds"][0]-0.1+0.01)
	shots.child_entered_tree.disconnect(record_origin)
	check(view.player.current_animation=="seeds_attack" and shots.get_child_count()==3,"native firing pose and actual seed fan disagree")
	# Later controlled slices advance the bones but not these projectiles.
	# Capture the actual release socket, never substitute the later pose.
	var emitter: Vector2 = firing_origins[0] if not firing_origins.is_empty() else Vector2.ZERO
	check(firing_origins.size()==3 and firing_origins.all(func(at): return at.is_equal_approx(emitter)),"all seeds observe the actual release socket")
	check(emitter.distance_to(boss.position)>70,"crown socket ignored")
	for shot in shots.get_children():
		shot.set_physics_process(false)
		check(shot.position.is_equal_approx(emitter) and shot.source_actor_id==boss.get_instance_id(),"actual seed origin/owner mismatch")
	var pose: Transform2D = view.skeleton.get_bone(0).transform
	paused = true
	await process_frame
	await process_frame
	check(view.skeleton.get_bone(0).transform==pose,"paused Boss runs independent attack animation")
	paused = false
	target.stealthed = true
	boss._physics_process(0.02)
	check(not combat.is_attacking(),"hidden target retains attack")
	await process_frame
	check(shots.get_child_count()==0,"hidden target retains owned seeds")
	target.stealthed = false
	boss._physics_process(0.02)
	boss.take_damage(5000)
	boss._physics_process(0.65)
	combat.attack_gap = 99
	check(combat.current_phase==3 and requests==[6,8] and combat.start_action(&"seeds"),"third phase/progression absent")
	advance_actor_warning(boss,combat.DURATIONS[&"seeds"][0]+0.01)
	check(shots.get_child_count()==5,"actual third-phase fan lacks five seeds")
	var deaths := [0]
	boss.died.connect(func(_boss,_coins,_source): deaths[0]+=1)
	boss.take_damage(1e9)
	check(combat.get_state_name()=="DEATH" and view.player.current_animation=="death" and deaths[0]==1,"death does not terminate real actions/corpse")
	view.player.advance(1.2)
	await process_frame
	check(shots.get_child_count()==0 and not is_instance_valid(view),"death leaks owned seeds or corpse")
	host.free()
	if not failures: print("TEST PASS: VineGuardAttackIntegrationTest %d"%checks)
	quit(1 if failures else 0)
