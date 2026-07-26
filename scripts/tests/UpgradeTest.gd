extends SceneTree

const PlayerScript = preload("res://scripts/actors/Player.gd")
const UpgradeSystemScript = preload("res://scripts/systems/UpgradeSystem.gd")
const FloorGridScript = preload("res://scripts/world/FloorGrid.gd")

const FAMILY_IDS: Array[String] = ["ballistics", "mobility", "automation"]

var assertions := 0

func _assert_true(condition: bool, message: String) -> bool:
	assertions += 1
	if condition:
		return true
	push_error("TEST FAIL: UpgradeTest: " + message)
	paused = false
	quit(1)
	return false

func _find_catalog_entry(upgrades: Node, card_id: String) -> Dictionary:
	for entry_value in upgrades.upgrade_pool:
		var entry: Dictionary = entry_value
		if String(entry.get("id", "")) == card_id:
			return entry
	return {}

func _flatten_offers(state: Dictionary) -> Array[Dictionary]:
	var flattened: Array[Dictionary] = []
	for family_value in state.get("families", []):
		var family: Dictionary = family_value
		for offer_value in family.get("offers", []):
			flattened.append(offer_value)
	return flattened

func _initialize() -> void:
	var player: Node = PlayerScript.new()
	root.add_child(player)
	var upgrades: Node = UpgradeSystemScript.new()
	upgrades.process_mode = Node.PROCESS_MODE_ALWAYS
	root.add_child(upgrades)
	await process_frame
	player.set_physics_process(false)
	upgrades.setup(player)

	for locked_card_id in ["move_speed", "spike_density", "spike_resonance", "drone_damage", "arc_capacitor", "arc_relay", "rift_overdrive", "thunder_matrix"]:
		if not _assert_true(not upgrades._is_card_unlocked(_find_catalog_entry(upgrades, locked_card_id)), "%s appeared before its starter card was acquired" % locked_card_id):
			return
	var drone_count_before: int = player.drone_count
	upgrades._apply_card("mine")
	upgrades._apply_card("drone")
	upgrades._apply_card("arc")
	if not _assert_true(player.drone_count == drone_count_before + 1, "one drone card did not add exactly one drone"):
		return
	for unlocked_card_id in ["move_speed", "spike_density", "spike_resonance", "drone_damage", "arc_capacitor", "arc_relay", "rift_overdrive", "thunder_matrix"]:
		if not _assert_true(upgrades._is_card_unlocked(_find_catalog_entry(upgrades, unlocked_card_id)), "%s remained locked after all required starter cards were acquired" % unlocked_card_id):
			return

	var normal_counts := {"ballistics": 0, "mobility": 0, "automation": 0}
	for card_value in upgrades.upgrade_pool:
		var card: Dictionary = card_value
		if String(card.get("kind", "")) != "evolution":
			normal_counts[String(card.get("family", ""))] = int(normal_counts.get(String(card.get("family", "")), 0)) + 1
	if not _assert_true(normal_counts == {"ballistics": 6, "mobility": 6, "automation": 6}, "catalog did not contain six balanced cards per family: %s" % [normal_counts]):
		return
	if not _assert_true(_find_catalog_entry(upgrades, "recovery_route").is_empty() and _find_catalog_entry(upgrades, "pickup").is_empty(), "pickup-range cards remained in the catalog"):
		return
	if not _assert_true(not _find_catalog_entry(upgrades, "spike_resonance").is_empty() and not _find_catalog_entry(upgrades, "arc_relay").is_empty(), "signature spike/arc mechanic cards did not replace pickup-range cards"):
		return
	var pickup_radius_before: float = player.pickup_radius
	var spike_radius_before: float = player.spike_radius
	var spike_interval_before: float = player.spike_tick_interval
	upgrades._apply_card("spike_resonance")
	if not _assert_true(player.pickup_radius == pickup_radius_before and player.spike_radius > spike_radius_before and player.spike_tick_interval < spike_interval_before, "spike resonance did not strengthen radius/frequency without pickup range"):
		return
	var arc_interval_before: float = player.arc_base_interval
	upgrades._apply_card("arc_relay")
	if not _assert_true(player.pickup_radius == pickup_radius_before and player.arc_base_interval < arc_interval_before, "arc relay did not strengthen pulse frequency without pickup range"):
		return
	var floor: Node2D = FloorGridScript.new()
	root.add_child(floor)
	var trap: Node = player.SpikeTrapScript.new()
	root.add_child(trap)
	await process_frame
	if not _assert_true(floor.z_index < trap.z_index and trap.z_index < 0, "render order was not floor < spike < enemy"):
		return
	trap.queue_free()
	floor.queue_free()
	if not _assert_true(upgrades.family_levels == {"ballistics": 1, "mobility": 1, "automation": 1}, "family levels did not start at one"):
		return

	var progression_events: Array[Dictionary] = []
	upgrades.progression_state_changed.connect(func(state: Dictionary) -> void: progression_events.append(state.duplicate(true)))
	if not _assert_true(upgrades.add_coins(1000), "test coins were not added"):
		return
	if not _assert_true(progression_events[-1] == {"coins": 1000, "family_levels": {"ballistics": 1, "mobility": 1, "automation": 1}}, "progression state shape was unstable"):
		return

	if not _assert_true(upgrades.prepare_settlement(1), "first settlement was not prepared"):
		return
	var first_state: Dictionary = upgrades.get_settlement_state()
	if not _assert_true(first_state["wave"] == 1 and first_state["families"].size() == 3, "first settlement shape was invalid"):
		return
	var first_offers := _flatten_offers(first_state)
	if not _assert_true(first_offers.size() == 6, "settlement did not expose six offers"):
		return
	var seen_ids: Dictionary = {}
	for family_index in range(FAMILY_IDS.size()):
		var family: Dictionary = first_state["families"][family_index]
		if not _assert_true(String(family["id"]) == FAMILY_IDS[family_index] and family["offers"].size() == 2, "family %s did not expose exactly two cards" % FAMILY_IDS[family_index]):
			return
		for offer_value in family["offers"]:
			var offer: Dictionary = offer_value
			var offer_id := String(offer["id"])
			if not _assert_true(String(offer["family"]) == FAMILY_IDS[family_index] and not seen_ids.has(offer_id), "offer was duplicated or assigned to the wrong family"):
				return
			seen_ids[offer_id] = true
			var catalog_entry := _find_catalog_entry(upgrades, offer_id)
			if not _assert_true(int(offer["cost"]) == int(catalog_entry["base_cost"]), "wave one cost did not equal the catalog base cost"):
				return
	var stable_first := first_state.duplicate(true)
	if not _assert_true(not upgrades.prepare_settlement(1) and upgrades.get_settlement_state() == stable_first, "same-wave settlement rerolled its snapshot"):
		return
	if not _assert_true(not upgrades.prepare_settlement(2), "an open settlement was invalidated by a newer wave"):
		return

	var free_offer: Dictionary = first_offers[0].duplicate(true)
	var paid_offer: Dictionary = first_offers[1].duplicate(true)
	if not _assert_true(not upgrades.purchase_settlement_offer(paid_offer), "paid purchase was accepted before the free reward"):
		return
	if not _assert_true(not upgrades.complete_settlement({"transaction": first_state["transaction"]}), "settlement closed before the free reward"):
		return
	var forged_free := free_offer.duplicate(true)
	forged_free["transaction"] = int(first_state["transaction"]) + 99
	if not _assert_true(not upgrades.claim_free_offer(forged_free), "forged free transaction was accepted"):
		return
	var free_family := String(free_offer["family"])
	var levels_before_free: Dictionary = upgrades.family_levels.duplicate(true)
	var coins_before_free: int = upgrades.coins
	if not _assert_true(upgrades.claim_free_offer(free_offer), "valid free reward was rejected"):
		return
	if not _assert_true(upgrades.coins == coins_before_free and int(upgrades.family_levels[free_family]) == int(levels_before_free[free_family]) + 1, "free reward changed coins or failed to raise its family"):
		return
	for family_id in FAMILY_IDS:
		if family_id != free_family and not _assert_true(upgrades.family_levels[family_id] == levels_before_free[family_id], "free reward raised an unrelated family"):
			return
	if not _assert_true(int(upgrades.upgrade_counts.get(String(free_offer["id"]), 0)) == 1, "free reward did not raise card rank exactly once"):
		return
	if not _assert_true(not upgrades.claim_free_offer(free_offer), "free reward transaction was consumed twice"):
		return
	var after_free: Dictionary = upgrades.get_settlement_state()
	if not _assert_true(bool(after_free["reward_claimed"]) and bool(after_free["can_close"]), "free reward did not unlock purchases and close"):
		return

	var paid_levels_before: Dictionary = upgrades.family_levels.duplicate(true)
	var paid_cost := int(paid_offer["cost"])
	var tampered_paid := paid_offer.duplicate(true)
	tampered_paid["cost"] = 1
	if not _assert_true(upgrades.purchase_settlement_offer(tampered_paid), "valid paid offer was rejected"):
		return
	if not _assert_true(upgrades.coins == coins_before_free - paid_cost, "paid purchase trusted the caller's price"):
		return
	if not _assert_true(upgrades.family_levels == paid_levels_before, "paid purchase raised a family level"):
		return
	if not _assert_true(int(upgrades.upgrade_counts.get(String(paid_offer["id"]), 0)) == 1, "paid purchase did not raise its card rank"):
		return
	var coins_after_paid: int = upgrades.coins
	if not _assert_true(not upgrades.purchase_settlement_offer(paid_offer) and upgrades.coins == coins_after_paid, "paid offer was purchased twice"):
		return
	if not _assert_true(not upgrades.complete_settlement({"transaction": int(first_state["transaction"]) + 1}), "forged close transaction was accepted"):
		return
	if not _assert_true(upgrades.complete_settlement({"transaction": first_state["transaction"]}), "valid settlement close was rejected"):
		return
	if not _assert_true(not upgrades.complete_settlement({"transaction": first_state["transaction"]}), "settlement close transaction was consumed twice"):
		return

	if not _assert_true(upgrades.prepare_settlement(2), "second settlement was not prepared after close"):
		return
	var second_state: Dictionary = upgrades.get_settlement_state()
	for offer in _flatten_offers(second_state):
		var entry := _find_catalog_entry(upgrades, String(offer["id"]))
		var expected_cost := maxi(1, roundi(float(entry["base_cost"]) * 1.55))
		if not _assert_true(int(offer["cost"]) == expected_cost, "wave two price did not use the 1 + 0.55 * (wave - 1) contract"):
			return
	if not _assert_true(not upgrades.claim_free_offer(free_offer), "stale offer from the previous settlement was accepted"):
		return
	var second_free: Dictionary = _flatten_offers(second_state)[0]
	if not _assert_true(upgrades.claim_free_offer(second_free), "second free reward was rejected"):
		return
	if not _assert_true(upgrades.complete_settlement({"transaction": second_state["transaction"]}), "second settlement did not close"):
		return

	upgrades.family_levels["ballistics"] = 5
	upgrades.family_levels["mobility"] = 5
	if not _assert_true(upgrades.prepare_settlement(4), "evolution-eligible settlement was not prepared"):
		return
	var evolution_state: Dictionary = upgrades.get_settlement_state()
	var evolution_offers: Array[Dictionary] = []
	for offer in _flatten_offers(evolution_state):
		if String(offer.get("kind", "")) == "evolution":
			evolution_offers.append(offer)
	if not _assert_true(evolution_offers.size() == 1, "more than one eligible evolution entered a settlement: %s" % [evolution_offers]):
		return
	if not _assert_true(upgrades.claim_free_offer(evolution_offers[0]), "eligible evolution reward was rejected"):
		return
	if not _assert_true(not String(upgrades.acquired_evolution_id).is_empty(), "evolution acquisition was not recorded"):
		return
	if not _assert_true(upgrades.complete_settlement({"transaction": evolution_state["transaction"]}), "evolution settlement did not close"):
		return
	if not _assert_true(upgrades.prepare_settlement(5), "post-evolution settlement was not prepared"):
		return
	var later_evolutions := 0
	for offer in _flatten_offers(upgrades.get_settlement_state()):
		if String(offer.get("kind", "")) == "evolution":
			later_evolutions += 1
	if not _assert_true(later_evolutions == 0, "a second evolution entered the run after one was acquired"):
		return

	for forbidden_method in ["prepare_shop_for_wave", "purchase_shop_offer", "queue_wave_upgrade", "apply_upgrade"]:
		if not _assert_true(not upgrades.has_method(forbidden_method), "legacy progression bypass remained callable: %s" % forbidden_method):
			return
	if not _assert_true(
		not upgrades.has_signal("choices_ready") and not upgrades.has_signal("shop_changed"),
		"legacy progression signals still exposed a second upgrade or purchase path"
	):
		return

	upgrades.queue_free()
	player.queue_free()
	await process_frame
	print("TEST PASS: UpgradeTest %d" % assertions)
	quit(0)
