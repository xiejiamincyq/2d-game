extends SceneTree

const PlayerScript = preload("res://scripts/actors/Player.gd")
const DamageTypes = preload("res://scripts/components/DamageTypes.gd")

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
	if not _assert_true(
		is_equal_approx(player.get_effective_damage_multiplier(DamageTypes.PROJECTILE), 6.0),
		"overdrive and source damage modifiers did not compose without stacking"
	):
		return
	if not _assert_true(
		is_equal_approx(player.get_effective_damage_multiplier(DamageTypes.LASER), 4.0),
		"overdrive did not apply to all damage sources"
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
	player.set_overdrive_active(true)
	if not _assert_true(
		is_equal_approx(persistent_shot.get_resolved_damage(), 40.0),
		"a projectile created before overdrive did not gain its active damage multiplier"
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
		is_equal_approx(persistent_spike.get_resolved_damage(), 48.0),
		"a spike created before overdrive did not gain its active damage multiplier"
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

	var drones_before_matrix: int = player.drone_count
	if not _assert_true(player.activate_build_evolution("thunder_matrix"), "thunder evolution was rejected"):
		return
	if not _assert_true(
		player.drone_count >= maxi(2, drones_before_matrix + 1)
		and player.arc_pulse_level >= 1,
		"thunder evolution did not guarantee both drone and arc mechanics"
	):
		return

	player.queue_free()
	spawned_attacks.queue_free()
	await process_frame
	print("TEST PASS: DamageTest %d" % assertions)
	quit(0)
