extends SceneTree
## Controlled clock state/geometry fixture, not a chapter-victory claim.
const SOURCE := "res://scripts/components/TideShellAttackDirector.gd"
class Target extends CharacterBody2D:
	var hits: Array[float] = []
	var alive := true
	var on_damage := Callable()
	func is_alive() -> bool: return alive
	func get_body_radius() -> float: return 13.0
	func take_damage(amount: float,_source: StringName = &"") -> void:
		hits.append(amount)
		if on_damage.is_valid(): on_damage.call()
class Boss extends CharacterBody2D:
	var world_bounds := Rect2(-1000,-1000,2000,2000)
	var death_resolved := false
	var body_radius := 56.0
	func get_safe_salt_origin() -> Vector2: return global_position+Vector2(0,-16)
	func get_claw_origins() -> Array[Vector2]: return [global_position+Vector2(-100,-20),global_position+Vector2(100,-20)]
var checks := 0
var failures := 0
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("TEST FAIL: TideShellAttackDirectorTest "+label)
func _initialize() -> void: call_deferred("run")
func advance_warning(combat: Node,seconds: float = -1.0) -> void:
	var remaining: float = combat.DURATIONS[combat.action][0] if seconds<0 else seconds
	while remaining>0.0000001:
		var step := minf(1.0/120.0,remaining)
		combat.advance(step)
		remaining -= step

