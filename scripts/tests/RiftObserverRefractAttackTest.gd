extends SceneTree
## Actual unique Director and articulated Beacon; controlled clock, not natural play.
const Boss = preload("res://scripts/actors/RiftObserverBoss.gd")
const PlayerScript = preload("res://scripts/actors/Player.gd")
var checks := 0
var failures := 0
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error("TEST FAIL: RiftObserverRefractAttackTest "+label)
func step(combat: Node,seconds: float) -> void:
	var remaining := seconds
	while remaining>0.000001:
		var dt := minf(remaining,1.0/120); combat.advance(dt); remaining -= dt
func armed_count(combat: Node) -> int:
	var count := 0
	for fragment in combat.refract.fragments:
		if fragment.armed: count += 1
	return count
func reset(player: Node) -> void:
	player.health.current_health = 100; player.health.invulnerable_time = 0
func run() -> void:
	var host := Node2D.new(); root.add_child(host)
	var shots := Node2D.new(); host.add_child(shots)
	var player := PlayerScript.new(); player.position = Vector2(240,0); host.add_child(player); player.set_physics_process(false)
	var boss := Boss.new(); boss.world_bounds = Rect2(-1000,-1000,2000,2000); boss.setup(6,shots,player); host.add_child(boss); boss.set_physics_process(false)
	var combat = boss.get_attack_director()
	check(not combat.start_action(&"refract"),"actual entrance bypass")
	combat.advance(1.4); boss._update_entrance_reveal(); combat.attack_gap = 99
	check(combat.start_action(&"refract"),"actual three-batch refract missing from unique director")
	if failures: host.free(); await process_frame; quit(1); return
	combat.cancel_action(); await physics_frame
	check(player.move_speed==235 and player.health.max_health==100 and is_equal_approx(player.get_body_radius(),16.9),"ordinary Player altered")
	check(combat.refract.fragments.size()==9 and not combat.refract.has_method("_physics_process") and combat.probe_canvas.z_index==22 and not combat.probe_canvas.is_processing(),"bounded nine slots or sole clock changed")
	for rate in [30,60,120]:
		for facing in [-1,1]:
			reset(player); player.position = Vector2(240*facing,0)
			check(combat.start_action(&"refract"),"implemented refract starts")
			var origin: Vector2 = combat.locked_origin; var direction: Vector2 = combat.locked_direction
			var distance: float = combat.refract.path_length
			check(origin.is_equal_approx(boss.get_action_origin(&"refract",4,true)) and direction.is_equal_approx(origin.direction_to(player.global_position)) and is_equal_approx(distance,origin.distance_to(player.global_position)),"warning locks real Beacon and fixed length")
			check(boss.should_show_attack_marker() and boss.get_visual_node().player.current_animation=="refract_warning" and armed_count(combat)==0,"warning loses locked ranges or births prematurely")
			player.position += Vector2(0,200); step(combat,combat.DURATIONS[&"refract"][0])
			check(combat.action_stage==combat.Stage.ACTIVE and armed_count(combat)==0 and player.health.current_health==100 and not boss.should_show_attack_marker(),"active opens with early damage/geometry")
			var root_at := boss.global_transform; var births := [0,0,0]; var iterations := 0
			while combat.action_stage==combat.Stage.ACTIVE and iterations<100:
				combat.advance(1.0/rate); iterations += 1
				check(combat.locked_direction==direction and combat.refract.path_length==distance and boss.global_transform==root_at,"refract tracks Player or rotates/moves physical root")
				for batch in range(3):
					if combat.refract.released[batch] and births[batch]==0:
						births[batch] += 1
						var at: Vector2 = combat.refract.origins[batch]
						check(at.is_equal_approx(boss.get_action_origin(&"refract",4,true)) and combat.refract.births[batch]>=combat.refract.RELEASES[batch] and combat.refract.births[batch]<combat.refract.RELEASES[batch]+1.0/rate+0.00001,"batch born at true sampled Beacon with one-clock quantization")
						for offset in range(3):
							var fragment: RefCounted = combat.refract.fragments[batch*3+offset]
							var expected: Vector2 = at+direction.rotated(combat.refract.ANGLES[batch][offset])*distance
							check(fragment.armed and fragment.age==0 and fragment.origin==at and fragment.position==at and fragment.landing.is_equal_approx(expected),"one of nine births is retroactive, follows target or uses fake origin")
				check(armed_count(combat)<=3 and player.health.current_health==100,"batches overlap excessively or track moved Player")
			check(iterations<100 and births==[1,1,1] and armed_count(combat)==0 and combat.action_stage==combat.Stage.RECOVERY,"three finite batches fail to close within active")
			check(boss.get_visual_node().player.current_animation=="refract_recovery","native recovery disconnected")
			step(combat,0.60); check(not combat.is_attacking(),"recovery fails to finish")
	# First two fans leave a true central gap; the third locks the central counter-hit.
	reset(player); player.position = Vector2(240,0); check(combat.start_action(&"refract"),"standing gap control starts")
	step(combat,combat.DURATIONS[&"refract"][0]); step(combat,0.46)
	check(player.health.current_health==100 and not combat.refract.attempt.attempted and combat.refract.released==[true,true,false],"first two batches have no real central gap")
	var events := [0]; var on_damage := func(_current,_maximum): events[0] += 1
	player.health.health_changed.connect(on_damage)
	for _index in range(20): player.health.invulnerable_time = 0; combat.advance(1.0/120)
	check(player.health.current_health==76 and events[0]==1 and combat.refract.attempt.attempted,"third batch stationary hit is missing or repeated")
	player.health.health_changed.disconnect(on_damage); combat.cancel_action()
	# Block the actual Beacon, not the centre. A consumed batch may not respawn later.
	reset(player); check(combat.start_action(&"refract"),"strict birth control starts")
	step(combat,combat.DURATIONS[&"refract"][0]); step(combat,0.10)
	var wall := StaticBody2D.new(); wall.collision_layer = 2; wall.collision_mask = 0; wall.position = boss.get_visual_node().skeleton.get_node(boss.SOCKETS[&"refract"]).global_position
	var collision := CollisionShape2D.new(); var shape := RectangleShape2D.new(); shape.size = Vector2(24,24); collision.shape = shape; wall.add_child(collision); host.add_child(wall); await physics_frame
	combat.advance(1.0/120)
	check(combat.refract.released[0] and not combat.refract.origins[0].is_finite() and armed_count(combat)==0,"blocked Beacon substituted physical centre")
	wall.free(); await physics_frame; step(combat,0.05)
	check(combat.refract.released[0] and armed_count(combat)==0,"blocked consumed batch reappears after wall removal")
	combat.cancel_action()
	for cancellation in [&"manual",&"pause",&"hidden",&"hitch"]:
		reset(player); check(combat.start_action(&"refract"),"lifecycle fixture starts")
		step(combat,combat.DURATIONS[&"refract"][0]); step(combat,0.12); check(armed_count(combat)==3,"lifecycle has real born fragments")
		match cancellation:
			&"manual": combat.cancel_action()
			&"pause": paused = true; combat._process(0); paused = false
			&"hidden": combat.set_target_hidden(true)
			&"hitch": combat.advance(0.1)
		check(not combat.is_attacking() and armed_count(combat)==0 and player.health.current_health==100 and not boss.should_show_attack_marker(),"cancel leaves damage/head mark or catches up")
		combat.set_target_hidden(false)
	reset(player); check(combat.start_action(&"refract"),"reentrant Health control starts"); step(combat,combat.DURATIONS[&"refract"][0])
	var callback := func(_current,_maximum): combat.set_target_hidden(true)
	player.health.health_changed.connect(callback,CONNECT_ONE_SHOT); step(combat,0.60)
	check(player.health.current_health==76 and not combat.is_attacking() and armed_count(combat)==0,"Health callback resurrects a cancelled fan")
	combat.set_target_hidden(false)
	check(not combat.start_action(&"unknown"),"unknown action silently admitted")
	reset(player); check(combat.start_action(&"refract"),"real phase control starts"); step(combat,combat.DURATIONS[&"refract"][0]); step(combat,0.12)
	boss.take_damage(4000)
	check(combat.state==combat.State.TRANSITION_1 and armed_count(combat)==0 and not combat.is_attacking(),"real Health phase retains fan")
	step(combat,0.65); check(combat.current_phase==2,"phase2 unavailable after transition")
	check(combat.start_action(&"refract"),"owner death control starts"); step(combat,combat.DURATIONS[&"refract"][0]); step(combat,0.12)
	boss.take_damage(boss.health.current_health+1)
	check(combat.state==combat.State.DEATH and armed_count(combat)==0 and not combat.start_action(&"refract"),"actual owner death permits fragments")
	host.free(); await process_frame
	if not failures: print("TEST PASS: RiftObserverRefractAttackTest %d"%checks)
	quit(1 if failures else 0)
func _initialize() -> void: call_deferred("run")
