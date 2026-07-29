extends SceneTree

const PlayerScript = preload("res://scripts/actors/Player.gd")
const EnemyScript = preload("res://scripts/actors/Enemy.gd")
const SpikeTrapScript = preload("res://scripts/components/SpikeTrap.gd")
const BurnStatusScript = preload("res://scripts/components/BurnStatus.gd")
const DamageTypes = preload("res://scripts/components/DamageTypes.gd")

class DroneTarget extends Node2D:
	var damage_received := 0.0
	var body_radius := 12.0

	func take_damage(amount: float, _source: StringName = &"generic", _direction: Vector2 = Vector2.ZERO) -> bool:
		damage_received += amount
		return false

	func apply_burn_stack(_base_attack: float, _duration: float, _slow: float = 0.0, _source: StringName = &"burn") -> bool:
		return true

var assertions := 0

func _assert_true(condition: bool, message: String) -> bool:
	assertions += 1
	if condition:
		return true
	push_error("TEST FAIL: Phase20Test: " + message)
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

	var burn: RefCounted = BurnStatusScript.new()
	burn.apply_stack(10.0, 4.0)
	if not _assert_true(is_equal_approx(burn.get_damage_per_second(), 6.0), "burn damage was not doubled to 60% base attack per stack"):
		return

	for kind in [EnemyScript.EnemyKind.SCRAPPER, EnemyScript.EnemyKind.DASHER]:
		var melee: Node = EnemyScript.new()
		melee.setup(kind, 6, projectiles)
		if not _assert_true(is_equal_approx(melee.speed, PlayerScript.BASE_MOVE_SPEED * 0.90), "melee enemy %d did not use 90%% player speed" % kind):
			return
		melee.queue_free()
	for kind in [EnemyScript.EnemyKind.SPITTER, EnemyScript.EnemyKind.MARKSMAN, EnemyScript.EnemyKind.LOBBER]:
		var ranged: Node = EnemyScript.new()
		ranged.setup(kind, 6, projectiles)
		if not _assert_true(is_equal_approx(ranged.speed, PlayerScript.BASE_MOVE_SPEED * 0.60), "ranged enemy %d did not use 60%% player speed" % kind):
			return
		ranged.queue_free()

	var fired: Array[Node] = []
	player.fired.connect(func(projectile: Node) -> void:
		projectiles.add_child(projectile)
		projectile.set_physics_process(false)
		fired.append(projectile)
	)
	player.activate_build_evolution("orbital_storm")
	player.velocity = Vector2(100.0, 50.0)
	player._spawn_bullet(Vector2.RIGHT)
	if not _assert_true(fired[-1].velocity.is_equal_approx(Vector2(348.0, 50.0)), "grenade did not combine player inertia with 40% muzzle speed"):
		return

	player.set_overdrive_active(true)
	if not _assert_true(
		is_equal_approx(player.get_effective_damage_multiplier(DamageTypes.ARC), 1.0)
		and is_equal_approx(player.get_effective_damage_multiplier(DamageTypes.LASER), 1.0),
		"overdrive still applied a direct arc or drone laser damage multiplier"
	):
		return
	player.set_overdrive_active(false)

	var dash_cooldown_before: float = player.dash_cooldown
	var dash_distance_before: float = player.dash_distance
	var normal_layer: int = player.collision_layer
	var normal_mask: int = player.collision_mask
	player.activate_build_evolution("rift_overdrive")
	if not _assert_true(
		is_equal_approx(player.dash_cooldown, dash_cooldown_before * 1.20)
		and is_equal_approx(player.dash_distance, dash_distance_before * 1.20),
		"assassin evolution did not add 20% dash distance and 20% dash cooldown"
	):
		return
	player.velocity = Vector2.ZERO
	player.global_position = Vector2.ZERO
	player.dash_cooldown_remaining = 0.0
	player._start_dash(Vector2.RIGHT)
	player._update_dash(player.dash_duration)
	await process_frame
	if not _assert_true(
		is_equal_approx(player.global_position.x, dash_distance_before * 1.20)
		and player.is_stealthed()
		and player.collision_layer == 0
		and player.collision_mask == 0
		and player.player_collision.disabled,
		"assassin dash distance or collision-free stealth window was incorrect"
	):
		return
	player._fire()
	await process_frame
	if not _assert_true(
		not player.is_stealthed()
		and player.collision_layer == normal_layer
		and player.collision_mask == normal_mask
		and not player.player_collision.disabled,
		"breaking stealth did not restore the full player collision contract"
	):
		return
	player._activate_assassin_stealth()
	player._update_stealth(player.ASSASSIN_STEALTH_SECONDS + 0.01)
	await process_frame
	if not _assert_true(
		not player.is_stealthed()
		and player.collision_layer == normal_layer
		and player.collision_mask == normal_mask
		and not player.player_collision.disabled,
		"natural stealth timeout did not restore player collision"
	):
		return
	player._activate_assassin_stealth()
	player.clear_runtime_modifiers()
	await process_frame
	if not _assert_true(
		player.collision_layer == normal_layer
		and player.collision_mask == normal_mask
		and not player.player_collision.disabled,
		"runtime modifier cleanup did not restore player collision"
	):
		return

	var spike_enemy: Node = EnemyScript.new()
	spike_enemy.setup(EnemyScript.EnemyKind.BRUISER, 0, projectiles)
	spike_enemy.global_position = Vector2(600.0, 0.0)
	root.add_child(spike_enemy)
	var traps: Array[Node] = []
	for index in range(4):
		var trap: Node = SpikeTrapScript.new()
		trap.global_position = spike_enemy.global_position
		trap.damage = 1.0
		trap.radius = 40.0
		trap.set_process(false)
		root.add_child(trap)
		traps.append(trap)
	await physics_frame
	await physics_frame
	var health_before_spikes: float = spike_enemy.health.current_health
	for trap in traps:
		trap._damage_enemies()
	var first_spike_damage := health_before_spikes - float(spike_enemy.health.current_health)
	if not _assert_true(is_equal_approx(first_spike_damage, 3.0), "four overlapping spikes dealt %.2f damage instead of capping at three" % first_spike_damage):
		return
	traps[0].queue_free()
	await process_frame
	await physics_frame
	var health_before_replacement: float = spike_enemy.health.current_health
	for index in range(1, traps.size()):
		traps[index]._damage_enemies()
	var replacement_spike_damage := health_before_replacement - float(spike_enemy.health.current_health)
	if not _assert_true(is_equal_approx(replacement_spike_damage, 3.0), "remaining spikes dealt %.2f damage after one slot was released" % replacement_spike_damage):
		return

	var drone_target := DroneTarget.new()
	drone_target.global_position = Vector2(0.0, 1000.0)
	root.add_child(drone_target)
	player.global_position = Vector2.ZERO
	player.velocity = Vector2.ZERO
	player.drone_count = 1
	player.set_enemy_provider(func() -> Array[Node]: return [drone_target])
	player._sync_drone_visuals()
	player._update_drone_positions()
	player._update_drone_lasers(0.1)
	var first_direction: Vector2 = player.drone_aim_directions[0]
	var first_turn := absf(first_direction.angle_to(Vector2.RIGHT))
	if not _assert_true(
		first_turn <= deg_to_rad(15.0) + 0.001
		and first_turn >= deg_to_rad(14.0)
		and is_zero_approx(drone_target.damage_received),
		"drone laser exceeded 150 degrees per second or damaged before aiming"
	):
		return
	player._update_drone_lasers(0.6)
	if not _assert_true(drone_target.damage_received > 0.0, "drone laser failed to damage after completing its limited turn"):
		return

	for trap in traps:
		if is_instance_valid(trap):
			trap.queue_free()
	spike_enemy.queue_free()
	drone_target.queue_free()
	player.queue_free()
	projectiles.queue_free()
	await process_frame
	await process_frame
	print("TEST PASS: Phase20Test %d" % assertions)
	quit(0)
