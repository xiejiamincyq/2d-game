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

	upgrades.add_experience(92)
	if not _assert_true(upgrades.level == 4, "92 XP reached level %d instead of 4" % upgrades.level):
		return
	if not _assert_true(upgrades.pending_upgrade_count == 3 and upgrades.awaiting_choice, "three crossed levels were not queued"):
		return
	if not _assert_true(upgrades.pending_choices.size() == 3, "first transaction did not contain three choices"):
		return

	var damage_before: float = player.weapon_damage
	var pending_before: int = upgrades.pending_upgrade_count
	paused = true
	var forged_result: Variant = upgrades.apply_upgrade({"id": "forged", "label": "forged"})
	if not _assert_true(forged_result == false, "forged choice was not rejected"):
		return
	if not _assert_true(paused, "forged choice changed global pause"):
		return
	if not _assert_true(player.weapon_damage == damage_before and upgrades.pending_upgrade_count == pending_before, "forged choice changed gameplay state"):
		return
	paused = false

	var first_choice: Dictionary = upgrades.pending_choices[0].duplicate(true)
	var first_result: Variant = upgrades.apply_upgrade(first_choice)
	if not _assert_true(first_result == true, "current choice was rejected"):
		return
	var pending_after_first: int = upgrades.pending_upgrade_count
	var duplicate_result: Variant = upgrades.apply_upgrade(first_choice)
	if not _assert_true(duplicate_result == false, "consumed transaction was accepted twice"):
		return
	if not _assert_true(upgrades.pending_upgrade_count == pending_after_first, "duplicate choice consumed another queued level"):
		return

	while upgrades.pending_upgrade_count > 0:
		var current: Dictionary = upgrades.pending_choices[0].duplicate(true)
		if not _assert_true(upgrades.apply_upgrade(current), "queued choice was not accepted"):
			return
	if not _assert_true(not upgrades.awaiting_choice and upgrades.pending_choices.is_empty(), "upgrade queue did not finish cleanly"):
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
