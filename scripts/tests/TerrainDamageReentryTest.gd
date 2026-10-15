extends SceneTree
## Real Health synchronous signal reentry; not map/weapon acceptance.
const Obstacle = preload("res://scripts/world/ArenaObstacle.gd")
const Trap = preload("res://scripts/world/ReusableStepTrap.gd")
var checks := 0
var failures := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("TEST FAIL: TerrainDamageReentryTest " + label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var host := Node2D.new(); root.add_child(host)
	for kind in ["building", "trap"]:
		var actor: Node2D
		if kind=="building":
			actor = Obstacle.new()
			actor.setup(Rect2(-20,-20,40,40), &"planter")
		else:
			actor = Trap.new()
		host.add_child(actor)
		actor.set_physics_process(false)
		var initial: float = actor.health.current_health
		var results: Array[bool] = []
		var reentered := [false]
		actor.health.health_changed.connect(func(_current, _maximum):
			if not reentered[0]:
				reentered[0] = true
				results.append(actor.take_damage(initial)))
		results.append(actor.take_damage(1))
		check(reentered[0] and results.size()==2, kind+" actual Health signal did not reenter")
		check(results.count(true)==1, kind+" duplicate destruction receipt")
		check(actor.health.current_health==0 and actor.is_queued_for_deletion(), kind+" death did not retire receiver")
		check(not actor.is_in_group(&"destructible_terrain"), kind+" retired receiver remains a target")
		check(not actor.take_damage(1), kind+" retired receiver admits damage")
		await process_frame
	host.free(); await process_frame
	if failures==0: print("TEST PASS: TerrainDamageReentryTest %d" % checks)
	quit(1 if failures else 0)
