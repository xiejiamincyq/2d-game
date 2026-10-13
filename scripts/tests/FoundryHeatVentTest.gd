extends SceneTree
func advance_warning(clock, seconds: float) -> void:
	var remaining := seconds
	while remaining > 0.0:
		var step := minf(remaining, 1.0/120.0)
		clock.advance(step)
		remaining = maxf(0.0, remaining-step)
var checks := 0
var failures := 0
class Target extends Node2D:
	var health: Node
	var hits := 0
	var immune := false
	var entering := false
	func _init() -> void:
		health = Node.new()
		health.set_meta("alive",true)
		add_child(health)
	func is_alive() -> bool: return health.get_meta("alive")
	func is_entrance_active() -> bool: return entering
	func get_body_radius() -> float: return 13.0
	func take_damage(amount: float,_source: StringName) -> bool:
		if immune: return false
		hits += 1
		return is_equal_approx(amount,18.0)
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error("TEST FAIL: FoundryHeatVentTest "+label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var path := "res://scripts/world/FoundryHeatVent.gd"
	check(ResourceLoader.exists(path),"heat vent missing")
	if failures: quit(1); return
	var source = load(path)
	check(source!=null and source.can_instantiate(),"vent parse")
	if failures: quit(1); return
	var layout = load("res://scripts/world/FoundryArenaLayout.gd").new()
	root.add_child(layout); layout.generate_map(521)
	var target := Target.new(); root.add_child(target)
	var vent = source.new(); root.add_child(vent); vent.set_physics_process(false)
	vent.configure(layout,target,Vector2(600,100))
	target.position = vent.position
	check(vent.state==vent.State.INACTIVE,"defaults disabled")
	vent.set_enabled(true)
	vent.advance(1.49)
	check(vent.state==vent.State.COOLDOWN and target.hits==0,"safe initial cooldown")
	vent.advance(0.01)
	check(vent.state==vent.State.WARNING and target.hits==0,"short warning")
	advance_warning(vent,vent.WARNING_TIME-0.01)
	check(vent.state==vent.State.WARNING,"warning not shortened")
	vent.advance(0.011)
	check(vent.state==vent.State.ACTIVE and target.hits==1,"active damage 18")
	vent.advance(0.2); vent.advance(0.2)
	check(target.hits==1,"single damage each activation")
	vent.set_enabled(true)
	check(vent.state==vent.State.ACTIVE and vent.attempted,"idempotent enable does not reset activation")
	vent.advance(0.21)
	check(vent.state==vent.State.COOLDOWN,"danger ends after 0.6")
	vent.advance(100)
	check(vent.state==vent.State.WARNING and target.hits==1,"no catch-up burst skips warning")
	advance_warning(vent,vent.WARNING_TIME)
	check(target.hits==2,"next activation independent")
	vent.set_enabled(false); vent.advance(100)
	check(vent.state==vent.State.INACTIVE and target.hits==2,"disable cancels")
	vent.set_enabled(true); target.position += Vector2(80,0)
	vent.advance(1.5); advance_warning(vent,vent.WARNING_TIME)
	check(target.hits==2,"outside visible radius plus body")
	target.position = vent.position+Vector2(58,0); vent.advance(0.01)
	check(target.hits==3,"late entry body overlap")
	target.position += Vector2(80,0); vent.advance(0.01)
	target.position = vent.position; vent.advance(0.01)
	check(target.hits==3,"reentry not repeated")
	paused = true; vent.advance(10)
	check(vent.state==vent.State.INACTIVE and target.hits==3,"pause cancels danger")
	paused = false; vent.advance(0.01)
	check(vent.state==vent.State.COOLDOWN,"resume requires fresh safe interval")
	target.entering = true; vent.advance(2)
	check(vent.state==vent.State.INACTIVE,"entrance protection")
	target.entering = false; vent.advance(0.01)
	vent.advance(1.5); target.immune = true; advance_warning(vent,vent.WARNING_TIME)
	check(target.hits==3,"does not bypass player immunity")
	target.immune = false; vent.advance(0.01)
	check(target.hits==3,"only one damage attempt per activation")
	target.health.set_meta("alive",false); vent.advance(0.01)
	check(vent.state==vent.State.INACTIVE and not vent.enabled,"death disarms permanently")
	target.health.set_meta("alive",true)
	var blocked: Vector2 = layout.get_obstacle_descriptors()[0].rect.get_center()
	vent.configure(layout,target,blocked); vent.set_enabled(true); vent.advance(10)
	check(vent.state==vent.State.INACTIVE,"solid terrain cannot activate vent")
	vent.configure(layout,target,Vector2(1590,0)); vent.set_enabled(true); vent.advance(10)
	check(vent.state==vent.State.INACTIVE,"bounds constrain full footprint")
	vent.configure(layout,target,Vector2(600,100)); vent.set_enabled(true)
	target.queue_free(); await process_frame; vent.advance(10)
	check(vent.state==vent.State.INACTIVE and not vent.enabled,"target exit cancels")
	vent.free(); layout.free(); await process_frame
	if not failures: print("TEST PASS: FoundryHeatVentTest %d"%checks)
	quit(1 if failures else 0)
