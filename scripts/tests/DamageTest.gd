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

	player.queue_free()
	await process_frame
	print("TEST PASS: DamageTest %d" % assertions)
	quit(0)
