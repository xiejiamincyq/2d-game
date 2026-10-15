extends SceneTree
## Shared replacement for retired periodic-field expectations. Actual map owners,
## twelve seeds, real physics wall isolation; controlled individual trap clocks.
const Definitions = preload("res://scripts/campaign/ChapterRunDefinitions.gd")
const Field = preload("res://scripts/world/ReusableTrapField.gd")
const Trap = preload("res://scripts/world/ReusableStepTrap.gd")
const Player = preload("res://scripts/actors/Player.gd")
const FIELD_NAMES := ["TrapField","HeatField","TidalField","SporeField","EchoField","RiftField"]
var checks:=0
var failures:=0
func _chapter_number() -> int: return 4
func suite_name() -> String: return get_script().resource_path.get_file().get_basename()
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		push_error("TEST FAIL: %s %s"%[suite_name(),label])
func _initialize() -> void: call_deferred("run")
func tick() -> void: await physics_frame; await process_frame
func fixture(seed_value: int) -> Dictionary:
	var host:=Node2D.new(); host.position=Vector2(64,32); root.add_child(host)
	var definition: Dictionary=Definitions.get_definition(_chapter_number())
	var map: Node2D=definition.map.instantiate(); map.map_seed=seed_value; host.add_child(map)
	var player:=Player.new(); host.add_child(player)
	player.global_position=map.layout.to_global(Vector2.ZERO); player.set_physics_process(false)
	return {"host":host,"map":map,"player":player,"field":map.get_node(FIELD_NAMES[_chapter_number()-1])}
func run() -> void:
	var signatures: Dictionary={}
	for seed_value in [0,1,2,3,7,13,29,97,123,521,20261011,-1]:
		var f:=fixture(seed_value)
		var field: Node=f.field
		check(field.get_script()==Field and not field.active and field.get_child_count()==10 and field.z_index==-80,"actual map owns ten disarmed ground plates")
		var sites: Array=field.get_sites(); signatures[seed_value]=sites.duplicate()
		sites.clear(); check(field.get_sites().size()==10,"getter cannot mutate authoritative placements")
		var protected: Dictionary=f.map.layout.get_script().get_script_constant_map()
		for index in field.get_child_count():
			var trap: Node2D=field.get_child(index)
			var at: Vector2=field.get_sites()[index]
			check(trap.get_script()==Trap and trap is Area2D and trap.body_radius==12 and not trap.is_in_group(&"enemies"),"destructible receiver is not a movement wall or enemy debt")
			check(trap.global_position.is_equal_approx(f.map.layout.to_global(at)),"translated map-local placement matches actual receiver")
			check(f.map.layout.is_position_walkable(at,66) and f.map.layout.is_reachable(Vector2.ZERO,at,f.player.get_body_radius()),"full normal player can reach/exit plate")
			check(not protected.SPAWN_BUFFER.grow(66).has_point(at) and not protected.BOSS_BUFFER.grow(66).has_point(at),"spawn and boss pockets reserved")
			for previous in range(index): check(at.distance_to(field.get_sites()[previous])>=169.99,"pair spacing170")
		field.bind_player(f.player); field.set_active(true,2)
		check(field.active and field.get_children().filter(func(child): return child.enabled).size()==2,"explicit ordinary authority enables two")
		var first: Node=field.get_child(0); first.set_physics_process(false)
		f.player.global_position=first.global_position; first._physics_process(0.01); first._physics_process(0.20)
		var elapsed: float=first.elapsed
		field.set_active(true,2)
		check(first.stage==first.Stage.WARNING and is_equal_approx(first.elapsed,elapsed),"repeated combat grant does not rewind pending cue")
		first.take_damage(20); field.set_active(true,4)
		check(first.health.current_health==60 and field.get_children().filter(func(child): return child.enabled).size()==4,"risk count increases without healing damaged plate")
		first.take_damage(60)
		check(first.is_queued_for_deletion() and first.health.current_health==0 and not field.get_destructible_targets().has(first),"destroyed plate leaves damage roster immediately")
		await process_frame
		field.set_active(false); field.set_active(true,4)
		check(field.get_child_count()==9 and field.get_children().filter(func(child): return child.enabled).size()==4,"next grant never resurrects retired plate")
		field.set_active(true,0)
		check(not field.active and field.get_children().all(func(child): return not child.enabled),"zero grant cancels all activity")
		field.set_active(true,999)
		check(field.get_children().all(func(child): return child.enabled),"oversized grant caps at existing live population")
		f.map.generate_map(seed_value)
		check(not field.active and field.get_child_count()==10 and field.get_sites()==signatures[seed_value],"same-seed regeneration deterministically replaces, not duplicates")
		f.map.generate_map(seed_value+100)
		check(not field.active and field.get_child_count()==10 and field.get_sites()!=signatures[seed_value],"new seed changes disarmed placement")
		field.bind_player(f.player); field.set_active(true,4)
		f.player.health.damage(f.player.health.current_health,true)
		check(not field.active and field.get_children().all(func(child): return not child.enabled),"actual health death synchronously cancels all plates")
		f.host.free(); await process_frame
	check(signatures[0]!=signatures[521],"different seeded runs differ")
	await wall_and_rebind()
	if failures==0: print("TEST PASS: %s %d"%[suite_name(),checks])
	quit(1 if failures else 0)
func add_wall(host: Node,at: Vector2) -> StaticBody2D:
	var wall:=StaticBody2D.new(); wall.collision_layer=3
	var collider:=CollisionShape2D.new(); var shape:=RectangleShape2D.new(); shape.size=Vector2(2,60)
	collider.shape=shape; wall.add_child(collider); host.add_child(wall); wall.global_position=at+Vector2(15,0)
	return wall
func wall_and_rebind() -> void:
	var f:=fixture(521)
	var field: Node=f.field; var trap: Node2D=field.get_child(0)
	trap.set_physics_process(false)
	f.player.global_position=trap.global_position+Vector2(34,0)
	var wall:=add_wall(f.host,trap.global_position)
	await tick(); await tick(); field.bind_player(f.player); field.set_active(true,1)
	trap._physics_process(0.01)
	check(trap.stage==trap.Stage.READY and f.player.health.current_health==100,"real unlisted2px wall prevents pressure across it")
	wall.free(); await tick(); await tick()
	trap._physics_process(0.01)
	check(trap.stage==trap.Stage.WARNING,"removed wall restores legitimate pressure")
	wall=add_wall(f.host,trap.global_position); await tick(); await tick()
	trap._physics_process(trap.WARNING_SECONDS)
	check(f.player.health.current_health==100,"wall inserted during warning prevents delayed hit")
	wall.free()
	var replacement:=Player.new(); f.host.add_child(replacement); replacement.set_physics_process(false)
	field.bind_player(replacement)
	check(not field.active and trap.stage==trap.Stage.READY and is_zero_approx(trap.elapsed),"rebind cancels old clock and authorization")
	field.set_active(true,4); f.player.health.damage(100,true)
	check(field.active and field.get_children().filter(func(child): return child.enabled).size()==4,"old target death cannot cancel new owner")
	f.map.remove_child(field)
	check(not field.active and field.get_children().all(func(child): return not child.enabled),"field departure cancels danger synchronously")
	field.free(); f.host.free(); await process_frame
