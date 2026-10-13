extends SceneTree
## Actual native Actor/physics/pause/Health/death; controlled phase damage, not victory.
const Boss = preload("res://scripts/actors/RiftObserverBoss.gd")
const PlayerScript = preload("res://scripts/actors/Player.gd")
var checks := 0
var failures := 0
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error("TEST FAIL: RiftObserverIntegrationTest "+label)
func bone_pose(view: Node) -> Array[Transform2D]:
	var result: Array[Transform2D] = []
	for index in view.skeleton.get_bone_count(): result.append(view.skeleton.get_bone(index).transform)
	return result
func run() -> void:
	for input in ["move_left","move_right","move_up","move_down","fire","dash_melee"]: Input.action_release(input)
	var host := Node2D.new(); root.add_child(host)
	var shots := Node2D.new(); host.add_child(shots)
	var player := PlayerScript.new(); player.position = Vector2(240,0); host.add_child(player); player.set_physics_process(false)
	var boss := Boss.new(); boss.world_bounds = Rect2(-1000,-1000,2000,2000); boss.setup(6,shots,player); host.add_child(boss); boss.set_physics_process(false)
	var view := boss.get_visual_node(); var combat = boss.get_attack_director()
	check(view.scene_file_path=="res://scenes/actors/native/rift_observer_paper_v2.tscn" and view.skeleton.get_bone_count()==30 and view.player.get_animation_list().size()==14,"not the actual new30/14 native Actor")
	check(boss.scale==Vector2.ONE and boss.rotation==0 and boss.modulate.a==1 and boss.body_radius==56 and boss.health.max_health==10800,"root/collision/HP changed")
	var body_at := boss.global_transform; var entrance_pose := bone_pose(view); var entrances := [0]; var deaths := [0]
	boss.entrance_finished.connect(func(): entrances[0] += 1)
	boss.died.connect(func(_actor,_coins,_source): deaths[0] += 1)
	boss.take_damage(100)
	check(boss.health.current_health==10800 and not combat.start_action(&"beam"),"entrance damage/attack immunity lost")
	boss._physics_process(0.7)
	check(view.player.current_animation=="entrance" and bone_pose(view)!=entrance_pose and boss.global_transform==body_at and entrances[0]==0,"entrance does not articulate independently of physical root")
	boss._physics_process(0.71); combat.attack_gap = 99
	check(boss.entrance_resolved and entrances[0]==1 and boss.process_mode==Node.PROCESS_MODE_PAUSABLE and combat.current_phase==1,"entrance not one-time/pausable")
	boss.set_physics_process(true); var before := boss.global_position
	for _frame in range(8): await physics_frame
	check(boss.global_position.distance_to(before)>0.5 and view.player.current_animation=="walk" and not combat.is_attacking(),"actual physics never moves with native gait")
	check(boss.scale==Vector2.ONE and boss.rotation==0 and boss.modulate.a==1,"actual locomotion rotates/fades physical root")
	check(boss.apply_burn_stack(10,2.0),"real finite burn fixture cannot start")
	await physics_frame; await process_frame
	var paused_at := boss.global_transform; var paused_pose := bone_pose(view); var paused_health: float = boss.health.current_health
	var paused_clock: float = combat.state_elapsed; var paused_motion: float = boss.boss_motion.locomotion_time
	paused = true
	for _frame in range(12): await physics_frame; await process_frame
	check(boss.global_transform==paused_at and bone_pose(view)==paused_pose,"actual paused body/bones move")
	check(boss.health.current_health==paused_health and combat.state_elapsed==paused_clock and boss.boss_motion.locomotion_time==paused_motion,"pause advances burn/combat/animation clock")
	paused = false
	for _frame in range(8): await physics_frame
	check(boss.global_transform!=paused_at and boss.health.current_health<paused_health and combat.state_elapsed>paused_clock,"unpause fails to resume actual movement and finite burn")
	boss.set_physics_process(false); body_at = boss.global_transform
	boss._update_visual_facing(boss.global_position+Vector2(-100,0))
	check(view.get_node("Facing").scale.x==-1 and boss.rotation==0 and boss.get_visual_rect().is_equal_approx(view.get_node("Facing").transform*view.body_rect),"mirrored native skin or camera bounds drift")
	boss.take_damage(1)
	check(view.player.current_animation=="hit" and view.get_node("Facing/Skin").material==boss.boss_flash_material and float(boss.boss_flash_material.get_shader_parameter("flash_amount"))==boss.HIT_FLASH_AMOUNT,"real hit recoil/skin-only flash absent")
	boss.velocity = Vector2.ZERO; boss._update_boss_motion(0.3)
	check(view.player.current_animation=="idle" and boss.global_transform==body_at,"hit recoil displaces physical root or never settles")
	boss.take_damage(boss.health.max_health*0.31)
	check(boss.get_phase()==2 and combat.state==combat.State.TRANSITION_1 and not combat.is_attacking(),"actual70percent phase cancels incorrectly")
	combat.advance(0.65); check(combat.current_phase==2 and combat.get_state_name()=="PHASE_2","actual phase2 transition unavailable")
	boss.take_damage(boss.health.max_health*0.36)
	check(boss.get_phase()==3 and combat.state==combat.State.TRANSITION_2,"actual35percent phase missing")
	combat.advance(0.65); check(combat.current_phase==3 and combat.get_state_name()=="PHASE_3" and entrances[0]==1,"actual phase3 transition replays entrance")
	var corpse_at := view.global_transform; boss.take_damage(boss.health.current_health+1)
	check(deaths[0]==1 and boss.death_resolved and combat.get_state_name()=="DEATH" and not combat.is_attacking(),"actual native death not one-shot shutdown")
	check(view.get_parent()==host and view.global_transform==corpse_at and view.player.current_animation=="death" and float(boss.boss_flash_material.get_shader_parameter("flash_amount"))==0,"native corpse drift/flash/clip mismatch")
	check(not view.cancel_action() and not view.play_clip("idle"),"death can resurrect native idle")
	boss.take_damage(1); check(deaths[0]==1,"second native death event")
	view.player.advance(1.4); await process_frame; await process_frame
	check(not is_instance_valid(boss) and not is_instance_valid(view) and shots.get_child_count()==0,"actual dead Actor/corpse leaks")
	host.free(); await process_frame
	if not failures: print("TEST PASS: RiftObserverIntegrationTest %d"%checks)
	quit(1 if failures else 0)
func _initialize() -> void: call_deferred("run")
