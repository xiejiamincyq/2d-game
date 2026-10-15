extends SceneTree
## Actual collider edges in all six maps; passive clocks are controlled here.
const Definitions = preload("res://scripts/campaign/ChapterRunDefinitions.gd")
const Arc = preload("res://scripts/components/ArcPulseVisual.gd")
const Spike = preload("res://scripts/components/SpikeTrap.gd")
const Trap = preload("res://scripts/world/ReusableStepTrap.gd")
const Obstacle = preload("res://scripts/world/ArenaObstacle.gd")
class EnemyProbe extends CharacterBody2D:
	var damage_received := 0.0
	var on_hit: Callable
	func _ready() -> void:
		add_to_group(&"enemies")
		var collider := CollisionShape2D.new(); var shape := CircleShape2D.new(); shape.radius=10
		collider.shape=shape; add_child(collider)
	func take_damage(amount: float,_source: StringName=&"generic",_direction: Vector2=Vector2.ZERO) -> bool:
		damage_received+=amount
		if on_hit.is_valid(): on_hit.call()
		return false
var checks := 0
var failures := 0
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("TEST FAIL: AoeTerrainTest " + label)
func _initialize() -> void: call_deferred("run")
func tick() -> void: await physics_frame; await process_frame
func arc(parent: Node,at: Vector2) -> Node2D:
	var pulse := Arc.new(); pulse.position = at; pulse.setup(160,18,func(): return [])
	parent.add_child(pulse); pulse.set_process(false)
	return pulse
func spike(parent: Node,at: Vector2) -> Area2D:
	var source := Spike.new(); source.position = at; source.damage = 9
	parent.add_child(source); source.set_process(false)
	return source
func run() -> void:
	for chapter in range(1,7): await map_case(chapter)
	await trap_case()
	await world_case()
	await cap_and_cancel()
	await rotated_and_crowded()
	if failures == 0: print("TEST PASS: AoeTerrainTest %d" % checks)
	quit(1 if failures else 0)
func map_case(chapter: int) -> void:
	var host := Node2D.new(); root.add_child(host)
	var definition: Dictionary = Definitions.get_definition(chapter)
	var map: Node2D = definition.map.instantiate(); map.map_seed = 521; host.add_child(map)
	var wall: Node2D = map.layout.get_child(0)
	var rect: Rect2 = wall.get_damage_rect()
	var pulse := arc(host,Vector2(rect.position.x-40,rect.get_center().y))
	var source := spike(host,Vector2(rect.position.x-37,rect.get_center().y))
	await tick(); await tick()
	var hp: float = wall.health.current_health
	pulse._process(0.02)
	check(wall.health.current_health == hp,"chapter%d pulse has not reached actual wall face" % chapter)
	pulse._process(0.06)
	var expected := 18.0 * (1.0-0.75*40.0/160.0)
	check(is_equal_approx(wall.health.current_health,hp-expected),"chapter%d pulse hits actual face with distance falloff" % chapter)
	pulse._process(0.08)
	check(is_equal_approx(wall.health.current_health,hp-expected),"chapter%d one wave never repeats wall damage" % chapter)
	hp = wall.health.current_health
	source._damage_enemies()
	check(is_equal_approx(wall.health.current_health,hp-9),"chapter%d actual38px spike touches wall edge, not art pivot" % chapter)
	check(not wall.is_in_group(&"enemies"),"chapter%d terrain never joins enemy roster" % chapter)
	host.free(); await process_frame
func trap_case() -> void:
	var host := Node2D.new(); root.add_child(host)
	var plate := Trap.new(); plate.position = Vector2(80,0); host.add_child(plate)
	var pulse := arc(host,Vector2.ZERO)
	var source := spike(host,Vector2(129,0))
	await tick(); await tick()
	pulse._damage_crossed_enemies(18,60)
	check(plate.health.current_health == 80,"wave outside trap collision circle does not hit")
	pulse._damage_crossed_enemies(60,64)
	var expected := 18.0*(1.0-0.75*68.0/160.0)
	check(is_equal_approx(plate.health.current_health,80-expected),"wave grazes12px Area at68px, not center80")
	var hp: float = plate.health.current_health
	source._damage_enemies()
	check(is_equal_approx(plate.health.current_health,hp-9),"spike hits real Area with1px overlap")
	var passed := arc(host,Vector2.ZERO)
	hp = plate.health.current_health; passed._damage_crossed_enemies(110,120)
	check(plate.health.current_health == hp,"passed wave hollow interior does not retroactively damage terrain")
	host.free(); await process_frame
func world_case() -> void:
	var own := SubViewport.new(); own.world_2d = World2D.new(); root.add_child(own)
	var other := SubViewport.new(); other.world_2d = World2D.new(); root.add_child(other)
	var a := Trap.new(); a.position = Vector2(40,0); own.add_child(a)
	var b := Trap.new(); b.position = Vector2(40,0); other.add_child(b)
	var pulse := arc(own,Vector2.ZERO); var source := spike(own,Vector2(40,0))
	await tick(); await tick()
	pulse._damage_crossed_enemies(18,40); source._damage_enemies()
	check(a.health.current_health < 71,"own world receives both AoEs")
	check(b.health.current_health == 80,"same-position other World2D never receives AoE damage")
	own.free(); other.free(); await process_frame
