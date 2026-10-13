extends SceneTree
func advance_warning(clock, seconds: float) -> void:
	var remaining := seconds
	while remaining > 0.0:
		var step := minf(remaining, 1.0/120.0)
		clock.advance(step)
		remaining = maxf(0.0, remaining-step)
const SOURCE := "res://scripts/components/VineGuardAttackDirector.gd"
class Target extends Node2D:
	var stealthed := false
	var hits: Array[float] = []
	func is_stealthed() -> bool: return stealthed
	func take_damage(amount: float,_source: StringName = &"") -> void: hits.append(amount)
class Boss extends CharacterBody2D:
	var world_bounds := Rect2(-1000,-1000,2000,2000)
	var death_resolved := false
	func get_safe_seed_origin() -> Vector2: return global_position+Vector2(0,-100)
	func _update_boss_motion(_delta: float) -> void: pass
var checks := 0
var failures := 0
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("TEST FAIL: VineGuardAttackDirectorTest "+label)
func _initialize() -> void:
	await process_frame
	check(FileAccess.file_exists(SOURCE),"chapter-specific director missing; old Overseer mechanics remain")
	if failures: quit(1); return
	var host := Node2D.new()
	root.add_child(host)
	var boss := Boss.new()
	var target := Target.new()
	target.position = Vector2(120,0)
	var shots := Node2D.new()
	host.add_child(boss)
	host.add_child(target)
	host.add_child(shots)
	var director = load(SOURCE).new()
	boss.add_child(director)
	director.configure(boss,target,shots)
	check(director.get_state_name()=="ENTRANCE" and director.is_movement_locked(),"entrance not authoritative")
	director.advance(1.4)
	check(director.get_state_name()=="PHASE_1" and director.current_phase==1,"entrance never enters first phase")
	director.attack_gap = 99
	check(director.start_action(&"lash"),"new lash not startable")
	advance_warning(director,director.DURATIONS[&"lash"][0]-0.01)
	check(target.hits.is_empty() and director.action_stage==director.Stage.WARNING,"lash warning hits early")
	target.position = Vector2(120,0)
	director.advance(0.02)
	check(target.hits==[54.0] and director.action_stage==director.Stage.ACTIVE,"unique lash damage absent")
	director.advance(0.04)
	check(target.hits==[54.0],"lash duplicates damage")
	director.advance(0.7)
	check(not director.is_attacking(),"lash cannot finish")
	check(director.start_action(&"lash"),"second lash absent")
	target.position = Vector2(-120,0)
	advance_warning(director,director.DURATIONS[&"lash"][0]+0.01)
	check(target.hits==[54.0] and director.locked_direction.x>0,"lash tracks target through warning")
	director.cancel_action()
	target.position = Vector2(200,0)
	director.set_health_phase(2)
	check(director.get_state_name()=="TRANSITION_1" and not director.is_attacking(),"phase transition fails to cancel")
	director.advance(0.65)
	check(director.current_phase==2,"second phase absent")
	director.attack_gap = 99
	check(director.start_action(&"roots") and director.root_centers.size()==3,"locked triple root positions absent")
	var locked: Vector2 = director.root_centers[1]
	target.position = Vector2(-500,500)
	advance_warning(director,director.DURATIONS[&"roots"][0]+0.01)
	check(target.hits==[54.0] and director.root_centers[1]==locked,"roots follow moved target or hit outside circles")
	director.cancel_action()
	target.position = Vector2(200,0)
	check(director.start_action(&"roots"),"root repeat absent")
	advance_warning(director,director.DURATIONS[&"roots"][0]+0.01)
	check(target.hits==[54.0,60.0],"three root circles cause repeat damage")
	director.cancel_action()
	target.position = Vector2(980,980)
	check(director.start_action(&"roots"),"boundary roots fail completely")
	for i in director.root_centers.size():
		for j in range(i+1,director.root_centers.size()):
			check(director.root_centers[i].distance_to(director.root_centers[j])>=director.ROOT_RADIUS*2,"clamped root warnings overlap at world corner")
	director.cancel_action()
	target.position = Vector2(200,0)
	check(director.start_action(&"seeds"),"seed fan absent")
	advance_warning(director,director.DURATIONS[&"seeds"][0]+0.01)
	check(shots.get_child_count()==3,"phase two is not three original seeds")
	for shot in shots.get_children():
		shot.set_physics_process(false)
		check(shot.get_script().resource_path.ends_with("VineSeedProjectile.gd") and shot.global_position==boss.get_safe_seed_origin() and shot.damage==18 and shot.radius==6,"seed resource/socket/numbers disagree")
	director.set_target_hidden(true)
	check(not director.is_attacking(),"hidden target keeps armed action")
	await process_frame
	check(shots.get_child_count()==0,"hidden target leaves owned seed projectiles")
	director.advance(5)
	check(shots.get_child_count()==0,"hidden scheduler still emits")
	director.set_target_hidden(false)
	director.set_health_phase(3)
	director.advance(0.65)
	director.attack_gap = 99
	check(director.start_action(&"seeds"),"third-phase seeds absent")
	advance_warning(director,director.DURATIONS[&"seeds"][0]+0.01)
	check(shots.get_child_count()==5,"third phase not stronger five-seed fan")
	director.shutdown()
	await process_frame
	check(director.get_state_name()=="DEATH" and shots.get_child_count()==0 and not director.start_action(&"lash"),"death retains attacks/projectiles")
	host.free()
	if not failures: print("TEST PASS: VineGuardAttackDirectorTest %d"%checks)
	quit(1 if failures else 0)
