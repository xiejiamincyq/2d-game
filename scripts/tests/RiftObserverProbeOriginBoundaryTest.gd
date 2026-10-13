extends SceneTree
## Real bone socket behind a thin wall/border must not silently spawn at centre.
const Boss = preload("res://scripts/actors/RiftObserverBoss.gd")
const PlayerScript = preload("res://scripts/actors/Player.gd")
var checks := 0
var failures := 0
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error("TEST FAIL: RiftObserverProbeOriginBoundaryTest "+label)
func step(combat: Node,seconds: float) -> void:
	var remaining := seconds
	while remaining>0.000001:
		var dt := minf(remaining,1.0/120); combat.advance(dt); remaining -= dt
func run() -> void:
	for facing in [-1,1]:
		for boundary in ["clear","layer1","layer2","world"]:
			var host := Node2D.new(); root.add_child(host)
			var shots := Node2D.new(); host.add_child(shots)
			var player := PlayerScript.new(); player.position = Vector2(240*facing,0); host.add_child(player); player.set_physics_process(false)
			var boss := Boss.new(); boss.world_bounds = Rect2(-1000,-1000,2000,2000)
			if boundary=="world": boss.world_bounds = Rect2(-70 if facing==1 else -1000,-1000,1070,2000)
			boss.setup(6,shots,player); host.add_child(boss); boss.set_physics_process(false)
			var combat = boss.get_attack_director(); combat.advance(1.4); boss._update_entrance_reveal(); combat.attack_gap = 99
			var wall: StaticBody2D
			if boundary in ["layer1","layer2"]:
				wall = StaticBody2D.new(); wall.collision_layer = 1 if boundary=="layer1" else 2; wall.collision_mask = 0; wall.position = Vector2(-70*facing,-20)
				var collision := CollisionShape2D.new(); var shape := RectangleShape2D.new(); shape.size = Vector2(2,140); collision.shape = shape; wall.add_child(collision); host.add_child(wall)
			await physics_frame
			check(boss.entrance_resolved and not boss.death_resolved and boss.scale==Vector2.ONE and boss.body_radius==56 and player.move_speed==235 and is_equal_approx(player.get_body_radius(),16.9),"normal actual entered bodies")
			var started: bool = combat.start_action(&"probes")
			if boundary!="clear":
				check(not started and not combat.is_attacking() and combat.action_stage==combat.Stage.IDLE,"unsafe predicted socket permits warning "+boundary)
				check(not boss.should_show_attack_marker() and combat.preview_paths.is_empty() and not combat.preview_beam.armed,"unsafe predicted socket retains preview/head marker "+boundary)
				check(not combat.probes[0].armed and not combat.probes[1].armed and combat.probe_released==[false,false] and shots.get_child_count()==0 and player.health.current_health==100,"rejected pair leaves birth/damage authority "+boundary)
				# Keep automatic scheduling out of this isolated rejected-cast fixture.
				combat.attack_gap = 99; step(combat,combat.DURATIONS[&"probes"][0]+0.56)
				check(not combat.is_attacking() and combat.preview_paths.is_empty() and not combat.preview_beam.armed and not combat.probes[0].armed and not combat.probes[1].armed and shots.get_child_count()==0 and player.health.current_health==100,"rejected pair later resumes illegal preview/damage "+boundary)
				print("OBSERVER ORIGIN BOUNDARY: %s facing%s entire cast safely rejected" % [boundary,facing])
				host.free(); await process_frame
				continue
			check(started,"clear pair starts")
			step(combat,combat.DURATIONS[&"probes"][0])
			var left_release_steps := 0
			while not combat.probe_released[0] and left_release_steps<30:
				combat.advance(1.0/120); left_release_steps += 1
			var raw_left: Vector2 = boss.get_visual_node().skeleton.get_node(Boss.SOCKETS[&"probes_left"]).global_position
			check(raw_left.x*facing< -70 and raw_left.distance_to(combat.probe_landings[0])<360,"actual articulated socket, not a centre/range-invalid fixture")
			check(left_release_steps<30 and combat.probe_released[0] and not combat.probe_released[1] and player.health.current_health==100,"left release consumed once before right, no birth damage")
			check(combat.probes[0].armed and combat.probe_origins[0].is_equal_approx(raw_left),"clear left must use true bone socket")
			print("OBSERVER ORIGIN BOUNDARY: %s facing%s true_left%s stored%s armed%s"%[boundary,facing,raw_left,combat.probe_origins[0],combat.probes[0].armed])
			var release_steps := 0
			while not combat.probe_released[1] and release_steps<30:
				combat.advance(1.0/120); release_steps += 1
			var raw_right: Vector2 = boss.get_visual_node().skeleton.get_node(Boss.SOCKETS[&"probes_right"]).global_position
			check(release_steps<30 and combat.probe_released[1] and combat.probes[1].armed and combat.probe_origins[1].is_equal_approx(raw_right),"unblocked current right sensor lost")
			step(combat,0.13)
			check(player.health.current_health==73 and combat.probe_attempt.attempted,"legal pair/right path damages actual normal Health once")
			host.free(); await process_frame
	if not failures: print("TEST PASS: RiftObserverProbeOriginBoundaryTest %d"%checks)
	quit(1 if failures else 0)
func _initialize() -> void: call_deferred("run")
