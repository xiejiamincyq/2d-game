extends SceneTree

const PlayerScript = preload("res://scripts/actors/Player.gd")
const CombatFeedbackScript = preload("res://scripts/systems/CombatFeedback.gd")
const DamageTypes = preload("res://scripts/components/DamageTypes.gd")

class DroneTarget extends CharacterBody2D:
	var damage_received := 0.0
	var burn_count := 0
	var burn_sources: Array[StringName] = []
	var body_radius := 14.0

	func _init() -> void:
		var shape := CollisionShape2D.new()
		var circle := CircleShape2D.new()
		circle.radius = body_radius
		shape.shape = circle
		add_child(shape)

	func take_damage(amount: float, _source: StringName = &"generic", _direction: Vector2 = Vector2.ZERO) -> bool:
		damage_received += amount
		return false

	func apply_burn_stack(_base_attack: float, _duration: float, _slow: float = 0.0, source: StringName = &"burn") -> bool:
		burn_count += 1
		burn_sources.append(source)
		return true

class AudioProbe extends Node:
	var hit_count := 0
	func play_hit(_source: StringName, _weight: int) -> void:
		hit_count += 1

var assertions := 0

func _assert_true(condition: bool, message: String) -> bool:
	assertions += 1
	if condition:
		return true
	push_error("TEST FAIL: Phase21Test: " + message)
	quit(1)
	return false

func _initialize() -> void:
	var projectiles := Node2D.new()
	root.add_child(projectiles)
	var player: Node = PlayerScript.new()
	root.add_child(player)
	await process_frame
	player.set_physics_process(false)
	player.projectile_parent = projectiles
	player.drone_count = 1
	player.global_position = Vector2.ZERO
	player._sync_drone_visuals()
	player.drone_visuals[0].global_position = Vector2.ZERO

	var lock_target := DroneTarget.new()
	lock_target.global_position = Vector2(0.0, 300.0)
	root.add_child(lock_target)
	var swept_target := DroneTarget.new()
	swept_target.global_position = Vector2.RIGHT.rotated(deg_to_rad(15.0)) * 600.0
	root.add_child(swept_target)
	await physics_frame
	player.set_enemy_provider(func() -> Array[Node]: return [lock_target, swept_target])
	player.drone_aim_directions[0] = Vector2.RIGHT
	player._update_drone_lasers(0.1)
	if not _assert_true(absf(player.drone_aim_directions[0].angle_to(Vector2.RIGHT.rotated(deg_to_rad(15.0)))) < 0.001, "drone did not turn at 150 degrees per second"):
		return
	if not _assert_true(swept_target.damage_received > 0.0 and is_zero_approx(lock_target.damage_received), "turning laser did not hit the enemy actually crossed by the ray"):
		return
	if not _assert_true(swept_target.burn_count == 0, "a brief swept hit ignited an enemy before the 0.6 second threshold"):
		return
	if not _assert_true(
		player.drone_reticles.size() == 1
		and player.drone_reticles[0].visible
		and player.drone_reticles[0].global_position.is_equal_approx(lock_target.global_position)
		and player.drone_reticles[0].RETICLE_COLOR.r > 0.9
		and player.drone_reticles[0].RETICLE_COLOR.g < 0.4,
		"small red lock reticle did not follow the selected target"
	):
		return

	lock_target.global_position = Vector2(800.0, 0.0)
	swept_target.global_position = Vector2(-800.0, 0.0)
	player.drone_aim_directions[0] = Vector2.RIGHT
	player._update_drone_lasers(0.59)
	if not _assert_true(lock_target.burn_count == 0, "normal laser ignited before 0.6 seconds"):
		return
	player._update_drone_lasers(0.01)
	if not _assert_true(lock_target.burn_count == 1 and lock_target.burn_sources == [DamageTypes.SILENT_BURN], "normal laser did not silently ignite at 0.6 seconds"):
		return

	player.drone_laser_piercing = true
	player._clear_drone_burn_tracks()
	player._update_drone_lasers(0.29)
	if not _assert_true(lock_target.burn_count == 1, "piercing laser ignited before 0.3 seconds"):
		return
	player._update_drone_lasers(0.01)
	if not _assert_true(lock_target.burn_count == 2, "piercing card did not reduce ignition threshold to 0.3 seconds"):
		return

	var blocker := StaticBody2D.new()
	var blocker_shape := CollisionShape2D.new()
	var blocker_rect := RectangleShape2D.new()
	blocker_rect.size = Vector2(30.0, 120.0)
	blocker_shape.shape = blocker_rect
	blocker.add_child(blocker_shape)
	blocker.global_position = Vector2(400.0, 0.0)
	root.add_child(blocker)
	await physics_frame
	lock_target.damage_received = 0.0
	player.drone_laser_piercing = false
	player._update_drone_lasers(0.1)
	if not _assert_true(is_zero_approx(lock_target.damage_received), "ordinary laser passed through a world blocker"):
		return
	player.drone_laser_piercing = true
	player._update_drone_lasers(0.1)
	if not _assert_true(lock_target.damage_received > 0.0, "piercing laser did not ignore a world blocker"):
		return
	blocker.queue_free()
	await physics_frame
	lock_target.global_position = Vector2(5000.0, 0.0)
	lock_target.damage_received = 0.0
	player.set_enemy_provider(func() -> Array[Node]: return [lock_target])
	await physics_frame
	player.drone_laser_piercing = false
	player.drone_aim_directions[0] = Vector2.RIGHT
	player._update_drone_lasers(0.1)
	if not _assert_true(lock_target.damage_received > 0.0, "laser retained the old short target-distance limit"):
		return

	var audio := AudioProbe.new()
	root.add_child(audio)
	var feedback: Node = CombatFeedbackScript.new()
	root.add_child(feedback)
	feedback.setup(null, null, audio)
	feedback.on_damage_resolved(lock_target, DamageTypes.SILENT_BURN, 3.0, Vector2.ZERO, Vector2.ZERO, false)
	if not _assert_true(audio.hit_count == 0, "drone burn still requested a hit sound"):
		return
	feedback.on_damage_resolved(lock_target, DamageTypes.BURN, 3.0, Vector2.ZERO, Vector2.ZERO, false)
	if not _assert_true(audio.hit_count == 1, "silencing drone burn also removed other burn audio"):
		return

	player.last_movement_direction = Vector2.LEFT
	player.velocity = Vector2.ZERO
	if not _assert_true(player._resolve_dash_direction(Vector2.UP).is_equal_approx(Vector2.UP), "dash did not prefer current movement input"):
		return
	if not _assert_true(player._resolve_dash_direction(Vector2.ZERO).is_equal_approx(Vector2.LEFT), "stationary dash did not preserve the last movement direction"):
		return

	feedback.queue_free()
	audio.queue_free()
	lock_target.queue_free()
	swept_target.queue_free()
	player.queue_free()
	projectiles.queue_free()
	await process_frame
	await process_frame
	print("TEST PASS: Phase21Test %d" % assertions)
	quit(0)
