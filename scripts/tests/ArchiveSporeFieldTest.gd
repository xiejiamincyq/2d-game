extends SceneTree
const Map = preload("res://scenes/world/luminous_archive.tscn")
const Player = preload("res://scripts/actors/Player.gd")
var checks := 0
var failures := 0
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error("TEST FAIL: ArchiveSporeFieldTest "+label)
func _initialize() -> void: call_deferred("run")
func tick() -> void: await physics_frame; await process_frame
func run() -> void:
	check(ResourceLoader.exists("res://scripts/world/ArchiveSporeField.gd"),"map-owned spore field missing")
	if failures: quit(1); return
	for seed_value in [0,1,2,3,7,13,29,97,123,521,20261011,-1]:
		var host := Node2D.new(); root.add_child(host)
		var map = Map.instantiate(); map.map_seed = seed_value; host.add_child(map)
		var field = map.get_node_or_null("SporeField")
		check(field!=null,"map has no field")
		if field==null: host.free(); quit(1); return
		var player := Player.new(); host.add_child(player); await tick(); await tick()
		check(not field.active and field.get_child_count()==4,"generation enables hazard or duplicates nests")
		check(field.get_sites().size()==4 and field.z_index==-80,"four ground sites missing")
		var sites: Array = field.get_sites(); sites.clear()
		check(field.get_sites().size()==4,"getter leaks mutable placement")
		field.bind_player(player); field.set_active(true)
		check(field.active and field.get_children().filter(func(n): return n.enabled).size()==2,"normal route must enable two")
		for nest in field.get_children():
			check(map.layout.get_spore_sites().has(map.layout.to_local(nest.global_position)),"nest outside reserved room")
			check(not nest is StaticBody2D and nest.get_body_radius()==12,"nest becomes movement wall")
		var first = field.get_child(0); first.take_damage(36); field.set_active(true)
		check(first.destroyed and first.health.current_health==0 and not first.is_in_group(&"enemies"),"repeated combat enable revives nest")
		field.set_active(true,4)
		check(first.destroyed and field.get_children().filter(func(n): return n.enabled).size()==4,"risk increases count but regrows nest")
		field.set_active(false)
		check(field.get_children().all(func(n): return not n.enabled and not n.is_in_group(&"enemies")),"clear leaves damage/target group")
		field.set_active(true,4)
		check(not first.destroyed and first.health.current_health==36,"new encounter does not reset nest")
		map.generate_map(seed_value+100)
		check(not field.active and field.get_child_count()==4 and field.get_sites().size()==4,"regeneration leaves stale active nests")
		field.bind_player(player); field.set_active(true,4)
		player.health.damage(player.health.current_health,true)
		check(not field.active and field.get_children().all(func(n): return not n.enabled),"health death does not cancel field")
		host.free(); await process_frame
	# Valid translated layout, physical wall veto and owner detach.
	var host := Node2D.new(); host.position = Vector2(64,32); root.add_child(host)
	var map = Map.instantiate(); map.map_seed = 521; host.add_child(map)
	var player := Player.new(); host.add_child(player); await tick(); await tick()
	var field = map.spore_field; field.bind_player(player); field.set_active(true,1)
	var nest = field.get_child(0)
	check(nest.enabled and map.layout.to_global(field.get_sites()[0]).is_equal_approx(nest.global_position),"translation breaks placement")
	var wall := StaticBody2D.new(); wall.global_position = nest.global_position
	var collider := CollisionShape2D.new(); var shape := RectangleShape2D.new(); shape.size = Vector2(2,60)
	collider.shape = shape; wall.add_child(collider); root.add_child(wall); await tick(); await tick()
	check(not nest.enabled,"actual unlisted thin wall permits through-wall emission")
	wall.free(); await tick(); await tick(); field.set_active(true,1)
	check(nest.enabled,"wall removal cannot safely arm")
	map.remove_child(field)
	check(not field.active and field.get_children().all(func(n): return not n.enabled),"owner detach leaves active damage")
	field.free(); host.free(); await process_frame
	if not failures: print("TEST PASS: ArchiveSporeFieldTest %d"%checks)
	quit(1 if failures else 0)
