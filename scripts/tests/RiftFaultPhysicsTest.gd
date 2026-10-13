extends "EchoBeatPhysicsTest.gd"
## Natural clock + real normal Player input. Only initial placement is controlled.
const RiftMap = preload("res://scenes/world/rift_observatory.tscn")
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error("TEST FAIL: RiftFaultPhysicsTest "+label)
func obstacle(parent: Node,at: Vector2,static_wall: bool) -> CollisionObject2D:
	var body: CollisionObject2D = StaticBody2D.new() if static_wall else CharacterBody2D.new()
	body.position = at; body.collision_layer = 1; body.collision_mask = 0
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new(); shape.size = Vector2(2,45) if static_wall else Vector2(3,3)
	collision.shape = shape; body.add_child(collision); parent.add_child(body)
	return body
func run() -> void:
	var path := "res://scripts/world/RiftFault.gd"
	check(ResourceLoader.exists(path),"actual moving fault absent")
	if failures: quit(1); return
	var Fault = load(path)
	var original_hz := Engine.physics_ticks_per_second
	for hz in [30,60,120]:
		Engine.physics_ticks_per_second = hz
		for mode in ["behind","up","down","diagonal","ahead","reverse"]:
			var host := Node2D.new(); host.position = Vector2(64,32); root.add_child(host)
			var map = RiftMap.instantiate(); map.map_seed = 521; host.add_child(map)
			var site: Vector2 = map.layout.get_fault_sites()[0]
			var heading := Vector2.LEFT if mode=="reverse" else Vector2.RIGHT
			var player := Player.new(); player.world_bounds = map.layout.world_bounds
			player.position = site+heading*80 if mode=="ahead" else site-heading*80
			map.add_child(player)
			var fault = Fault.new(); host.add_child(fault); await tick(); await tick()
			fault.configure(map.layout,player,site,heading); fault.set_enabled(true)
			check(fault.enabled,"normal fixture refused %s/%s"%[hz,mode])
			var before := durability(player)
			check(await wait_for(func(): return fault.state==Fault.State.WARNING),"natural warning absent %s/%s"%[hz,mode])
			check(durability(player)==before,"cooldown or warning damages Player")
			for _frame in ceili(hz*0.15): await tick()
			Input.action_press("move_up" if mode in ["up","diagonal"] else "move_down" if mode=="down" else "move_right" if mode in ["ahead","reverse"] else "move_left")
			if mode=="diagonal": Input.action_press("move_left")
			var start_moves := moves; var active_samples := 0; var first_center := Vector2.ZERO; var last_center := Vector2.ZERO
			for _frame in ceili(hz*0.7):
				var at := player.position; await tick()
				if player.position.distance_to(at)>0.01: moves += 1
				if fault.state==Fault.State.ACTIVE:
					if active_samples==0: first_center = fault.get_current_center()
					last_center = fault.get_current_center(); active_samples += 1
				check(Clearance.has_clearance(player.position,map.layout.world_bounds,map.layout.get_obstacle_descriptors(),player.get_body_radius()),"ordinary dodge embeds true circle %s/%s"%[hz,mode])
				check(durability(player)==before,"0.15 reaction not enough %s/%s frame%s"%[hz,mode,_frame])
			release()
			check(moves>start_moves+5 and active_samples>3 and first_center.distance_to(last_center)>120,"no real motion or finite moving footprint")
			check(is_equal_approx(player.move_speed,235) and is_equal_approx(player.get_body_radius(),16.9) and not player.is_stealthed(),"fixture cheats normal movement")
			print("RIFT FAULT ESCAPE: %sHz %s moves=%s active_samples=%s durability=%s"%[hz,mode,moves-start_moves,active_samples,durability(player)])
			fault.set_enabled(false); host.free(); await process_frame
	# Real standing-body control, actual pause and entrance restart; not invincible.
	Engine.physics_ticks_per_second = 60
	var host := Node2D.new(); root.add_child(host)
	var map = RiftMap.instantiate(); map.map_seed = 521; host.add_child(map)
	var site: Vector2 = map.layout.get_fault_sites()[0]
	var player := Player.new(); player.world_bounds = map.layout.world_bounds; player.position = site; map.add_child(player)
	var fault = Fault.new(); host.add_child(fault); await tick(); await tick()
	fault.configure(map.layout,player,site,Vector2.RIGHT); fault.set_enabled(true)
	var before := durability(player)
	check(await wait_for(func(): return fault.state==Fault.State.ACTIVE),"standing control never gets activity")
	check(await wait_for(func(): return fault.state==Fault.State.COOLDOWN,1.5),"activity never terminates")
	check(is_equal_approx(before-durability(player),18),"standing control is not unique actual18 damage")
	paused = true; await tick(); await tick(); check(fault.state==Fault.State.INACTIVE,"actual paused clock retains danger")
	paused = false; await tick(); await tick(); check(fault.state==Fault.State.COOLDOWN and fault.remaining>4.1,"pause resumes stale motion")
	player.begin_entrance(); await tick(); await tick(); check(fault.state==Fault.State.INACTIVE,"real entrance fails cancel")
	check(await wait_for(func(): return not player.is_entrance_active()),"entrance never finishes")
	await tick(); await tick(); check(fault.state==Fault.State.COOLDOWN and fault.remaining>4.1,"entrance recovery lacks full safe delay")
	fault.set_enabled(false)
	# Thin wall crosses capsule between clear endpoints; dynamic actors are not walls.
	var wall := obstacle(host,site,true); await tick(); await tick()
	fault.set_enabled(true); check(not fault.enabled,"two-pixel middle wall does not veto complete capsule")
	wall.free(); await tick(); await tick()
	var actor := obstacle(host,site,false); await tick(); await tick()
	fault.set_enabled(true); check(fault.enabled,"normal dynamic layer1 actor is treated as terrain")
	fault.set_enabled(false); actor.free(); await tick(); await tick()
	for _index in 40: obstacle(host,site,false)
	await tick(); await tick(); fault.set_enabled(true)
	check(not fault.enabled,"saturated contacts hide a possible wall and still arm")
	host.free(); await process_frame
	Engine.physics_ticks_per_second = original_hz; release()
	if not failures: print("TEST PASS: RiftFaultPhysicsTest %d; %d actual adjacent moves"%[checks,moves])
	quit(1 if failures else 0)
