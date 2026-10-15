extends SceneTree
## Real static wall admission/removal; controlled trap clock, no map adapter.
const Trap = preload("res://scripts/world/ReusableStepTrap.gd")
const Obstacle = preload("res://scripts/world/ArenaObstacle.gd")
const Player = preload("res://scripts/actors/Player.gd")
var checks := 0
var failures := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("TEST FAIL: StepTrapWallIsolationTest "+label)
func _initialize() -> void: call_deferred("run")
func add_wall(host: Node2D) -> Node2D:
	var wall := Obstacle.new()
	wall.setup(Rect2(14,-50,2,100), &"planter")
	host.add_child(wall)
	return wall
func run() -> void:
	var host := Node2D.new(); root.add_child(host)
	var player := Player.new(); player.position = Vector2(34,0)
	host.add_child(player); player.set_physics_process(false)
	var trap := Trap.new(); trap.target_player = player
	host.add_child(trap); trap.set_physics_process(false); trap.set_active(true)
	var wall := add_wall(host)
	await physics_frame; await physics_frame
	check(player.position.x-player.get_body_radius()>wall.get_damage_rect().end.x and wall.get_damage_rect().position.x>trap.body_radius, "fixture overlaps wall")
	trap._physics_process(0.01)
	check(trap.stage==trap.Stage.READY, "pressure triggers across solid wall")
	trap._physics_process(trap.WARNING_SECONDS)
	check(player.health.current_health==100, "wall-isolated player damaged")
	wall.take_damage(wall.health.max_health)
	await process_frame; await physics_frame; await physics_frame
	trap.set_active(false); trap.set_active(true)
	trap._physics_process(0.01)
	check(trap.stage==trap.Stage.WARNING, "removed wall still blocks pressure")
	wall = add_wall(host)
	await physics_frame; await physics_frame
	trap._physics_process(trap.WARNING_SECONDS)
	check(player.health.current_health==100, "wall added during warning does not isolate damage")
	wall.take_damage(wall.health.max_health)
	await process_frame; await physics_frame; await physics_frame
	trap._physics_process(trap.COOLDOWN_SECONDS)
	trap._physics_process(0.01); trap._physics_process(trap.WARNING_SECONDS)
	check(player.health.current_health==80, "unblocked real Player cannot trigger bounded hit")
	host.free(); await process_frame
	if failures==0: print("TEST PASS: StepTrapWallIsolationTest %d" % checks)
	quit(1 if failures else 0)
