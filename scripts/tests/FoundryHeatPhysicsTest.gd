extends SceneTree
func advance_warning(clock, seconds: float) -> void:
	var remaining := seconds
	while remaining > 0.0:
		var step := minf(remaining, 1.0/120.0)
		clock.advance(step)
		remaining = maxf(0.0, remaining-step)
## Real Player/health/physics lifecycle fixture, not normal-input chapter victory.
const Map = preload("res://scenes/world/ember_foundry.tscn")
const Player = preload("res://scripts/actors/Player.gd")
const Vent = preload("res://scripts/world/FoundryHeatVent.gd")
var checks := 0
var failures := 0
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error("TEST FAIL: FoundryHeatPhysicsTest "+label)
func _initialize() -> void: call_deferred("run")
func wait_for(predicate: Callable,seconds: float = 3.0) -> bool:
	var end := Time.get_ticks_msec()+int(seconds*1000)
	while not predicate.call() and Time.get_ticks_msec()<end: await physics_frame
	return predicate.call()
func run() -> void:
	var original_hz := Engine.physics_ticks_per_second
	for hz in [30,60,120]:
		Engine.physics_ticks_per_second = hz
		var host := Node2D.new(); root.add_child(host)
		var map = Map.instantiate(); host.add_child(map)
		var player := Player.new(); player.position = Vector2(600,100); host.add_child(player)
		var vent := Vent.new(); host.add_child(vent)
		vent.configure(map.layout,player,player.position)
		var before: float = player.health.current_health+player.shield
		vent.set_enabled(true)
		check(await wait_for(func(): return vent.state==Vent.State.WARNING),"real clock reaches warning %s"%hz)
		check(player.health.current_health+player.shield==before,"warning never hurts")
		check(await wait_for(func(): return vent.state==Vent.State.ACTIVE),"real clock reaches danger")
		await physics_frame
		check(is_equal_approx(before-player.health.current_health-player.shield,18),"real Player damage path 18")
		var damaged: float = player.health.current_health+player.shield
		paused = true
		await physics_frame; await physics_frame
		check(vent.state==Vent.State.INACTIVE,"real paused tree cancels visible danger")
		await create_timer(0.15,true).timeout
		check(player.health.current_health+player.shield==damaged,"pause stops damage")
		paused = false; await physics_frame; await physics_frame
		check(vent.state==Vent.State.COOLDOWN and vent.remaining>1.3,"resume full cooling")
		vent.set_enabled(false); player.begin_entrance(); vent.set_enabled(true)
		await physics_frame; await physics_frame
		check(vent.state==Vent.State.INACTIVE,"actual entrance suppresses heat")
		check(await wait_for(func(): return not player.is_entrance_active()),"actual entrance finishes")
		await physics_frame; await physics_frame
		check(vent.state==Vent.State.COOLDOWN and vent.remaining>1.3,"entrance ends before safe cooldown")
		map.heat_field.bind_player(player); map.heat_field.set_active(true)
		player.health.damage(player.health.current_health,true)
		check(not vent.enabled and not map.heat_field.active,"death signal cancels synchronously")
		await physics_frame; await physics_frame
		check(not vent.enabled and not map.heat_field.active,"real death cancels owned heat")
		check(map.heat_field.get_children().all(func(child): return not child.enabled),"all field dangers canceled")
		host.free(); await process_frame
	Engine.physics_ticks_per_second = original_hz
	# Real thin wall query, not a mock navigation veto.
	var host := Node2D.new(); root.add_child(host)
	var map = Map.instantiate(); host.add_child(map)
	var player := Player.new(); player.position = Vector2(658,100); host.add_child(player)
	player.set_physics_process(false)
	var wall := StaticBody2D.new(); wall.position = Vector2(650,100)
	var shape := CollisionShape2D.new(); var rect := RectangleShape2D.new()
	rect.size = Vector2(2,120); shape.shape = rect; wall.add_child(shape); host.add_child(wall)
	await physics_frame; await physics_frame
	var vent := Vent.new(); host.add_child(vent); vent.set_physics_process(false)
	vent.configure(map.layout,player,Vector2(600,100)); vent.set_enabled(true)
	var before: float = player.health.current_health+player.shield
	vent.advance(1.5); advance_warning(vent,vent.WARNING_TIME)
	check(player.health.current_health+player.shield==before and not vent.attempted,"thin wall blocks damage")
	wall.free(); await physics_frame; await physics_frame; vent.advance(0.01)
	check(is_equal_approx(before-player.health.current_health-player.shield,18),"unblocked late body overlap damages")
	map.heat_field.bind_player(player); map.heat_field.set_active(true)
	var detached = map.heat_field
	map.remove_child(detached)
	check(not detached.active and detached.get_children().all(func(child): return not child.enabled),"field exit cancels without waiting deletion")
	detached.free(); host.remove_child(player)
	check(not vent.enabled and vent.state==Vent.State.INACTIVE,"target detachment cancels synchronously")
	player.free(); await process_frame; vent.advance(10)
	check(not vent.enabled and vent.state==Vent.State.INACTIVE,"real target queue/free disarms")
	host.free(); await process_frame
	if not failures: print("TEST PASS: FoundryHeatPhysicsTest %d"%checks)
	quit(1 if failures else 0)
