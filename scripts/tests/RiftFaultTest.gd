extends "EchoBeatTest.gd"
## Canonical R2 unit fixture; controlled target samples are not a player dodge test.
const RiftLayout = preload("res://scripts/world/RiftArenaLayout.gd")
class ReentrantTarget extends Target:
	var fault: Node
	func take_damage(amount: float,source: StringName) -> bool:
		var accepted := super.take_damage(amount,source)
		fault.set_enabled(false); fault.set_enabled(true)
		return accepted
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error("TEST FAIL: RiftFaultTest "+label)
func cycle_start(fault,target,at: Vector2) -> void:
	fault.set_enabled(false); target.global_position = at
	fault.set_enabled(true); fault.advance(4.2); fault.advance(0.4)
func finish_cycle(fault) -> void:
	for _index in 50:
		if fault.state==fault.State.COOLDOWN: return
		fault.advance(0.01)
	check(false,"moving fault does not finish finite activity")
func run() -> void:
	var path := "res://scripts/world/RiftFault.gd"
	check(ResourceLoader.exists(path),"finite moving sixth-region fault missing")
	if failures: quit(1); return
	var Fault = load(path)
	var host := Node2D.new(); host.position = Vector2(64,32); root.add_child(host)
	var layout = RiftLayout.new(); host.add_child(layout); layout.generate_map(521)
	var target := Target.new(); host.add_child(target)
	var fault = Fault.new(); host.add_child(fault); fault.set_physics_process(false)
	var site: Vector2 = layout.get_fault_sites()[0]
	await tick(); await tick(); fault.configure(layout,target,site,Vector2.RIGHT)
	check(not fault.enabled and fault.state==Fault.State.INACTIVE and not fault is CollisionObject2D and not fault.is_in_group(&"enemies"),"generation arms damage or physical/loot actor")
	var ends: Array = fault.get_fault_path(); ends.clear()
	var start: Vector2 = fault.get_fault_path()[0]; var end: Vector2 = fault.get_fault_path()[1]
	check(fault.get_fault_path().size()==2 and start.is_equal_approx(layout.to_global(site)-Vector2(80,0)) and end.distance_to(start)==160,"translated fixed trajectory or getter mutation")
	check(fault.get_path() is NodePath,"hazard shadows native Node.get_path")
	target.global_position = start; fault.set_enabled(true)
	check(fault.enabled and fault.remaining>=4.2,"arming lacks cooldown")
	fault.advance(999); check(fault.state==Fault.State.WARNING and fault.remaining==0.4 and target.hits.is_empty(),"hitch skips visible warning")
	var warning: float = fault.remaining
	for delta in [0.0,-1.0,NAN,INF]: fault.advance(delta)
	check(fault.remaining==warning and target.hits.is_empty(),"invalid delta mutates clock or health")
	fault.set_enabled(true); check(fault.remaining==warning,"repeated enabled update rewinds warning")
	fault.advance(0.4)
	check(fault.state==Fault.State.ACTIVE and target.hits==[18.0] and fault.get_current_center().is_equal_approx(start),"warning transition doesn't reveal starting disk or one hit")
	fault.advance(0.05)
	check(fault.get_current_center().distance_to(start)>20 and fault.get_current_center().distance_to(end)>100,"active circle does not move on fixed path")
	finish_cycle(fault); check(target.hits==[18.0] and fault.remaining>=4.2,"one activity repeats damage or lacks recovery")
	cycle_start(fault,target,end)
	check(target.hits.size()==1,"entire future trajectory is damaging before disk arrives")
	for _index in 5: fault.advance(0.05)
	check(target.hits.size()==1,"moving disk damages distant path end too early")
	fault.advance(0.05); check(target.hits==[18.0,18.0],"late real path-end disk overlap not resolved")
	finish_cycle(fault)
	cycle_start(fault,target,end); var attempts_before: int = target.attempts
	fault.advance(999)
	check(fault.state==Fault.State.COOLDOWN and fault.remaining>=4.2 and target.attempts==attempts_before,"active hitch sweeps entire160 route or skips safe restart")
	cycle_start(fault,target,start+Vector2(32,32))
	check(target.attempts==attempts_before,"circle uses expanded square corner")
	target.global_position = start+Vector2(20,20); fault.advance(0.01)
	check(target.hits.size()==3,"true circle overlap after activity start fails")
	finish_cycle(fault)
	target.immune = true; cycle_start(fault,target,start)
	check(target.attempts==attempts_before+2 and target.hits.size()==3,"immune overlap not attempted exactly once")
	target.immune = false; finish_cycle(fault)
	check(target.attempts==attempts_before+2,"same activity retries rejected immunity")
	cycle_start(fault,target,start+Vector2(0,-100)); attempts_before = target.attempts
	target.global_position = start+Vector2(0,100); fault.advance(0.01)
	check(target.attempts==attempts_before+1,"relative crossing tunnels despite non-overlapping endpoints")
	finish_cycle(fault)
	cycle_start(fault,target,end); paused = true; fault.advance(0.01)
	check(fault.state==Fault.State.INACTIVE,"pause retains dangerous activity")
	paused = false; fault.advance(0.01)
	check(fault.state==Fault.State.COOLDOWN and fault.remaining>=4.2,"resume inherits old path or movement")
	target.entrance = true; fault.advance(0.01); check(fault.state==Fault.State.INACTIVE,"entrance fails cancellation")
	target.entrance = false; fault.advance(0.01); check(fault.remaining>=4.2,"entrance resume skips safety")
	cycle_start(fault,target,end); target.target_hidden = true; fault.advance(0.01)
	check(fault.state==Fault.State.INACTIVE,"hidden player leaves visible moving danger")
	target.target_hidden = false; fault.advance(0.01); check(fault.remaining>=4.2,"hidden recovery reuses old activity")
	fault.set_enabled(false); fault.advance(999)
	check(not fault.enabled and fault.state==Fault.State.INACTIVE,"disabled owner retains activity")
	for direction in [Vector2.ZERO,Vector2(NAN,0)]:
		fault.configure(layout,target,site,direction); fault.set_enabled(true)
		check(not fault.enabled,"invalid trajectory arms physical danger")
	fault.configure(layout,target,Vector2(NAN,0),Vector2.RIGHT); fault.set_enabled(true)
	check(not fault.enabled,"non-finite anchor arms physical danger")
	fault.configure(layout,target,Vector2.ZERO,Vector2.RIGHT); fault.set_enabled(true)
	check(not fault.enabled,"spawn buffer arms damage")
	fault.configure(layout,target,site,Vector2.RIGHT); fault.set_enabled(true)
	fault.scale = Vector2(2,1); fault.advance(0.01); check(not fault.enabled,"scaled hazard hides radius mismatch")
	fault.scale = Vector2.ONE
	var reentrant := ReentrantTarget.new(); host.add_child(reentrant); reentrant.fault = fault; await tick()
	fault.configure(layout,reentrant,site,Vector2.RIGHT); cycle_start(fault,reentrant,start)
	check(reentrant.attempts==1 and not fault.enabled and fault.state==Fault.State.INACTIVE,"damage callback re-arms same clock")
	fault.bind_player(target); fault.set_enabled(true); target.health.damage(target.health.current_health,true)
	check(not fault.enabled and fault.state==Fault.State.INACTIVE,"real Health death signal retains activity")
	fault.bind_player(null); fault.set_enabled(true); check(not fault.enabled,"absent player arms")
	fault.configure(layout,reentrant,site,Vector2.RIGHT); fault.set_enabled(true)
	host.remove_child(layout); check(not fault.enabled,"owner exit does not cancel")
	layout.free(); host.free(); await process_frame
	if not failures: print("TEST PASS: RiftFaultTest %d"%checks)
	quit(1 if failures else 0)
