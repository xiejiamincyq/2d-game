extends "EchoMovementTest.gd"
## Reuse only ordinary-input/circle-clearance test helpers, not production maps.
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error("TEST FAIL: RiftMovementTest "+label)
func run() -> void:
	var path := "res://scenes/world/rift_observatory.tscn"
	check(ResourceLoader.exists(path),"actual sixth map missing for ordinary movement")
	if failures: quit(1); return
	var original_hz := Engine.physics_ticks_per_second
	for case in [{"hz":30,"seed":0},{"hz":60,"seed":521},{"hz":120,"seed":20261011}]:
		Engine.physics_ticks_per_second = case.hz
		var map = load(path).instantiate(); map.map_seed = case.seed; root.add_child(map)
		var entries: Array[Dictionary] = map.layout.get_obstacle_descriptors()
		var module: Rect2 = entries[0].rect
		var player := Player.new(); player.world_bounds = map.layout.world_bounds
		player.position = Vector2(module.position.x-55,module.get_center().y)
		map.add_child(player); await physics_frame; await process_frame
		check(is_equal_approx(player.get_body_radius(),16.9) and is_equal_approx(player.move_speed,235),"fixture changes radius or movement")
		for _step in ceili(case.hz*0.6): await tick(player,Vector2.RIGHT)
		check(player.get_slide_collision_count()>0,"%sHz does not contact actual equipment"%case.hz)
		check(has_clearance(player.position,map.layout.world_bounds,entries,player.get_body_radius()),"equipment contact embeds full body")
		var island: Dictionary = map.layout.get_islands()[0]
		var routes: Array[Dictionary] = map.layout.get_bypass_routes()
		var upper: Rect2 = routes[0].rect; var lower: Rect2 = routes[1].rect
		var targets: Array[Vector2] = [island.left,Vector2(island.left.x,upper.get_center().y),Vector2(island.right.x,upper.get_center().y),island.right,Vector2(island.right.x,lower.get_center().y),Vector2(island.left.x,lower.get_center().y),island.left,map.layout.BOSS_CENTER]
		var before_route := moves
		for target in targets:
			var reached := false
			for _step in ceili(case.hz*12):
				if player.position.distance_to(target)<12: reached = true; break
				await tick(player,map.layout.get_navigation_direction(player.position,target,player.get_body_radius()))
				check(has_clearance(player.position,map.layout.world_bounds,entries,player.get_body_radius()),"ordinary input enters compound equipment")
			check(reached,"%sHz cannot complete real upper/lower bypass to %s"%[case.hz,target])
		check(moves>before_route+40,"path decisions replace real movement")
		print("RIFT MOVEMENT CASE: %sHz seed=%s moves=%s"%[case.hz,case.seed,moves-before_route])
		release(); map.free(); await process_frame
	Engine.physics_ticks_per_second = original_hz; release()
	if not failures: print("TEST PASS: RiftMovementTest %d; %d actual adjacent moves"%[checks,moves])
	quit(1 if failures else 0)