func run() -> void:
	check(ResourceLoader.exists(SOURCE),"independent tide-shell combat authority absent")
	if failures: quit(1); return
	var host := Node2D.new(); root.add_child(host)
	var boss := Boss.new(); host.add_child(boss)
	var target := Target.new(); target.position = Vector2(200,0); host.add_child(target)
	var shots := Node2D.new(); host.add_child(shots)
	var combat = load(SOURCE).new(); boss.add_child(combat); combat.configure(boss,target,shots)
	check(combat.get_state_name()=="ENTRANCE" and combat.is_movement_locked(),"entrance unlocked")
	check(not combat.start_action(&"ripple"),"entrance attacks")
	combat.advance(1.4); combat.attack_gap = 99
	check(combat.current_phase==1 and not combat.is_movement_locked(),"entrance cannot finish")
	check(combat.start_action(&"ripple"),"hollow ring absent")
	advance_warning(combat,combat.DURATIONS[&"ripple"][0]-0.01)
	check(target.hits.is_empty() and combat.action_stage==combat.Stage.WARNING,"warning deals damage")
	combat.advance(0.02)
	check(combat.action_stage==combat.Stage.ACTIVE and target.hits.is_empty(),"ring fills all interior instantly")
	combat.advance(0.72)
	check(target.hits==[42.0] and combat.action_stage==combat.Stage.RECOVERY,"continuous ring misses or repeats")
	combat.advance(5)
	check(not combat.is_attacking(),"recovery cannot finish")
	target.position = Vector2(80,0)
	check(combat.start_action(&"ripple"),"inner-safe ring cannot arm")
	advance_warning(combat); combat.advance(0.72)
	check(target.hits==[42.0],"hollow safe centre damaged")
	combat.cancel_action(); target.position = Vector2(100,-20)
	check(combat.start_action(&"pincer"),"bone-tip pincer absent")
	var direction: Vector2 = combat.locked_direction
	advance_warning(combat); combat.advance(0.08); combat.advance(0.28)
	check(target.hits==[42.0,48.0] and combat.locked_direction==direction,"claw damage missing/repeated")
	combat.cancel_action(); target.position = Vector2(500,0)
	check(combat.start_action(&"salt"),"salt fan absent")
	advance_warning(combat,combat.DURATIONS[&"salt"][0]-0.01)
	check(shots.get_child_count()==0,"salt born during warning")
	combat.advance(0.02)
	check(shots.get_child_count()==3 and combat.owned_projectiles.size()==3,"bounded fan not actually spawned")
	for shot in shots.get_children():
		check(shot.global_position==boss.get_safe_salt_origin() and is_equal_approx(shot.velocity.length(),350) and shot.radius==6,"wrong socket/flight footprint")
	combat.advance(0.10)
	check(shots.get_child_count()==3,"active fan respawns every tick")
	combat.set_target_hidden(true)
	check(not combat.is_attacking() and combat.owned_projectiles.is_empty(),"stealth leaves owned projectiles")
	await process_frame
	check(shots.get_child_count()==0,"cancelled projectile nodes survive")
	combat.advance(5)
	check(not combat.is_attacking(),"stealth schedules attacks")
	combat.set_target_hidden(false)
	var summons: Array[int] = []
	combat.reinforcements_requested.connect(func(count): summons.append(count))
	combat.set_health_phase(3)
	check(combat.get_state_name()=="TRANSITION_1" and summons==[2],"missing first finite reinforcement")
	combat.advance(0.65)
	check(combat.get_state_name()=="TRANSITION_2" and summons==[2,3],"large health drop skips phase")
	combat.advance(0.65); combat.set_health_phase(3)
	check(combat.current_phase==3 and summons==[2,3],"phase repeats reinforcements")
	check(combat.start_action(&"salt"),"pause fixture absent")
	advance_warning(combat)
	paused = true; await process_frame; await process_frame
	check(not combat.is_attacking() and combat.owned_projectiles.is_empty(),"tree pause retains salt")
	paused = false; combat.advance(0.01)
	check(combat.attack_gap>1 and not combat.is_attacking(),"resume immediately attacks")
	target.position = Vector2(200,0)
	check(combat.start_action(&"ripple"),"synchronous-death fixture absent")
	target.on_damage = func(): combat.shutdown()
	advance_warning(combat); combat.advance(0.72)
	check(combat.get_state_name()=="DEATH" and not combat.is_attacking() and not combat.start_action(&"salt"),"damage callback overwritten by recovery")
	target.on_damage = Callable()
	var cancelled = load(SOURCE).new(); boss.add_child(cancelled); cancelled.configure(boss,target,shots); cancelled.advance(1.4)
	target.position = Vector2(100,-20)
	target.on_damage = func(): cancelled.cancel_action()
	check(cancelled.start_action(&"pincer"),"claw callback fixture absent")
	advance_warning(cancelled)
	check(not cancelled.is_attacking() and cancelled.previous_claws.is_empty(),"damage cancellation rewrites stale claw cache")
	target.on_damage = Callable()
	var spawning = load(SOURCE).new(); boss.add_child(spawning); spawning.configure(boss,target,shots); spawning.advance(1.4)
	shots.child_entered_tree.connect(func(_node): spawning.shutdown(),CONNECT_ONE_SHOT)
	check(spawning.start_action(&"salt"),"spawn callback fixture absent")
	advance_warning(spawning)
	check(spawning.get_state_name()=="DEATH" and spawning.owned_projectiles.is_empty(),"spawn callback leaks a new shot after terminal cancel")
	await process_frame
	check(shots.get_child_count()==0,"late appended projectile survives Boss death")
	var terminal = load(SOURCE).new(); boss.add_child(terminal); terminal.configure(boss,target,shots)
	terminal.advance(1.4)
	terminal.phase_changed.connect(func(phase):
		if phase==2: terminal.shutdown())
	terminal.set_health_phase(3); terminal.advance(0.65)
	check(terminal.get_state_name()=="DEATH" and not terminal.is_attacking(),"phase callback resurrects Boss")
	var other = load(SOURCE).new(); boss.add_child(other); other.configure(boss,target,shots); other.advance(1.4)
	check(other.start_action(&"ripple"),"departure fixture absent")
	host.remove_child(target)
	check(not other.is_attacking() and other.target_hidden,"departed target still attacked")
	target.free(); host.free(); await process_frame
	if not failures: print("TEST PASS: TideShellAttackDirectorTest %d" % checks)
	quit(1 if failures else 0)
