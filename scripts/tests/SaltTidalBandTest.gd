extends SceneTree
## Manual clock unit checks; real Player physics is a separate gate.
var checks := 0
var failures := 0
class Target extends Node2D:
	var health = preload("res://scripts/components/HealthComponent.gd").new()
	var hits := 0
	var immune := false
	var entering := false
	func _init() -> void:
		health.max_health = 1000
		add_child(health)
	func is_alive() -> bool: return health.current_health>0
	func is_entrance_active() -> bool: return entering
	func get_body_radius() -> float: return 13.0
	func take_damage(amount: float,source: StringName) -> bool:
		if immune: return false
		if source!=&"salt_tide": return false
		hits += 1
		return health.damage(amount)
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error("TEST FAIL: SaltTidalBandTest "+label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var path := "res://scripts/world/SaltTidalBand.gd"
	check(ResourceLoader.exists(path),"salt tidal rule missing")
	if failures: quit(1); return
	var source = load(path)
	check(source!=null and source.can_instantiate(),"tidal rule cannot parse")
	if failures: quit(1); return
	var layout = load("res://scripts/world/SaltArenaLayout.gd").new()
	root.add_child(layout); layout.generate_map(521)
	var passage: Rect2 = layout.get_causeways()[0]
	var size := Vector2(60,passage.size.y-48) if passage.size.x<passage.size.y else Vector2(passage.size.x-48,60)
	var area := Rect2(passage.get_center()-size/2,size)
	var target := Target.new(); root.add_child(target)
	var band = source.new(); root.add_child(band); band.set_physics_process(false)
	band.configure(layout,target,area)
	target.position = area.get_center()
	await physics_frame; await process_frame
	check(not band.enabled and band.state==band.State.INACTIVE,"defaults harmless")
	band.set_enabled(true); band.advance(1.79)
	check(band.state==band.State.COOLDOWN and target.hits==0,"safe initial cooldown")
	band.advance(0.011)
	check(band.state==band.State.WARNING and target.hits==0,"short harmless warning")
	check(band.WARNING_TIME==0.4 and band.WIDTH==60,"validated warning/width changed")
	band.advance(band.WARNING_TIME-0.001)
	check(band.state==band.State.WARNING,"warning duration preserved")
	band.advance(0.002)
	check(band.state==band.State.ACTIVE and target.hits==1 and target.health.current_health==982,"damage18 via target")
	band.advance(0.2); band.set_enabled(true); band.advance(0.2)
	check(target.hits==1 and band.attempted,"idempotent enable/single attempt")
	band.advance(0.201)
	check(band.state==band.State.COOLDOWN,"0.6 danger ends")
	band.advance(100)
	check(band.state==band.State.WARNING and target.hits==1,"stall cannot skip warning")
	band.advance(band.WARNING_TIME)
	check(target.hits==2,"new activation can hit")
	band.set_enabled(false); band.advance(100)
	check(band.state==band.State.INACTIVE and target.hits==2,"cancel")
	# Circle/rectangle overlap, not a square-expanded rectangle at corners.
	target.position = area.end+Vector2(10,10)
	band.set_enabled(true); band.advance(1.8); band.advance(band.WARNING_TIME)
	check(target.hits==2,"outside circle at rectangle corner not damaged")
	target.position = area.end+Vector2(8,8); band.advance(0.01)
	check(target.hits==3,"late genuine body overlap")
	target.position += Vector2(100,100); band.advance(0.01)
	target.position = area.get_center(); band.advance(0.01)
	check(target.hits==3,"reentry no repeated damage")
	paused = true; band.advance(5)
	check(band.state==band.State.INACTIVE,"pause cancels current warning/danger")
	paused = false; band.advance(0.01)
	check(band.state==band.State.COOLDOWN and band.remaining==1.8,"resume full safe cooldown")
	target.entering = true; band.advance(10)
	check(band.state==band.State.INACTIVE,"entrance cancels")
	target.entering = false; band.advance(0.01)
	band.advance(1.8); target.immune = true; band.advance(band.WARNING_TIME)
	check(target.hits==3,"target immunity honored")
	target.immune = false; band.advance(0.01)
	check(target.hits==3,"immune hit not retried in same activation")
	target.health.damage(target.health.current_health,true)
	check(not band.enabled and band.state==band.State.INACTIVE,"real health death synchronous cancel")
	var other := Target.new(); root.add_child(other)
	band.bind_player(other); band.set_enabled(true)
	root.remove_child(other)
	check(not band.enabled,"target detach synchronous cancel")
	other.free()
	var fresh := Target.new(); root.add_child(fresh)
	band.configure(layout,fresh,Rect2(-30,-30,60,200)); band.set_enabled(true)
	check(not band.enabled,"spawn buffer cannot arm")
	band.configure(layout,fresh,Rect2(layout.BOSS_CENTER-Vector2(30,100),Vector2(60,200))); band.set_enabled(true)
	check(not band.enabled,"Boss buffer cannot arm")
	band.configure(layout,fresh,Rect2(1630,-100,60,200)); band.set_enabled(true)
	check(not band.enabled,"whole strip constrained by bounds")
	band.configure(layout,fresh,layout.get_obstacle_descriptors()[0].rect); band.set_enabled(true)
	check(not band.enabled,"cannot arm in solid water")
	band.configure(layout,fresh,area); band.set_enabled(true)
	root.remove_child(layout)
	check(not band.enabled,"terrain detach synchronous cancel")
	layout.free(); band.free(); target.free(); fresh.free()
	await process_frame
	if not failures: print("TEST PASS: SaltTidalBandTest %d"%checks)
	quit(1 if failures else 0)
