extends SceneTree

const PlayerScript = preload("res://scripts/actors/Player.gd")
const UpgradeSystemScript = preload("res://scripts/systems/UpgradeSystem.gd")

var assertions := 0

func _assert_true(condition: bool, message: String) -> bool:
	assertions += 1
	if condition:
		return true
	push_error("TEST FAIL: UpgradeTest: " + message)
	paused = false
	quit(1)
	return false

func _initialize() -> void:
	var player: Node = PlayerScript.new()
	root.add_child(player)
	var upgrades: Node = UpgradeSystemScript.new()
	upgrades.process_mode = Node.PROCESS_MODE_ALWAYS
	root.add_child(upgrades)
	await process_frame
	player.set_physics_process(false)
	upgrades.setup(player)

	var progression_events: Array[Dictionary] = []
	upgrades.progression_changed.connect(func(coins: int, level: int) -> void:
		progression_events.append({"coins": coins, "level": level})
	)
	if not _assert_true(upgrades.coins == 0 and upgrades.level == 1, "progression did not start at zero coins and level one"):
		return
	if not _assert_true(upgrades.add_coins(12) and upgrades.coins == 12, "valid coins were not added"):
		return
	if not _assert_true(not upgrades.add_coins(0) and not upgrades.add_coins(-2) and upgrades.coins == 12, "invalid coin income changed the balance"):
		return
	if not _assert_true(upgrades.spend_coins(5) and upgrades.coins == 7, "valid coin spend was rejected"):
		return
	if not _assert_true(not upgrades.spend_coins(8) and not upgrades.spend_coins(0) and upgrades.coins == 7, "invalid coin spend changed the balance"):
		return

	if not _assert_true(upgrades.queue_wave_upgrade(1), "first cleared wave was not rewarded"):
		return
	if not _assert_true(not upgrades.queue_wave_upgrade(1), "the same cleared wave was rewarded twice"):
		return
	if not _assert_true(not upgrades.queue_wave_upgrade(0), "invalid wave index was rewarded"):
		return
	if not _assert_true(upgrades.level == 1, "level advanced before the upgrade was applied"):
		return
	if not _assert_true(upgrades.pending_upgrade_count == 1 and upgrades.awaiting_choice, "wave reward did not queue one choice transaction"):
		return
	if not _assert_true(upgrades.pending_choices.size() == 3, "wave reward did not present three choices"):
		return

	var damage_before: float = player.weapon_damage
	var forged_result: Variant = upgrades.apply_upgrade({"id": "forged", "label": "forged"})
	if not _assert_true(forged_result == false, "forged choice was not rejected"):
		return
	if not _assert_true(player.weapon_damage == damage_before and upgrades.pending_upgrade_count == 1, "forged choice changed progression"):
		return

	var first_choice: Dictionary = upgrades.pending_choices[0].duplicate(true)
	if not _assert_true(upgrades.apply_upgrade(first_choice), "current wave choice was rejected"):
		return
	if not _assert_true(upgrades.level == 2 and upgrades.pending_upgrade_count == 0, "applied wave upgrade did not advance exactly one level"):
		return
	if not _assert_true(not upgrades.awaiting_choice and upgrades.pending_choices.is_empty(), "wave upgrade transaction did not finish cleanly"):
		return
	if not _assert_true(not upgrades.apply_upgrade(first_choice), "consumed transaction was accepted twice"):
		return
	if not _assert_true(not progression_events.is_empty() and progression_events[-1] == {"coins": 7, "level": 2}, "progression signal did not publish the final state"):
		return

	upgrades.upgrade_counts["fire_rate"] = 12
	upgrades.choice_generation += 1
	var capped_choice := {"id": "fire_rate", "label": "capped", "_transaction": upgrades.choice_generation}
	upgrades.pending_choices.assign([capped_choice])
	upgrades.pending_upgrade_count = 1
	upgrades.awaiting_choice = true
	var capped_rate_before: float = player.fire_rate
	if not _assert_true(upgrades.apply_upgrade(capped_choice) == false, "a capped upgrade transaction was accepted"):
		return
	if not _assert_true(is_equal_approx(player.fire_rate, capped_rate_before), "capped fire rate changed player stats"):
		return

	upgrades.queue_free()
	player.queue_free()
	await process_frame
	print("TEST PASS: UpgradeTest %d" % assertions)
	quit(0)
