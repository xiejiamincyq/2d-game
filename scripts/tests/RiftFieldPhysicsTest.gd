extends "EchoMovementTest.gd"
## All four natural clocks while an unmodified Player uses real bypass inputs.
const RiftMap = preload("res://scenes/world/rift_observatory.tscn")
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error("TEST FAIL: RiftFieldPhysicsTest "+label)
func run() -> void:
	var original_hz := Engine.physics_ticks_per_second
	for hz in [30,60,120]:
		Engine.physics_ticks_per_second = hz
		for side in [0,1]:
			var map = RiftMap.instantiate(); map.map_seed = 521; root.add_child(map)
			var island: Dictionary = map.layout.get_islands()[0]
			var bypass: Rect2 = map.layout.get_bypass_routes()[side].rect
			var player := Player.new(); player.world_bounds = map.layout.world_bounds; player.position = island.left; map.add_child(player)
			await physics_frame; await process_frame; await physics_frame; await process_frame
			map.rift_field.bind_player(player); map.rift_field.set_active(true,4)
			check(map.rift_field.get_children().all(func(n): return n.enabled),"risk field not genuinely active")
			var first = map.rift_field.get_child(0)
			var deadline := Time.get_ticks_msec()+6000
			while first.state!=first.State.WARNING and Time.get_ticks_msec()<deadline: await physics_frame; await process_frame
			check(first.state==first.State.WARNING,"no natural warning before route")
			var before_moves := moves; var samples := 0
			var targets: Array[Vector2] = [Vector2(island.left.x,bypass.get_center().y),Vector2(island.right.x,bypass.get_center().y),island.right]
			for target in targets:
				var reached := false
				for _frame in ceili(hz*12):
					if player.position.distance_to(target)<12: reached = true; break
					await tick(player,map.layout.get_navigation_direction(player.position,target,player.get_body_radius()))
					samples += map.rift_field.get_children().filter(func(n): return n.state==n.State.ACTIVE).size()
					check(has_clearance(player.position,map.layout.world_bounds,map.layout.get_obstacle_descriptors(),player.get_body_radius()),"full body embeds equipment")
					check(player.health.current_health>0,"normal live route kills Player before completing bypass")
				check(reached,"actual %sHz bypass %s closed by live field"%[hz,side])
			release()
			check(moves>before_moves+40 and samples>0,"path not walked or real moving dangers never observed")
			check(is_equal_approx(player.move_speed,235) and is_equal_approx(player.get_body_radius(),16.9),"fixture modifies ordinary movement")
			print("RIFT LIVE BYPASS: %sHz side%s moves=%s active_samples=%s HP=%s"%[hz,side,moves-before_moves,samples,player.health.current_health])
			map.rift_field.set_active(false); map.free(); await process_frame
	Engine.physics_ticks_per_second = original_hz; release()
	if not failures: print("TEST PASS: RiftFieldPhysicsTest %d; %d actual adjacent moves"%[checks,moves])
	quit(1 if failures else 0)
