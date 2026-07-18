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

	var shop_events: Array[Dictionary] = []
	upgrades.shop_changed.connect(func(state: Dictionary) -> void: shop_events.append(state.duplicate(true)))
	upgrades.add_coins(200)
	if not _assert_true(upgrades.prepare_shop_for_wave(1), "first wave shop was not prepared"):
		return
	var wave_one_shop: Dictionary = upgrades.get_shop_state()
	if not _assert_true(wave_one_shop["wave"] == 1 and wave_one_shop["offers"].size() == 3, "wave one shop did not contain three offers"):
		return
	for offer_value in wave_one_shop["offers"]:
		var offer: Dictionary = offer_value
		if not _assert_true(
			offer.has("family") and offer.has("kind") and int(offer["cost"]) > 0 and int(offer["_shop_transaction"]) > 0,
			"shop offer was missing catalog metadata: %s" % [offer]
		):
			return
	var stable_snapshot: Dictionary = wave_one_shop.duplicate(true)
	if not _assert_true(not upgrades.prepare_shop_for_wave(1) and upgrades.get_shop_state() == stable_snapshot, "same-wave shop preparation rerolled offers"):
		return

	var first_offer: Dictionary = wave_one_shop["offers"][0].duplicate(true)
	var forged_offer: Dictionary = first_offer.duplicate(true)
	forged_offer["_shop_transaction"] = int(first_offer["_shop_transaction"]) + 999
	if not _assert_true(not upgrades.purchase_shop_offer(forged_offer), "forged shop transaction was accepted"):
		return
	var internal_cost := int(first_offer["cost"])
	var coins_before_purchase: int = upgrades.coins
	var level_before_purchase: int = upgrades.level
	var count_before_purchase: int = int(upgrades.upgrade_counts.get(String(first_offer["id"]), 0))
	var tampered_offer: Dictionary = first_offer.duplicate(true)
	tampered_offer["cost"] = 1
	if not _assert_true(upgrades.purchase_shop_offer(tampered_offer), "valid shop offer was rejected"):
		return
	if not _assert_true(upgrades.coins == coins_before_purchase - internal_cost, "shop trusted a caller-tampered price"):
		return
	if not _assert_true(upgrades.level == level_before_purchase, "paid shop purchase advanced the free wave level"):
		return
	if not _assert_true(int(upgrades.upgrade_counts.get(String(first_offer["id"]), 0)) == count_before_purchase + 1, "shop purchase did not apply the upgrade effect exactly once"):
		return
	var sold_state: Dictionary = upgrades.get_shop_state()
	if not _assert_true(bool(sold_state["offers"][0]["sold"]), "purchased offer was not marked sold"):
		return
	var coins_after_purchase: int = upgrades.coins
	if not _assert_true(not upgrades.purchase_shop_offer(first_offer) and upgrades.coins == coins_after_purchase, "sold offer was purchased twice"):
		return

	if not _assert_true(upgrades.prepare_shop_for_wave(2), "new wave did not prepare fresh offers"):
		return
	var wave_two_shop: Dictionary = upgrades.get_shop_state()
	if not _assert_true(wave_two_shop["wave"] == 2 and wave_two_shop["offers"].size() == 3, "wave two shop state was invalid"):
		return
	for offer_value in wave_two_shop["offers"]:
		var offer: Dictionary = offer_value
		var catalog_entry: Dictionary = {}
		for candidate in upgrades.upgrade_pool:
			if String(candidate["id"]) == String(offer["id"]):
				catalog_entry = candidate
				break
		var expected_cost := maxi(1, roundi(float(catalog_entry["base_cost"]) * 1.18))
		if not _assert_true(int(offer["cost"]) == expected_cost, "wave-scaled shop cost was %d instead of %d" % [offer["cost"], expected_cost]):
			return
	if upgrades.coins > 0:
		upgrades.spend_coins(upgrades.coins)
	var unaffordable_offer: Dictionary = upgrades.get_shop_state()["offers"][0].duplicate(true)
	if not _assert_true(not bool(unaffordable_offer["affordable"]) and not upgrades.purchase_shop_offer(unaffordable_offer), "unaffordable offer changed progression"):
		return
	if not _assert_true(not shop_events.is_empty(), "shop changes were not published"):
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
