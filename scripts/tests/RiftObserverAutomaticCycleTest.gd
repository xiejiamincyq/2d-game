extends SceneTree
## Controlled routing with actual Health. Immunity isolates routing, NOT dodge proof.
const Boss = preload("res://scripts/actors/RiftObserverBoss.gd")
const PlayerScript = preload("res://scripts/actors/Player.gd")
var checks := 0
var failures := 0
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error("TEST FAIL: RiftObserverAutomaticCycleTest "+label)
func run() -> void:
	for phase in [1,2,3]:
		var host := Node2D.new(); root.add_child(host)
		var shots := Node2D.new(); host.add_child(shots)
		var player := PlayerScript.new(); player.position = Vector2(240,0); host.add_child(player); player.set_physics_process(false)
		player.health.begin_invulnerability(100)
		var boss := Boss.new(); boss.world_bounds = Rect2(-1000,-1000,2000,2000); boss.setup(6,shots,player); host.add_child(boss); boss.set_physics_process(false)
		var combat = boss.get_attack_director(); combat.advance(1.4); boss._update_entrance_reveal()
		if phase>1: boss.take_damage(boss.health.max_health*(0.31 if phase==2 else 0.80)); combat.advance(0.65)
		if phase==3: combat.advance(0.65)
		check(combat.current_phase==phase and combat.get_state_name()=="PHASE_%d"%phase,"real Health does not reach phase")
		await physics_frame
		var seen: Array[StringName] = []; var serial: int = combat.action_serial
		var first_pose: Dictionary = {}; var completed := 0; var prior_active := false
		for _step in range(3000):
			combat.advance(1.0/120)
			if combat.action_serial!=serial:
				serial = combat.action_serial
				if combat.action_stage==combat.Stage.WARNING:
					seen.append(combat.action); first_pose[combat.action] = boss.get_visual_node().player.current_animation
			if prior_active and not combat.is_attacking():
				completed += 1
				check(is_equal_approx(combat.attack_gap,1.1 if phase<3 else 0.85),"phase pressure gap lost")
			prior_active = combat.is_attacking()
			if seen.size()>=6 and not combat.is_attacking(): break
		check(seen==[&"beam",&"probes",&"refract",&"beam",&"probes",&"refract"] and completed==6,"automatic two-round three-action cycle absent phase%s: %s"%[phase,seen])
		if failures: host.free(); await process_frame; quit(1); return
		for kind in [&"beam",&"probes",&"refract"]: check(first_pose[kind]==String(kind)+"_warning","automatic native warning disconnected")
		check(player.health.current_health==100 and shots.get_child_count()==0 and boss.scale==Vector2.ONE and boss.rotation==0,"routing fixture changes root or creates uncontrolled projectile Nodes")
		combat.cancel_action(); host.free(); await process_frame
	var host := Node2D.new(); root.add_child(host)
	var shots := Node2D.new(); host.add_child(shots)
	var player := PlayerScript.new(); player.position = Vector2(600,0); host.add_child(player); player.set_physics_process(false); player.health.begin_invulnerability(100)
	var boss := Boss.new(); boss.world_bounds = Rect2(-1000,-1000,2000,2000); boss.setup(6,shots,player); host.add_child(boss); boss.set_physics_process(false)
	var combat = boss.get_attack_director(); combat.advance(1.4); boss._update_entrance_reveal()
	for _step in range(200): combat.advance(1.0/120)
	check(not combat.is_attacking() and combat.attack_gap>0 and combat.attack_gap<=0.2,"out-of-range automatic loop spins/fires")
	player.position = Vector2(240,0); await physics_frame
	var started := 0
	for _step in range(1000):
		combat.advance(1.0/120)
		if combat.action_stage==combat.Stage.WARNING and combat.action_elapsed==0: started += 1
		if started==2 and not combat.is_attacking(): break
	check(started==2 and combat.action==&"","blocked-origin fixture did not complete first two automatic actions")
	var wall := StaticBody2D.new(); wall.collision_layer = 2; wall.collision_mask = 0; wall.position = boss.get_visual_node().skeleton.get_node(boss.SOCKETS[&"refract"]).global_position
	var collision := CollisionShape2D.new(); var shape := RectangleShape2D.new(); shape.size = Vector2(24,24); collision.shape = shape; wall.add_child(collision); host.add_child(wall); await physics_frame
	for _step in range(160):
		combat.advance(1.0/120)
		if combat.is_attacking(): break
	check(combat.action==&"beam" and combat.action_stage==combat.Stage.WARNING,"blocked strict Beacon stalls all automatic actions or substitutes a fake refract")
	check(not combat.refract.fragments[0].armed and boss.should_show_attack_marker(),"fallback lost actual warning")
	combat.cancel_action(); wall.free(); host.free(); await process_frame
	if not failures: print("TEST PASS: RiftObserverAutomaticCycleTest %d"%checks)
	quit(1 if failures else 0)
func _initialize() -> void: call_deferred("run")
