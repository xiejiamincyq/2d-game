extends SceneTree

const PlayerScript = preload("res://scripts/actors/Player.gd")
const DamageTypes = preload("res://scripts/components/DamageTypes.gd")
const ArcPulseScript = preload("res://scripts/components/ArcPulseVisual.gd")

class ArcTarget extends Node2D:
	var hit_count: int = 0
	var damage_received: float = 0.0

	func take_damage(amount: float, _source: StringName = &"generic", _direction: Vector2 = Vector2.ZERO) -> bool:
		hit_count += 1
		damage_received += amount
		return true

var assertions := 0

func _assert_true(condition: bool, message: String) -> bool:
	assertions += 1
	if condition:
		return true
	push_error("TEST FAIL: DamageTest: " + message)
	quit(1)
	return false

func _initialize() -> void:
	var player: Node = PlayerScript.new()
	root.add_child(player)
	await process_frame
	player.set_physics_process(false)
	player.health.set_process(false)
	player.shield = 20.0
	player.arc_pulse_level = 1
	if not _assert_true(
		is_equal_approx(player.arc_damage, 17.0)
		and is_equal_approx(player.get_arc_pulse_damage(), 23.0)
		and is_equal_approx(player.spike_spacing, 96.0)
		and is_equal_approx(player.get_arc_pulse_expansion_speed_scale(), 0.5),
		"base arc damage, spike density, or global arc expansion speed did not match the phase 17 contract"
	):
		return
	player.arc_pulse_level = 0

	var accepted: Array[Variant] = []
	accepted.append(player.take_damage(8.0))
	for repeat_index in range(4):
		player.health._process(0.1)
		var before_hit: float = player.health.invulnerable_time
		accepted.append(player.take_damage(8.0))
		if repeat_index < 3 and not _assert_true(
			is_equal_approx(player.health.invulnerable_time, before_hit),
			"a rejected hit refreshed the invulnerability timer"
		):
			return

	if not _assert_true(accepted == [true, false, false, false, true], "accepted-hit sequence was %s" % [accepted]):
		return
	if not _assert_true(is_equal_approx(player.shield, 4.0), "shield was %.2f instead of 4.0" % player.shield):
		return
	if not _assert_true(is_equal_approx(player.health.current_health, 100.0), "health changed while shield covered accepted hits"):
		return

	player.health.invulnerable_time = 0.0
	player.set_damage_modifier(&"projectile_boost", 1.5, DamageTypes.PROJECTILE)
	player.set_damage_modifier(&"projectile_boost", 1.5, DamageTypes.PROJECTILE)
	if not _assert_true(
		is_equal_approx(player.get_effective_damage_multiplier(DamageTypes.PROJECTILE), 1.5),
		"reapplying one source-specific damage modifier accumulated"
	):
		return
	if not _assert_true(
		is_equal_approx(player.get_effective_damage_multiplier(DamageTypes.LASER), 1.0),
		"a projectile modifier leaked into another damage source"
	):
		return
	player.set_overdrive_active(true)
	player.set_overdrive_active(true)
	var normal_arc_interval: float = maxf(0.7, player.arc_base_interval - player.arc_pulse_level * 0.20)
	if not _assert_true(
		is_equal_approx(player.get_effective_damage_multiplier(DamageTypes.PROJECTILE), 1.8),
		"overdrive and source damage modifiers did not compose without stacking"
	):
		return
	if not _assert_true(
		is_equal_approx(player.get_effective_damage_multiplier(DamageTypes.SPIKE), 2.0)
		and is_equal_approx(player.get_effective_damage_multiplier(DamageTypes.LASER), 2.0)
		and is_equal_approx(player.get_effective_damage_multiplier(DamageTypes.ARC), 1.5),
		"overdrive did not apply the requested spike, laser, and arc damage multipliers"
	):
		return
	if not _assert_true(
		is_equal_approx(player.get_effective_move_speed(), player.move_speed * 1.3)
		and is_equal_approx(player.get_effective_dash_cooldown(), player.dash_cooldown * 0.7)
		and is_equal_approx(player.get_arc_pulse_interval(), normal_arc_interval / 1.5)
		and is_equal_approx(player.get_arc_pulse_radius(), player.arc_radius * 2.0)
		and is_equal_approx(player.get_drone_laser_width(), 6.0),
		"overdrive mobility, arc frequency/range, or drone beam width was incorrect"
	):
		return

	player.set_dash_immunity_active(true)
	player.set_overdrive_active(false)
	if not _assert_true(player.is_damage_immune(), "ending overdrive cleared active dash immunity"):
		return
	var shield_before_immune_hit: float = player.shield
	if not _assert_true(not player.take_damage(8.0), "dash immunity accepted damage"):
		return
	if not _assert_true(
		is_equal_approx(player.shield, shield_before_immune_hit),
		"an immune hit changed shield"
	):
		return
	player.set_overdrive_active(true)
	player.set_dash_immunity_active(false)
	if not _assert_true(player.is_damage_immune(), "ending dash immunity cleared active overdrive immunity"):
		return
	player.set_overdrive_active(false)
	if not _assert_true(not player.is_damage_immune(), "immunity remained after all sources ended"):
		return
	if not _assert_true(
		is_equal_approx(player.get_effective_move_speed(), player.move_speed)
		and is_equal_approx(player.get_effective_dash_cooldown(), player.dash_cooldown)
		and is_equal_approx(player.get_arc_pulse_interval(), normal_arc_interval)
		and is_equal_approx(player.get_arc_pulse_radius(), player.arc_radius)
		and is_equal_approx(player.get_drone_laser_width(), 4.0),
		"ending overdrive did not restore movement, dash, arc, and laser geometry"
	):
		return
	player.clear_damage_modifier(&"projectile_boost", DamageTypes.PROJECTILE)
	if not _assert_true(
		is_equal_approx(player.get_effective_damage_multiplier(DamageTypes.PROJECTILE), 1.0),
		"clearing a source-specific damage modifier did not restore the base multiplier"
	):
		return

	var spawned_attacks := Node2D.new()
	root.add_child(spawned_attacks)
	player.projectile_parent = spawned_attacks
	var spawned_shots: Array[Node] = []
	player.fired.connect(func(shot: Node) -> void:
		spawned_attacks.add_child(shot)
		spawned_shots.append(shot)
	)
	player.weapon_damage = 10.0
	player.set_overdrive_active(false)
	player._spawn_bullet(Vector2.RIGHT)
	var persistent_shot: Node = spawned_shots[0]
	if not _assert_true(is_equal_approx(persistent_shot.global_position.x, 32.5), "projectile muzzle offset did not follow the 30% larger player visual"):
		return
	player.set_overdrive_active(true)
	if not _assert_true(
		is_equal_approx(persistent_shot.get_resolved_damage(), 12.0),
		"a projectile created before overdrive did not gain its active damage multiplier"
	):
		return
	var shots_before_overdrive_volley := spawned_shots.size()
	player.weapon_lines = 3
	player._fire()
	var overdrive_volley_count := spawned_shots.size() - shots_before_overdrive_volley
	if not _assert_true(overdrive_volley_count == 6, "overdrive fired %d lines instead of double the configured three" % overdrive_volley_count):
		return
	player.weapon_lines = 5
	var shots_before_capped_volley := spawned_shots.size()
	player._fire()
	var capped_overdrive_volley_count := spawned_shots.size() - shots_before_capped_volley
	if not _assert_true(capped_overdrive_volley_count == 8, "overdrive exceeded the eight-line cap with %d shots" % capped_overdrive_volley_count):
		return
	var overdrive_shot: Node = spawned_shots[spawned_shots.size() - 1]
	if not _assert_true(
		overdrive_shot.get("overdrive_visual")
		and overdrive_shot.tint.is_equal_approx(Color("b45cff"))
		and overdrive_shot.get_node_or_null("OverdriveParticles") is GPUParticles2D,
		"overdrive projectile did not receive the purple glowing particle treatment"
	):
		return
	player.set_overdrive_active(false)
	if not _assert_true(
		is_equal_approx(persistent_shot.get_resolved_damage(), 10.0),
		"a projectile retained overdrive damage after the window ended"
	):
		return

	player.spike_damage = 12.0
	player._drop_spike_trap_at(Vector2.ZERO)
	var persistent_spike: Node = spawned_attacks.get_child(spawned_attacks.get_child_count() - 1)
	player.set_overdrive_active(true)
	if not _assert_true(
		is_equal_approx(persistent_spike.get_resolved_damage(), 24.0),
		"a spike created before overdrive did not gain its active damage multiplier"
	):
		return
	player._drop_spike_trap_at(Vector2(32.0, 0.0))
	var overdrive_spike: Node = spawned_attacks.get_child(spawned_attacks.get_child_count() - 1)
	if not _assert_true(
		is_equal_approx(overdrive_spike.radius, player.spike_radius * 2.0)
		and is_equal_approx(overdrive_spike.lifetime, player.spike_duration * 1.5),
		"a spike generated during overdrive did not receive double size and 1.5x duration"
	):
		return
	player.set_overdrive_active(false)
	if not _assert_true(
		is_equal_approx(persistent_spike.get_resolved_damage(), 12.0),
		"a spike retained overdrive damage after the window ended"
	):
		return

	player.set_build_family_levels({
		"ballistics": 3,
		"mobility": 2,
		"automation": 4,
	})
	if not _assert_true(
		is_equal_approx(player.get_effective_damage_multiplier(DamageTypes.PROJECTILE), 1.1025),
		"ballistics level did not add 5% compounded projectile damage per level"
	):
		return
	if not _assert_true(
		is_equal_approx(player.get_effective_damage_multiplier(DamageTypes.DASH), 1.05)
		and is_equal_approx(player.get_effective_damage_multiplier(DamageTypes.SPIKE), 1.05),
		"mobility level did not apply to both dash and spike damage"
	):
		return
	if not _assert_true(
		is_equal_approx(player.get_effective_damage_multiplier(DamageTypes.LASER), 1.157625)
		and is_equal_approx(player.get_effective_damage_multiplier(DamageTypes.ARC), 1.157625),
		"automation level did not apply to laser and arc damage"
	):
		return

	var original_dash_cooldown: float = player.dash_cooldown
	var original_dash_distance: float = player.dash_distance
	var original_spike_spacing: float = player.spike_spacing
	if not _assert_true(player.activate_build_evolution("rift_overdrive"), "rift evolution was rejected"):
		return
	if not _assert_true(
		player.mine_level >= 1
		and player.dash_cooldown < original_dash_cooldown
		and player.dash_distance > original_dash_distance
		and player.spike_spacing < original_spike_spacing,
		"rift evolution did not unlock and strengthen its linked mobility mechanics"
	):
		return
	if not _assert_true(not player.activate_build_evolution("rift_overdrive"), "duplicate evolution activation stacked"):
		return
	player._reset_spike_path()
	player.global_position = Vector2.ZERO
	player._update_spike_path(false)
	var walking_spike: Node = spawned_attacks.get_child(spawned_attacks.get_child_count() - 1)
	player.global_position = Vector2(player.spike_spacing * 1.1, 0.0)
	player._update_spike_path(true)
	var rift_dash_spike: Node = spawned_attacks.get_child(spawned_attacks.get_child_count() - 1)
	if not _assert_true(
		not walking_spike.rift_variant
		and walking_spike.damage_source == DamageTypes.SPIKE
		and is_equal_approx(walking_spike.damage, player.spike_damage),
		"walking after the mobility evolution no longer produced the original spike"
	):
		return
	if not _assert_true(
		rift_dash_spike.rift_variant
		and rift_dash_spike.damage_source == DamageTypes.DASH
		and is_equal_approx(rift_dash_spike.damage, player.spike_damage * 3.0)
		and rift_dash_spike.get_primary_color().get_luminance() < 0.08,
		"mobility-evolution dash did not produce a visible black triple-damage spike"
	):
		return

	var shots_before_storm := spawned_shots.size()
	if not _assert_true(player.activate_build_evolution("orbital_storm"), "orbital evolution was rejected"):
		return
	for volley in range(5):
		player._fire()
	var storm_shot_count := spawned_shots.size() - shots_before_storm
	if not _assert_true(
		storm_shot_count == player.weapon_lines * 5 + 12,
		"orbital evolution spawned %d shots instead of five volleys plus 12 radial shots" % storm_shot_count
	):
		return

	player.drone_count = 1
	player.arc_pulse_level = 1
	var drones_before_matrix: int = player.drone_count
	var drone_damage_before_matrix: float = player.drone_damage
	if not _assert_true(player.activate_build_evolution("thunder_matrix"), "thunder evolution was rejected"):
		return
	if not _assert_true(
		player.drone_count == drones_before_matrix
		and is_equal_approx(player.drone_damage, drone_damage_before_matrix * 2.0)
		and player.get_arc_pulse_radius() >= player.get_viewport_rect().size.length()
		and is_equal_approx(player.get_arc_pulse_expansion_speed_scale(), 0.5)
		and player.get_drone_laser_color().is_equal_approx(Color("b45cff")),
		"thunder evolution changed drone count or lost its full-screen, slow arc and purple laser contract"
	):
		return

	var near_target := ArcTarget.new()
	var far_target := ArcTarget.new()
	near_target.position = Vector2(24.0, 0.0)
	far_target.position = Vector2(88.0, 0.0)
	root.add_child(near_target)
	root.add_child(far_target)
	var arc_targets: Array[Node] = [near_target, far_target]
	var wave: Node = ArcPulseScript.new()
	root.add_child(wave)
	wave.set_process(false)
	wave.setup(100.0, 25.0, func() -> Array[Node]: return arc_targets, 0.3)
	if not _assert_true(
		is_equal_approx(wave.lifetime, 0.42 / 0.3)
		and near_target.hit_count == 0
		and far_target.hit_count == 0,
		"slow arc wave damaged enemies instantly or used the wrong expansion duration"
	):
		return
	wave._process(0.10)
	if not _assert_true(near_target.hit_count == 1 and far_target.hit_count == 0, "arc wavefront did not damage only the enemy it reached"):
		return
	wave._process(1.10)
	wave._process(0.05)
	if not _assert_true(
		near_target.hit_count == 1
		and far_target.hit_count == 1
		and is_equal_approx(near_target.damage_received, 20.5)
		and is_equal_approx(far_target.damage_received, 8.5),
		"one arc wave did not apply exactly one distance-decayed hit per touched enemy"
	):
		return
	wave.queue_free()
	near_target.queue_free()
	far_target.queue_free()

	var target_a := Node2D.new()
	var target_b := Node2D.new()
	target_a.position = Vector2(10.0, 0.0)
	target_b.position = Vector2(20.0, 0.0)
	root.add_child(target_a)
	root.add_child(target_b)
	var target_pool: Array[Node] = [target_a, target_b]
	var assigned_targets: Array[Node2D] = [target_a]
	if not _assert_true(
		player._nearest_unassigned_enemy(Vector2.ZERO, assigned_targets, target_pool) == target_b,
		"a drone reused an assigned target while an unassigned target existed"
	):
		return
	assigned_targets.append(target_b)
	if not _assert_true(
		player._nearest_unassigned_enemy(Vector2.ZERO, assigned_targets, target_pool) == target_a,
		"a drone did not fall back to the nearest occupied target when no free target remained"
	):
		return
	target_a.queue_free()
	target_b.queue_free()

	player.queue_free()
	spawned_attacks.queue_free()
	await process_frame
	print("TEST PASS: DamageTest %d" % assertions)
	quit(0)
