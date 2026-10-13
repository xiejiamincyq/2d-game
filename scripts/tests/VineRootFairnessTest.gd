extends SceneTree
const Combat = preload("res://scripts/components/VineGuardAttackDirector.gd")
class Boss extends CharacterBody2D:
	var death_resolved := false
	var world_bounds := Rect2(-1000,-1000,2000,2000)
class Target extends Node2D:
	var hits: Array[float] = []
	var damage_callback: Callable
	func take_damage(amount: float) -> void:
		hits.append(amount)
		if damage_callback.is_valid(): damage_callback.call()
var checks := 0
var failures := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("TEST FAIL: VineRootFairnessTest " + message)
func _initialize() -> void: call_deferred("_run")
func step_warning(combat: Node,seconds: float) -> void:
	var remaining := seconds
	while remaining>0.000001:
		var dt := minf(remaining,1.0/120); combat.advance(dt); remaining -= dt
func _run() -> void:
	var host := Node2D.new()
	root.add_child(host)
	var boss := Boss.new()
	var target := Target.new()
	target.position = Vector2(200,0)
	host.add_child(boss); host.add_child(target)
	var combat := Combat.new()
	boss.add_child(combat)
	combat.configure(boss,target,host)
	combat.advance(1.4)
	combat.set_health_phase(2)
	combat.advance(0.65)
	check(combat.start_action(&"roots"), "open-space roots refused")
	step_warning(combat,0.79)
	check(target.hits.is_empty() and combat.action_stage == combat.Stage.WARNING, "roots hit before full 0.8 second warning")
	check(combat.has_method("get_root_stage"), "individual root clocks absent")
	if not combat.has_method("get_root_stage"):
		host.free(); quit(1); return
	var locked: Array = combat.root_centers.duplicate()
	combat.advance(0.02)
	check(target.hits == [60.0], "central root damage changed or never fired")
	check(combat.get_root_stage(0) == combat.Stage.ACTIVE and combat.get_root_stage(1) == combat.Stage.WARNING, "three roots still fire simultaneously")
	target.position = Vector2(-500,500)
	combat.advance(0.12)
	check(combat.root_centers == locked and combat.get_root_stage(1) == combat.Stage.ACTIVE, "roots track player or second root does not stagger")
	combat.advance(0.12)
	check(combat.get_root_stage(2) == combat.Stage.ACTIVE and target.hits == [60.0], "third root repeats damage or fails to stagger")
	combat.cancel_action()
	target.position = Vector2(200,0)
	combat.start_action(&"roots")
	target.position = combat.root_centers[1]
	step_warning(combat,0.800001)
	combat.advance(0.50)
	check(target.hits == [60.0,60.0], "visible-warning then active-to-recovery frame skipped entire side-root window")
	combat.cancel_action()
	target.position = Vector2(200,0)
	combat.start_action(&"roots")
	target.position = combat.root_centers[1]
	step_warning(combat,0.800001)
	combat.advance(0.10)
	combat.advance(0.21)
	check(target.hits == [60.0,60.0,60.0], "active-to-active frame skipped side-root window")
	combat.advance(0.2)
	check(target.hits.size()==3, "crossed interval delivered repeated damage")
	combat.cancel_action()
	for expired_index in [0,1]:
		target.position = Vector2(200,0)
		combat.start_action(&"roots")
		var expired_center: Vector2 = combat.root_centers[expired_index]
		target.position = Vector2(-500,500)
		step_warning(combat,0.800001)
		combat.advance(0.2 if expired_index==0 else 0.32)
		var before_expired := target.hits.size()
		target.position = expired_center
		combat.advance(0.01)
		check(target.hits.size()==before_expired, "later active root revived an expired root")
		combat.cancel_action()
	target.position = Vector2(200,0)
	combat.start_action(&"roots")
	var before_callback := target.hits.size()
	target.position = Vector2(-500,500)
	step_warning(combat,0.800001)
	target.position = combat.root_centers[1]
	target.damage_callback = combat.cancel_action
	combat.advance(0.50)
	check(target.hits.size()==before_callback+1 and not combat.is_attacking(), "synchronous damage cancellation did not stop crossed-window processing")
	target.damage_callback = Callable()
	target.position = Vector2(200,0)
	for offset in [Vector2(-55,0),Vector2(55,0),Vector2(0,-55),Vector2(0,55)]:
		var wall := StaticBody2D.new()
		var collision := CollisionShape2D.new()
		var rectangle := RectangleShape2D.new()
		rectangle.size = Vector2(20,400) if offset.x != 0 else Vector2(400,20)
		collision.shape = rectangle
		wall.add_child(collision)
		wall.position = target.position + offset
		host.add_child(wall)
	await physics_frame
	await physics_frame
	check(not combat.start_action(&"roots") and not combat.is_attacking(), "trapped player received unavoidable roots")
	host.free()
	if failures == 0: print("TEST PASS: VineRootFairnessTest %d" % checks)
	quit(1 if failures else 0)
