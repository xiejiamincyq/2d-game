extends "EchoFieldTest.gd"
## Actual owner field contract; controlled clock samples are not a combat playtest.
const RiftMap = preload("res://scenes/world/rift_observatory.tscn")
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error("TEST FAIL: RiftFieldTest "+label)
func run() -> void:
	var signatures := {}
	for seed_value in [0,1,2,3,7,13,29,97,123,521,20261011,-1]:
		var host := Node2D.new(); host.position = Vector2(64,32); root.add_child(host)
		var map = RiftMap.instantiate(); map.map_seed = seed_value; host.add_child(map)
		var field = map.get_node_or_null("RiftField")
		check(field!=null,"actual sixth map has no dormant owner field")
		if field==null: host.free(); quit(1); return
		var player := Player.new(); player.world_bounds = map.layout.world_bounds; map.add_child(player); await tick(); await tick()
		check(not field.active and field.get_child_count()==4 and field.z_index==-80,"map generation arms danger or hides ground pixels")
		var sites: Array = field.get_sites(); sites.clear(); check(field.get_sites().size()==4,"getter mutates placements")
		var signature := []
		field.bind_player(player); field.set_active(true)
		check(field.active and field.get_children().filter(func(n): return n.enabled).size()==2,"ordinary count not two")
		for i in 4:
			var fault = field.get_child(i)
			check(map.layout.get_fault_sites().has(map.layout.to_local(fault.global_position)),"trajectory is not on reserved site")
			check(not fault is CollisionObject2D and not fault.is_in_group(&"enemies"),"pad creates terrain or reward debt")
			check(is_equal_approx(absf(fault.direction.x),1) and is_zero_approx(fault.direction.y),"unseeded or nonhorizontal locked direction")
			check(is_equal_approx(fault.initial_delay,4.2+i*0.37),"timing no longer staggered")
			for center in fault.get_fault_path(): check(map.layout.is_position_walkable(map.layout.to_local(center),36.9),"full footprint plus Player not locally passable")
			signature.append([map.layout.to_local(fault.global_position),fault.direction])
		signatures[seed_value] = signature
		var first = field.get_child(0); first.set_physics_process(false); first.advance(4.2)
		var remaining: float = first.remaining; field.set_active(true)
		check(first.state==first.State.WARNING and first.remaining==remaining,"combat update rewinds warning")
		field.set_active(true,4); check(field.get_children().all(func(n): return n.enabled),"risk count not four")
		paused = true
		for fault in field.get_children(): fault.advance(0.01)
		check(field.get_children().all(func(n): return n.state==n.State.INACTIVE),"paused field retains moving circles")
		paused = false
		for fault in field.get_children(): fault.advance(0.01); check(fault.remaining==fault.initial_delay,"resume removes stagger")
		field.set_active(false); check(not field.active and field.get_children().all(func(n): return not n.enabled and n.state==n.State.INACTIVE),"clear/reward retains activity")
		field.set_active(true,0); check(not field.active and field.get_children().all(func(n): return not n.enabled),"zero count still authorizes activity")
		field.set_active(true,99); check(field.get_children().all(func(n): return n.enabled),"count upper clamp not four")
		map.generate_map(seed_value)
		check(not field.active and field.get_child_count()==4,"regeneration duplicates pads or retains authority")
		var restored := []
		for fault in field.get_children(): restored.append([map.layout.to_local(fault.global_position),fault.direction])
		check(restored==signatures[seed_value],"same seed changes sites/directions")
		field.bind_player(player); field.set_active(true,4); player.health.damage(player.health.current_health,true)
		check(not field.active and field.get_children().all(func(n): return not n.enabled),"real Health death leaves field enabled")
		host.free(); await process_frame
	check(signatures[0]!=signatures[521],"distinct seeds do not vary placement/order")
	var host := Node2D.new(); root.add_child(host); var map = RiftMap.instantiate(); map.map_seed = 521; host.add_child(map)
	var a := Player.new(); var b := Player.new(); map.add_child(a); map.add_child(b); await tick(); await tick()
	var field = map.rift_field; field.bind_player(a); field.set_active(true,4); field.bind_player(b)
	check(not field.active,"rebind retains combat")
	field.set_active(true,4); a.health.damage(a.health.current_health,true)
	check(field.active and field.get_children().all(func(n): return n.enabled),"old target death cancels rebound field")
	map.remove_child(field); check(not field.active and field.get_children().all(func(n): return not n.enabled),"field detach retains circles")
	field.free(); host.free(); await process_frame
	if not failures: print("TEST PASS: RiftFieldTest %d"%checks)
	quit(1 if failures else 0)
