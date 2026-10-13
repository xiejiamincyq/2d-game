extends SceneTree
const Map = preload("res://scenes/world/echo_court.tscn")
const Player = preload("res://scripts/actors/Player.gd")
var checks := 0
var failures := 0
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error("TEST FAIL: EchoFieldTest "+label)
func _initialize() -> void: call_deferred("run")
func tick() -> void: await physics_frame; await process_frame
func run() -> void:
	for seed_value in [0,1,2,3,7,13,29,97,123,521,20261011,-1]:
		var host := Node2D.new(); root.add_child(host)
		var map = Map.instantiate(); map.map_seed = seed_value; host.add_child(map)
		var field = map.get_node_or_null("EchoField")
		check(field!=null,"actual map has no encounter-owned beat field")
		if field==null: host.free(); quit(1); return
		var player := Player.new(); player.world_bounds = map.layout.world_bounds; host.add_child(player); await tick(); await tick()
		check(not field.active and field.get_child_count()==4 and field.z_index==-80,"generation arms hazard, duplicates pads or hides ground effect")
		var sites: Array = field.get_sites(); sites.clear(); check(field.get_sites().size()==4,"mutable authoritative placements")
		field.bind_player(player); field.set_active(true)
		check(field.active and field.get_children().filter(func(n): return n.enabled).size()==2,"ordinary encounter does not enable two")
		for beat in field.get_children():
			check(map.layout.get_echo_sites().has(map.layout.to_local(beat.global_position)),"not a reserved map site")
			check(not beat is CollisionObject2D and not beat.is_in_group(&"enemies"),"hazard creates wall or enemy reward debt")
			for center in beat.get_beat_centers(): check(map.layout.is_position_walkable(map.layout.to_local(center),46.9),"full Player cannot leave local stamp")
		var first = field.get_child(0); first.advance(3.4); var remaining: float = first.remaining
		field.set_active(true); check(first.remaining==remaining,"repeated combat update restarts warning")
		field.set_active(true,4); check(field.get_children().all(func(n): return n.enabled),"risk does not enable four finite sites")
		field.set_active(false); check(field.get_children().all(func(n): return not n.enabled and n.state==n.State.INACTIVE),"reward/leave contract retains pulse")
		map.generate_map(seed_value+100)
		check(not field.active and field.get_child_count()==4,"regeneration keeps stale ownership")
		field.bind_player(player); field.set_active(true,4); player.health.damage(player.health.current_health,true)
		check(not field.active and field.get_children().all(func(n): return not n.enabled),"real Health death does not cancel all sites")
		host.free(); await process_frame
	var host := Node2D.new(); host.position = Vector2(64,32); root.add_child(host)
	var map = Map.instantiate(); map.map_seed = 521; host.add_child(map)
	var player := Player.new(); host.add_child(player); await tick(); await tick()
	var field = map.echo_field; field.bind_player(player); field.set_active(true,1)
	var beat = field.get_child(0)
	check(beat.enabled and map.layout.to_global(field.get_sites()[0]).is_equal_approx(beat.global_position),"translation drifts fixed first site")
	var wall := StaticBody2D.new(); var collider := CollisionShape2D.new(); var shape := RectangleShape2D.new(); shape.size = Vector2(2,60)
	collider.shape = shape; wall.add_child(collider); root.add_child(wall); wall.global_position = beat.get_beat_centers()[1]; await tick(); await tick()
	check(not beat.enabled and beat.state==beat.State.INACTIVE,"unexpected thin wall permits secondary disk through terrain")
	wall.free(); await tick(); field.set_active(true,1); check(beat.enabled and beat.remaining>=3.4,"wall removal resumes without safety")
	map.remove_child(field); check(not field.active and field.get_children().all(func(n): return not n.enabled),"owner detach retains pair")
	field.free(); host.free(); await process_frame
	if not failures: print("TEST PASS: EchoFieldTest %d"%checks)
	quit(1 if failures else 0)
