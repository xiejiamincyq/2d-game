extends SceneTree
const SOURCE := "res://scripts/actors/SaltTideBoss.gd"
class Target extends CharacterBody2D:
	var hits: Array[float] = []
	func get_body_radius() -> float: return 13.0
	func is_alive() -> bool: return true
	func take_damage(amount: float,_source: StringName = &"") -> void: hits.append(amount)
var checks := 0
var failures := 0
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("TEST FAIL: TideShellIntegrationTest "+label)
func _initialize() -> void: call_deferred("run")
func advance_warning(combat: Node,seconds: float = -1.0) -> void:
	var remaining: float = combat.DURATIONS[combat.action][0] if seconds<0 else seconds
	while remaining>0.0000001:
		var step := minf(1.0/120.0,remaining)
		combat.advance(step)
		remaining -= step

func run() -> void:
	check(ResourceLoader.exists(SOURCE),"actual native Salt Boss missing")
	if failures: quit(1); return
	var host := Node2D.new(); root.add_child(host)
	var shots := Node2D.new(); host.add_child(shots)
	var target := Target.new(); target.position = Vector2(200,0); host.add_child(target)
	var boss = load(SOURCE).new(); boss.setup(3,shots,target); host.add_child(boss)
	boss.set_physics_process(false)
	var body = boss.get_visual_node()
	var combat = boss.get_attack_director()
	check(body.scene_file_path=="res://scenes/actors/native/tide_shell_paper_v2.tscn" and body.skeleton.get_bone_count()==25,"actual actor falls back to old body")
	check(boss.get_tentacle_attack()==null and boss.find_children("*","CollisionShape2D",false,false).size()==1,"legacy attack node or changed physical footprint")
	check(boss.body_radius==56 and boss.scale==Vector2.ONE and boss.rotation==0 and boss.modulate.a==1,"art alters physical root")
	var initial_health: float = boss.health.current_health
	boss.take_damage(200)
	check(boss.health.current_health==initial_health,"entrance damage bypass")
	combat.advance(1.4); boss._update_entrance_reveal(); combat.attack_gap = 99
	check(boss.entrance_resolved and body.player.current_animation=="entrance","entrance cannot resolve")
	for action in [&"ripple",&"pincer",&"salt"]:
		# Warning art is normalized to the slower combat telegraph; active and
		# recovery clips still share the authoritative seconds directly.
		for stage in [1,2]:
			check(is_equal_approx(body.player.get_animation(String(action)+["_warning","_attack","_recovery"][stage]).length,combat.DURATIONS[action][stage]),"bone duration differs from authoritative clock")
		combat.cancel_action()
		check(combat.start_action(action) and boss.should_show_attack_marker(),"real short head warning absent")
		boss._update_boss_motion(0)
		check(body.player.current_animation==String(action)+"_warning","warning not read from actual stage")
		var warning_clip := String(action)+"_warning"
		var warning_length: float = body.player.get_animation(warning_clip).length
		for warning_fraction in [0.2,0.5,0.8]:
			combat.action_elapsed = combat.DURATIONS[action][0]*warning_fraction
			boss._update_boss_motion(0)
			check(is_equal_approx(body.player.current_animation_position,warning_length*warning_fraction),"warning pose not normalized to unique combat clock")
			check(is_equal_approx(combat.action_elapsed,combat.DURATIONS[action][0]*warning_fraction),"visual adapter advanced authoritative warning")
		combat.action_elapsed = 0
		advance_warning(combat)
		boss._update_boss_motion(0)
		check(body.player.current_animation==String(action)+"_attack" and not boss.should_show_attack_marker(),"active pose/head marker mismatch")
		combat.advance(combat.DURATIONS[action][1])
		boss._update_boss_motion(0)
		check(body.player.current_animation==String(action)+"_recovery","recovery not bound")
		combat.advance(combat.DURATIONS[action][2])
		boss._update_boss_motion(0)
		check(body.player.current_animation=="idle" and not combat.is_attacking(),"action clock duplicated")
	# Actual articulated sockets, including left mirror and active jaw, not constants.
	for left in [false,true]:
		body.set_facing_left(left)
		for phase in [0.0,0.12,0.27]:
			body.sample_clip("pincer_attack",phase)
			var points: Array[Vector2] = boss.get_claw_origins()
			check(points.size()==2 and points[0]==body.get_node("Facing/Skeleton2D/Torso/ShoulderL/ArmL/PincerL/ClawOrigin").global_position,"left claw socket fabricated")
			check(points[1]==body.get_node("Facing/Skeleton2D/Torso/ShoulderR/ArmR/PincerR/ClawOrigin").global_position,"right claw socket fabricated")
		body.sample_clip("salt_attack",0.1)
		check(boss.get_safe_salt_origin()==body.get_node("Facing/Skeleton2D/Torso/Head/Jaw/SaltOrigin").global_position,"jaw not used on open floor")
	combat.cancel_action(); body.set_facing_left(false)
	# Stand in the actual left stroke arc. A hitch must not skip its return arc.
	check(combat.start_action(&"pincer"),"actual sweep fixture absent")
	advance_warning(combat)
	body.sample_clip("pincer_attack",0.10)
	target.position = boss.get_claw_origins()[0]
	body.sample_clip("pincer_attack",0)
	var before: int = target.hits.size()
	combat.advance(0.36*0.52)
	check(target.hits.size()==before+1,"hitch misses actual curved return stroke")
	combat.advance(0.36)
	check(target.hits.size()==before+1,"second pincer stroke repeats same cast")
	combat.cancel_action(); target.position = Vector2(200,0)
	var summons: Array[int] = []
	boss.reinforcements_requested.connect(func(_boss,count): summons.append(count))
	boss.take_damage(initial_health*0.4)
	check(combat.get_state_name()=="TRANSITION_1" and summons==[2],"actual health phase not bound")
	combat.advance(0.65); boss.take_damage(initial_health*0.3)
	check(combat.get_state_name()=="TRANSITION_2" and summons==[2,3],"actual second finite phase missing")
	combat.advance(0.65)
	check(combat.start_action(&"salt"),"real death cancellation fixture absent")
	advance_warning(combat)
	check(combat.owned_projectiles.size()==3,"actual bone-origin fan not spawned")
	boss.take_damage(initial_health)
	check(boss.death_resolved and combat.get_state_name()=="DEATH" and combat.owned_projectiles.is_empty() and boss.get_visual_node()==null,"death does not release/cancel native body")
	await process_frame; await process_frame
	check(shots.get_child_count()==0,"Boss-owned projectiles leaked")
	host.free(); await process_frame
	if not failures: print("TEST PASS: TideShellIntegrationTest %d" % checks)
	quit(1 if failures else 0)
