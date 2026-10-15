extends SceneTree
## Actual swept flight + nonoverlapping production wall/Player. Controlled callback
## cases below separately isolate queued guards, quotas and synchronous reentry.
const Shot = preload("res://scripts/components/Projectile.gd")
const Wall = preload("res://scripts/world/DestructibleObstacle.gd")
const Player = preload("res://scripts/actors/Player.gd")
const Health = preload("res://scripts/components/HealthComponent.gd")

class SignalReceiver extends StaticBody2D:
	var health: HealthComponent
	func _ready() -> void:
		add_to_group(&"enemies")
		health = preload("res://scripts/components/HealthComponent.gd").new()
		health.max_health = 100; add_child(health)
	func take_damage(amount: float,_source: StringName,_direction: Vector2) -> void:
		health.damage(amount,true)

var checks := 0
var failures := 0
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("TEST FAIL: ProjectileFirstImpactTest "+label)
func _initialize() -> void: call_deferred("run")

func fixture() -> Dictionary:
	var host := Node2D.new(); root.add_child(host)
	var wall = thin_wall(host,Vector2.ZERO)
	var player := Player.new(); player.position = Vector2(Player.BODY_RADIUS+2,0)
	host.add_child(player); player.set_physics_process(false)
	var second_wall = thin_wall(host,Vector2(300,0))
	return {"host":host,"wall":wall,"player":player,"second_wall":second_wall}

func thin_wall(host: Node2D,at: Vector2) -> StaticBody2D:
	# Production health/damage authority with a real 2px collider. Map decoration
	# is not part of this geometry fixture and cannot accept a 2px art silhouette.
	var wall := Wall.new(); wall.position = at; wall.collision_layer = 3; wall.collision_mask = 0
	wall.set_layout_footprint(Rect2(at-Vector2(1,60),Vector2(2,120)))
	var collider := CollisionShape2D.new(); collider.name = "CollisionShape2D"
	var shape := RectangleShape2D.new(); shape.size = Vector2(2,120)
	collider.shape = shape; wall.add_child(collider); host.add_child(wall)
	return wall

func callback_shot(f: Dictionary,pierce: int = 0) -> Projectile:
	var shot := Shot.new(); shot.damage = 9; shot.target_group = &"player"
	shot.pierce = pierce; shot.position = Vector2(-100,0)
	f.host.add_child(shot); shot.set_physics_process(false)
	return shot

func test_actual_first_wall_entry() -> void:
	var f := fixture(); await physics_frame; await physics_frame
	check(f.player.global_position.x-Player.BODY_RADIUS>1,"actual wall and actual Player fixtures overlap")
	var wall_before: float = f.wall.health.current_health
	var player_before: float = f.player.health.current_health
	var shot := Shot.new(); shot.damage = 9; shot.target_group = &"player"; shot.pierce = 0
	# The old Area-only path entered both inflated shapes in the same tick.
	# The upgraded path must stop at the geometric wall before those callbacks.
	shot.position = Vector2(-7.5,0); shot.velocity = Vector2(Engine.physics_ticks_per_second*6.0,0)
	var moved := [false]
	var start := shot.position
	var last := [start]
	f.host.add_child(shot)
	shot.tree_exiting.connect(func():
		last[0] = shot.global_position
		moved[0] = moved[0] or last[0].distance_to(start)>0.1)
	var previous := shot.position
	for _step in 20:
		await physics_frame; await process_frame
		if not is_instance_valid(shot): break
		if shot.position!=previous: moved[0] = true
		previous = shot.position
	check(moved[0],"production projectile did not physically fly")
	check(last[0].x<=-1+0.2,"projectile crossed first wall entry face")
	var wall_lost: float = wall_before-f.wall.health.current_health
	var player_lost: float = player_before-f.player.health.current_health
	check(wall_lost==9 and player_lost==0,"first wall did not isolate rear Player and accept exactly one 9-point impact")
	check(not is_instance_valid(shot) or shot.is_queued_for_deletion(),"actual zero-pierce impact did not retire projectile")
	f.host.free(); await process_frame; await process_frame

func test_ordered_queued_entry() -> void:
	for wall_first in [true,false]:
		var f := fixture(); var shot := callback_shot(f)
		var first: Node = f.wall if wall_first else f.player
		var second: Node = f.player if wall_first else f.wall
		var first_before: float = first.health.current_health
		var second_before: float = second.health.current_health
		# Deliberate legal entry calls isolate the guard, not physics flight proof.
		shot._on_body_entered(first)
		check(shot.is_queued_for_deletion() and first.health.current_health==first_before-9,"first legitimate callback did not consume zero-pierce shot")
		shot._on_body_entered(second)
		check(second.health.current_health==second_before,"queued projectile admitted another legitimate target, wall-first=%s"%wall_first)
		f.host.free(); await process_frame; await process_frame

func test_one_pierce_control() -> void:
	var f := fixture(); var shot := callback_shot(f,1)
	var wall_before: float = f.wall.health.current_health
	var second_before: float = f.second_wall.health.current_health
	shot._on_body_entered(f.wall); shot._on_body_entered(f.wall)
	check(f.wall.health.current_health==wall_before-9 and not shot.is_queued_for_deletion(),"duplicate target consumed extra pierce budget")
	shot._on_body_entered(f.player)
	check(f.player.health.current_health==91 and shot.is_queued_for_deletion(),"pierce=1 did not allow exactly two different legitimate impacts")
	shot._on_body_entered(f.second_wall)
	check(f.second_wall.health.current_health==second_before,"pierce=1 accepted third target after exhausting two impacts")
	f.host.free(); await process_frame; await process_frame

func test_multiplier_cancellation() -> void:
	var f := fixture(); var shot := callback_shot(f); var calls := [0]
	var before: float = f.wall.health.current_health
	shot.damage_multiplier_provider = func():
		calls[0] += 1; shot.queue_free(); return 2.0
	shot._on_body_entered(f.wall)
	check(calls[0]==1 and shot.is_queued_for_deletion(),"multiplier cancellation positive control missing")
	check(f.wall.health.current_health==before,"multiplier callback cancelled projectile but it still applied damage")
	f.host.free(); await process_frame; await process_frame

func test_health_signal_reentry() -> void:
	var host := Node2D.new(); root.add_child(host)
	var first := SignalReceiver.new(); var second := SignalReceiver.new()
	host.add_child(first); host.add_child(second)
	var shot := Shot.new(); shot.damage = 9; shot.pierce = 0
	host.add_child(shot); shot.set_physics_process(false)
	var callbacks := [0]
	first.health.health_changed.connect(func(_current,_maximum):
		callbacks[0] += 1; shot._on_body_entered(second))
	shot._on_body_entered(first)
	check(callbacks[0]==1 and first.health.current_health==91,"real HealthComponent did not deliver synchronous damage signal")
	check(second.health.current_health==100 and shot.is_queued_for_deletion(),"synchronous damage-signal reentry bypassed zero-pierce impact budget")
	host.free(); await process_frame; await process_frame

func run() -> void:
	await test_actual_first_wall_entry()
	await test_ordered_queued_entry()
	await test_one_pierce_control()
	await test_multiplier_cancellation()
	await test_health_signal_reentry()
	print("FIRST IMPACT CHECKS: %d failures=%d"%[checks,failures])
	if not failures: print("TEST PASS: ProjectileFirstImpactTest %d"%checks)
	quit(1 if failures else 0)
