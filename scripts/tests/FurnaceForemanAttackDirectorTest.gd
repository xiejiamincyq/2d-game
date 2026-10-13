extends SceneTree
func advance_warning(clock, seconds: float) -> void:
	var remaining := seconds
	while remaining > 0.0:
		var step := minf(remaining, 1.0/120.0)
		clock.advance(step)
		remaining = maxf(0.0, remaining-step)
## State/geometry fixture; manual clock is not evidence of a playable chapter.
const SOURCE := "res://scripts/components/FurnaceForemanAttackDirector.gd"
class Target extends CharacterBody2D:
	var hits: Array[float] = []
	func is_alive() -> bool: return true
	func get_body_radius() -> float: return 13.0
	func take_damage(amount: float,_source: StringName = &"") -> void: hits.append(amount)
class Boss extends CharacterBody2D:
	var world_bounds := Rect2(-1000,-1000,2000,2000)
	var death_resolved := false
	var body_radius := 56.0
	func get_safe_heat_origin() -> Vector2: return global_position+Vector2(60,-12)
	# Geometry fixture has a fixed nozzle; production actors sample native bones.
	func _update_boss_motion(_delta: float) -> void: pass
var checks := 0
var failures := 0
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error("TEST FAIL: FurnaceForemanAttackDirectorTest "+label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	check(ResourceLoader.exists(SOURCE),"furnace-specific three-action authority absent")
	if failures: quit(1); return
	var host := Node2D.new(); root.add_child(host)
	var boss := Boss.new(); host.add_child(boss)
	var target := Target.new(); target.position = Vector2(180,0); host.add_child(target)
	var director = load(SOURCE).new(); boss.add_child(director); director.configure(boss,target,null)
	check(director.get_state_name()=="ENTRANCE" and director.is_movement_locked(),"entrance unlocked")
	check(not director.start_action(&"jet"),"entrance attacks")
	director.advance(1.4); director.attack_gap = 99
	check(director.current_phase==1,"entrance cannot finish")
	check(director.start_action(&"jet"),"short fan absent")
	check(director.locked_origin==boss.get_safe_heat_origin(),"jet not anchored to actual nozzle")
	advance_warning(director,director.DURATIONS[&"jet"][0]-0.01)
	check(target.hits.is_empty() and director.action_stage==director.Stage.WARNING,"early fan damage")
	director.advance(0.02)
	check(target.hits==[48.0] and director.action_stage==director.Stage.ACTIVE,"fan hit missing")
	director.advance(0.05)
	check(target.hits==[48.0],"fan repeats damage")
	director.advance(5)
	check(director.action_stage==director.Stage.RECOVERY,"hitch skips recovery")
	director.advance(5)
	check(not director.is_attacking(),"fan cannot complete")
	check(director.start_action(&"jet"),"second fan absent")
	var direction: Vector2 = director.locked_direction
	target.position = Vector2(-180,0); advance_warning(director,director.DURATIONS[&"jet"][0]+0.01)
	check(target.hits==[48.0] and director.locked_direction==direction,"fan retargets during warning")
	director.cancel_action(); target.position = Vector2(0,300)
	var reinforcements: Array[int] = []
	director.reinforcements_requested.connect(func(count: int): reinforcements.append(count))
	director.set_health_phase(2)
	check(director.get_state_name()=="TRANSITION_1" and reinforcements==[2],"unbounded/missing phase reinforcement")
	director.set_health_phase(2); director.advance(0.65)
	check(director.current_phase==2 and reinforcements==[2],"phase duplicates")
	check(director.start_action(&"vents") and director.vent_centers.size()==3,"three fixed disjoint zones absent")
	var centers: Array = director.vent_centers.duplicate()
	for i in centers.size():
		for j in range(i+1,centers.size()): check(centers[i].distance_to(centers[j])>=88,"overlapping zones")
	target.position = Vector2(-600,0); advance_warning(director,director.DURATIONS[&"vents"][0]+0.01)
	check(target.hits==[48.0] and director.vent_centers==centers,"vents track moving target")
	target.position = centers[1]; director.advance(0.01)
	check(target.hits==[48.0,42.0],"late entry does not hit")
	target.position = centers[0]; director.advance(0.01)
	check(target.hits==[48.0,42.0],"same cast hits multiple zones")
	director.set_target_hidden(true)
	check(not director.is_attacking() and director.vent_centers.is_empty(),"stealth leaves hazards")
	director.advance(5)
	check(target.hits==[48.0,42.0] and not director.is_attacking(),"stealth still schedules")
	director.set_target_hidden(false)
	target.position = Vector2(980,980)
	check(director.start_action(&"vents"),"corner zones all rejected")
	for point in director.vent_centers: check(boss.world_bounds.grow(-44).has_point(point),"zone outside world")
	director.cancel_action(); target.position = Vector2(400,0)
	check(director.start_action(&"ram"),"real ram absent")
	advance_warning(director,director.DURATIONS[&"ram"][0]-0.01)
	check(boss.position==Vector2.ZERO,"warning moves physical root")
	paused = true; director.advance(5)
	check(not director.is_attacking() and boss.position==Vector2.ZERO,"pause leaves armed ram")
	paused = false; director.advance(0.01)
	check(not director.is_attacking() and director.attack_gap>1,"resume has no safe delay")
	director.set_health_phase(3); director.advance(0.65)
	check(reinforcements==[2,3] and director.current_phase==3,"phase three unlimited reinforcement")
	director.set_health_phase(3)
	check(reinforcements==[2,3],"repeated phase emits reinforcement")
	check(director.start_action(&"ram"),"phase three ram absent")
	director.shutdown()
	check(director.get_state_name()=="DEATH" and not director.is_attacking() and not director.start_action(&"jet"),"death keeps attack")
	var terminal = load(SOURCE).new(); boss.add_child(terminal); terminal.configure(boss,target,null); terminal.advance(1.4)
	var terminal_summons: Array[int] = []
	terminal.reinforcements_requested.connect(func(count): terminal_summons.append(count))
	terminal.phase_changed.connect(func(phase):
		if phase==2: terminal.shutdown())
	terminal.set_health_phase(3); terminal.advance(0.65)
	check(terminal.get_state_name()=="DEATH" and terminal_summons==[2],"phase callback resurrects terminal state and summons more")
	var other = load(SOURCE).new(); boss.add_child(other); other.configure(boss,target,null); other.advance(1.4)
	check(other.start_action(&"vents"),"target exit fixture cannot arm")
	host.remove_child(target)
	check(not other.is_attacking() and other.vent_centers.is_empty(),"detached target keeps floor damage")
	target.free(); host.free(); await process_frame
	if not failures: print("TEST PASS: FurnaceForemanAttackDirectorTest %d"%checks)
	quit(1 if failures else 0)
