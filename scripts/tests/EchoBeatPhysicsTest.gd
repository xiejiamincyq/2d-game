extends SceneTree
## Natural clocks and real Player inputs. No post-spawn actor/stat/clock writes.
const Map = preload("res://scenes/world/echo_court.tscn")
const Player = preload("res://scripts/actors/Player.gd")
const Beat = preload("res://scripts/world/EchoBeat.gd")
const Clearance = preload("EchoMovementTest.gd")
var checks := 0
var failures := 0
var moves := 0
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error("TEST FAIL: EchoBeatPhysicsTest "+label)
func _initialize() -> void: call_deferred("run")
func tick() -> void: await physics_frame; await process_frame
func release() -> void:
	for action in ["move_left","move_right","move_up","move_down","fire","dash_melee"]: Input.action_release(action)
func wait_for(predicate: Callable,seconds: float = 6.0) -> bool:
	var deadline := Time.get_ticks_msec()+int(seconds*1000)
	while not predicate.call() and Time.get_ticks_msec()<deadline: await tick()
	return predicate.call()
func durability(player: Node) -> float: return player.health.current_health+player.shield
func run() -> void:
	var original_hz := Engine.physics_ticks_per_second
	for hz in [30,60,120]:
		Engine.physics_ticks_per_second = hz
		for mode in ["first","second","wall"]:
			var host := Node2D.new(); root.add_child(host)
			var map = Map.instantiate(); map.map_seed = 521; host.add_child(map)
			var anchor: Vector2 = map.layout.get_echo_sites()[0]
			var player := Player.new(); player.world_bounds = map.layout.world_bounds
			player.position = anchor+(Vector2(48,0) if mode=="second" else Vector2(0,-16) if mode=="wall" else Vector2.ZERO); host.add_child(player)
			var entries: Array[Dictionary] = map.layout.get_obstacle_descriptors()
			if mode=="wall":
				var area := Rect2(anchor+Vector2(-70,-55),Vector2(140,2))
				var wall := StaticBody2D.new(); wall.position = area.get_center()
				var collider := CollisionShape2D.new(); var shape := RectangleShape2D.new(); shape.size = area.size
				collider.shape = shape; wall.add_child(collider); host.add_child(wall); entries.append({"rect":area})
			var beat := Beat.new(); host.add_child(beat); await tick(); await tick()
			beat.configure(map.layout,player,anchor,Vector2.RIGHT); beat.set_enabled(true)
			check(beat.enabled,"natural fixed pad cannot arm %s/%s"%[hz,mode])
			var before := durability(player)
			var warning := Beat.State.WARNING_SECOND if mode=="second" else Beat.State.WARNING_FIRST
			check(await wait_for(func(): return beat.state==warning),"natural warning absent %s/%s"%[hz,mode])
			check(durability(player)==before,"warning/other disk damages real Player")
			for _frame in ceili(hz*0.15): await tick()
			Input.action_press("move_left" if mode=="first" else "move_right")
			if mode=="wall": Input.action_press("move_up")
			var start_moves := moves; var wall_contacts := 0
			for _frame in ceili(hz*0.65):
				var at := player.position; await tick()
				if player.position.distance_to(at)>0.01: moves += 1
				wall_contacts += player.get_slide_collision_count()
				check(Clearance.has_clearance(player.position,map.layout.world_bounds,entries,player.get_body_radius()),"real full-radius body embeds in terrain")
				check(durability(player)==before,"0.15s reaction fails %s/%s frame%s"%[hz,mode,_frame])
			release()
			check(moves>start_moves+5 and is_equal_approx(player.move_speed,235) and is_equal_approx(player.get_body_radius(),16.9) and not player.is_stealthed(),"escape bypasses normal motion")
			if mode=="wall": check(wall_contacts>0,"thin wall fixture never exercises real sliding")
			print("ECHO BEAT ESCAPE: %sHz %s actual_moves=%s durability=%s"%[hz,mode,moves-start_moves,durability(player)])
			beat.set_enabled(false); host.free(); await process_frame
	# All four natural pads active: real gateway remains passable, not necessarily harmless.
	for hz in [30,60,120]:
		Engine.physics_ticks_per_second = hz
		var host := Node2D.new(); root.add_child(host); var map = Map.instantiate(); map.map_seed = 521; host.add_child(map)
		var gate: Dictionary = map.layout.get_gateways()[0]
		var player := Player.new(); player.position = gate.inside; player.world_bounds = map.layout.world_bounds; host.add_child(player)
		await tick(); await tick(); map.echo_field.bind_player(player); map.echo_field.set_active(true,4)
		var first = map.echo_field.get_child(0)
		check(await wait_for(func(): return first.state==Beat.State.WARNING_FIRST),"active field clock absent before gateway route")
		var start_moves := moves; var reached := false; var pulses := 0
		for _frame in ceili(hz*8):
			if player.position.distance_to(gate.outside)<12: reached = true; break
			var direction: Vector2 = map.layout.get_navigation_direction(player.position,gate.outside,player.get_body_radius())
			release()
			for axis in [["move_left",-direction.x],["move_right",direction.x],["move_up",-direction.y],["move_down",direction.y]]:
				if axis[1]>0: Input.action_press(axis[0],axis[1])
			var at := player.position; await tick()
			if player.position.distance_to(at)>0.01: moves += 1
			pulses += map.echo_field.get_children().filter(func(n): return n.state in [Beat.State.PULSE_FIRST,Beat.State.PULSE_SECOND]).size()
			check(Clearance.has_clearance(player.position,map.layout.world_bounds,map.layout.get_obstacle_descriptors(),player.get_body_radius()),"live field gateway embeds full body")
		release(); check(reached and moves>start_moves+40 and pulses>0,"all four enabled pads close actual gateway or route never observes danger")
		print("ECHO BEAT GATEWAY: %sHz actual_moves=%s pulses=%s durability=%s"%[hz,moves-start_moves,pulses,durability(player)])
		map.echo_field.set_active(false); host.free(); await process_frame
	Engine.physics_ticks_per_second = 60
	for second in [false,true]:
		var host := Node2D.new(); root.add_child(host); var map = Map.instantiate(); map.map_seed = 521; host.add_child(map)
		var anchor: Vector2 = map.layout.get_echo_sites()[0]
		var player := Player.new(); player.position = anchor+Vector2(48,0) if second else anchor; player.world_bounds = map.layout.world_bounds; host.add_child(player)
		var beat := Beat.new(); host.add_child(beat); await tick(); await tick(); beat.configure(map.layout,player,anchor,Vector2.RIGHT); beat.set_enabled(true)
		var before := durability(player); var pulse := Beat.State.PULSE_SECOND if second else Beat.State.PULSE_FIRST
		check(await wait_for(func(): return beat.state==pulse),"standing control never receives actual pulse")
		check(is_equal_approx(before-durability(player),18),"standing real body damage is not18")
		check(await wait_for(func(): return beat.state==Beat.State.COOLDOWN,1.5),"standing cycle not finite")
		check(is_equal_approx(before-durability(player),18),"one pair repeats health/shield damage")
		paused = true; await tick(); await tick(); check(beat.state==Beat.State.INACTIVE,"real paused physics retains pulse")
		paused = false; await tick(); await tick(); check(beat.state==Beat.State.COOLDOWN and beat.remaining>3.3,"actual resume not safe")
		player.begin_entrance(); await tick(); await tick(); check(beat.state==Beat.State.INACTIVE,"real Player entrance fails cancel")
		check(await wait_for(func(): return not player.is_entrance_active()),"real entrance never ends")
		await tick(); await tick(); check(beat.state==Beat.State.COOLDOWN and beat.remaining>3.3,"actual entrance recovery lacks safety")
		beat.set_enabled(false); host.free(); await process_frame
	Engine.physics_ticks_per_second = original_hz; release()
	if not failures: print("TEST PASS: EchoBeatPhysicsTest %d; %d actual adjacent moves"%[checks,moves])
	quit(1 if failures else 0)
