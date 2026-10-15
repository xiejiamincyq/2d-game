extends SceneTree
## Common trap mechanism with a real Player receiver. Controlled clock checks,
## not six-map integration, visual readability, or a normal-input playthrough.
const PATH := "res://scripts/world/ReusableStepTrap.gd"
const Player = preload("res://scripts/actors/Player.gd")
var checks := 0
var failures := 0
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("TEST FAIL: ReusableStepTrapTest " + label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	check(ResourceLoader.exists(PATH),"shared reusable stepped trap is missing")
	if failures: quit(1); return
	var host := Node2D.new(); root.add_child(host)
	var player := Player.new(); host.add_child(player); player.set_physics_process(false)
	var trap = load(PATH).new(); trap.target_player = player; host.add_child(trap)
	trap.set_physics_process(false); trap.set_active(true)
	check(player.health.current_health==100 and player.shield==0,"ordinary vulnerable Player receiver")
	check(trap.health.current_health==80 and not trap.is_in_group(&"enemies") and trap.is_in_group(&"destructible_terrain"),"independent destructible trap, not enemy")
	trap._physics_process(0.01)
	check(trap.stage==trap.Stage.WARNING and player.health.current_health==100,"stepping starts warning, not immediate hit")
	trap._physics_process(trap.WARNING_SECONDS-0.01)
	check(player.health.current_health==100,"warning damages early")
	trap._physics_process(0.02)
	check(player.health.current_health==80 and trap.stage==trap.Stage.COOLDOWN and not trap.is_queued_for_deletion(),"first bounded 20 damage retires trap permanently")
	trap._physics_process(100)
	check(player.health.current_health==80 and trap.stage==trap.Stage.READY,"large cooldown delta creates catch-up burst")
	# Natural HealthComponent time expires normal 0.35s receiver invulnerability.
	await create_timer(0.4).timeout
	trap._physics_process(0.01); trap._physics_process(trap.WARNING_SECONDS)
	check(player.health.current_health==60 and not trap.is_queued_for_deletion(),"same live trap cannot trigger a second bounded hit")
	trap._physics_process(trap.COOLDOWN_SECONDS)
	trap._physics_process(0.01)
	player.position = Vector2(200,0)
	trap._physics_process(trap.WARNING_SECONDS)
	check(player.health.current_health==60,"escaped player hit outside actual trap footprint")
	trap._physics_process(trap.COOLDOWN_SECONDS)
	player.position = Vector2.ZERO
	trap._physics_process(0.01)
	trap.set_physics_process(true)
	var elapsed: float = trap.elapsed
	paused = true; await create_timer(0.1,true,false,true).timeout
	check(is_equal_approx(trap.elapsed,elapsed),"pause advances warning")
	paused = false; trap.set_physics_process(false)
	trap.set_active(false)
	trap._physics_process(100)
	check(player.health.current_health==60 and trap.stage==trap.Stage.READY,"disabled trap fires stale warning")
	check(not trap.take_damage(9) and trap.health.current_health==71,"small damage cannot wear down independent trap HP")
	for hit in range(8): trap.take_damage(9)
	check(trap.health.current_health==0 and trap.stage==trap.Stage.DESTROYED and not trap.is_in_group(&"destructible_terrain"),"continuous small hits do not retire trap")
	trap.set_active(true); trap._physics_process(100)
	check(player.health.current_health==60,"destroyed trap resurrected via enable")
	host.free(); await process_frame
	if failures==0: print("TEST PASS: ReusableStepTrapTest %d" % checks)
	quit(1 if failures else 0)