func cap_and_cancel() -> void:
	var host := Node2D.new(); root.add_child(host)
	var plate := Trap.new(); host.add_child(plate)
	var enemy := EnemyProbe.new(); host.add_child(enemy)
	var sources: Array[Area2D]=[]
	for index in 4: sources.append(spike(host,Vector2.ZERO))
	await tick(); await tick()
	for source in sources: source._damage_enemies()
	check(plate.health.current_health==53 and enemy.damage_received==27,"three-source cap applies to Area and original enemy body equally")
	sources[0].position=Vector2(300,0); await tick(); await tick()
	sources[0]._damage_enemies(); sources[3]._damage_enemies()
	check(plate.health.current_health==44 and enemy.damage_received==36,"leaving Area releases slot like body_exited")
	sources[1].queue_free(); sources[0].position=Vector2.ZERO; await tick(); await tick()
	sources[0]._damage_enemies()
	check(plate.health.current_health==35 and enemy.damage_received==45,"source retirement releases its target slots")
	for source in sources:
		if is_instance_valid(source): source.queue_free()
	await process_frame
	check(not plate.has_meta(Spike.ACTIVE_SPIKE_SOURCES_META) and not enemy.has_meta(Spike.ACTIVE_SPIKE_SOURCES_META),"last source exit removes all slot metadata")
	var source := spike(host,Vector2.ZERO)
	source.damage_multiplier_provider=func(): source._damage_enemies(); return 2.0
	await tick(); await tick()
	var hp: float=plate.health.current_health
	source._damage_enemies()
	check(plate.health.current_health==hp-18,"multiplier reentry cannot repeat one spike tick")
	source.queue_free(); await process_frame
	source=spike(host,Vector2.ZERO)
	source.damage_multiplier_provider=func(): source.queue_free(); return 2.0
	await tick(); await tick(); hp=plate.health.current_health; source._damage_enemies()
	check(plate.health.current_health==hp,"queued multiplier cancels damage")
	await process_frame
	source=spike(host,Vector2.ZERO); enemy.on_hit=func(): source.queue_free()
	await tick(); await tick(); source._damage_enemies()
	check(plate.health.current_health==hp,"first enemy callback cancellation prevents later terrain hit")
	await process_frame; enemy.on_hit=Callable()
	var pulse:=arc(host,Vector2(-40,0))
	pulse.enemy_provider=func(): pulse.queue_free(); return []
	pulse._damage_crossed_enemies(18,45)
	check(plate.health.current_health==hp,"queued arc provider cancels independent terrain query")
	await process_frame
	pulse=arc(host,Vector2(-40,0)); pulse.enemy_provider=func(): return [enemy,enemy,plate,plate]
	enemy.on_hit=func(): pulse.queue_free()
	var received:=enemy.damage_received; pulse._damage_crossed_enemies(18,45)
	check(enemy.damage_received>received and plate.health.current_health==hp,"first arc enemy callback cancels remaining targets")
	host.free(); await process_frame
func rotated_and_crowded() -> void:
	var host:=Node2D.new(); root.add_child(host)
	var wall:=Obstacle.new(); wall.setup(Rect2(-20,-10,40,20),&"planter"); host.add_child(wall)
	wall.rotation=0.73
	var collider: CollisionShape2D=wall.get_node("CollisionShape2D")
	var origin:=collider.to_global(Vector2(-60,0)); var pulse:=arc(host,origin)
	await tick(); await tick()
	var hp: float=wall.health.current_health
	pulse._damage_crossed_enemies(18,30)
	check(wall.health.current_health==hp,"rotated rectangle not inflated to world AABB")
	pulse._damage_crossed_enemies(30,36)
	check(is_equal_approx(wall.health.current_health,hp-14.625),"rotated rectangle face distance and falloff use transformed corners")
	host.free(); await process_frame
	host=Node2D.new(); root.add_child(host)
	var plates: Array[Node2D]=[]
	for index in 65:
		var plate:=Trap.new(); plate.position=Vector2(40,0); host.add_child(plate); plates.append(plate)
	pulse=arc(host,Vector2.ZERO); var source:=spike(host,Vector2(40,0))
	pulse.enemy_provider=func(): return [plates[0],plates[0]]
	await tick(); await tick()
	pulse._damage_crossed_enemies(18,40); source._damage_enemies()
	var expected:=80.0-18.0*(1.0-0.75*28.0/160.0)-9.0
	check(plates.all(func(plate): return is_equal_approx(plate.health.current_health,expected)),"65 receivers survive paging with exactly one hit per source and no provider duplicates")
	host.free(); await process_frame
