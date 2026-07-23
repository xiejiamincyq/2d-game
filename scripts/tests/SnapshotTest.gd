extends SceneTree

const SnapshotStoreScript = preload("res://scripts/systems/RunSnapshotStore.gd")
const PlayerScript = preload("res://scripts/actors/Player.gd")
const UpgradeSystemScript = preload("res://scripts/systems/UpgradeSystem.gd")

var assertions := 0

func _assert_true(condition: bool, message: String) -> bool:
	assertions += 1
	if condition:
		return true
	push_error("TEST FAIL: SnapshotTest: " + message)
	quit(1)
	return false

func _valid_snapshot() -> Dictionary:
	return {
		"version": 1,
		"boundary": "settlement",
		"pending_stage": 3,
		"coins": 87,
		"family_levels": {"ballistics": 3, "mobility": 2, "automation": 1},
		"upgrade_counts": {"damage": 2, "mine": 1},
		"evolution": "",
		"settlement": {
			"wave": 2,
			"generation": 2,
			"offers": [
				{"id": "damage", "family": "ballistics", "cost": 49, "sold": true, "claimed": true, "purchased": false, "transaction": 2},
				{"id": "mine", "family": "mobility", "cost": 81, "sold": false, "claimed": false, "purchased": false, "transaction": 2},
			],
			"reward_claimed": true,
			"closed": false,
		},
		"player": {"position": [12.5, -42.0], "health": 84.0, "max_health": 120.0, "shield": 13.0, "max_shield": 60.0},
		"kills": 142,
		"elapsed_seconds": 126.5,
	}

func _initialize() -> void:
	var store: Node = SnapshotStoreScript.new()
	store.save_path = "user://phase5_snapshot_test.json"
	root.add_child(store)
	store.clear_snapshot()

	var snapshot := _valid_snapshot()
	if not _assert_true(store.save_snapshot(snapshot), "valid snapshot was not written"):
		return
	var loaded: Dictionary = store.load_snapshot()
	var family_state_matches := true
	for family_id in ["ballistics", "mobility", "automation"]:
		family_state_matches = family_state_matches and int(loaded.get("family_levels", {}).get(family_id, -1)) == int(snapshot["family_levels"][family_id])
	var upgrade_state_matches := true
	for card_id in snapshot["upgrade_counts"]:
		upgrade_state_matches = upgrade_state_matches and int(loaded.get("upgrade_counts", {}).get(card_id, -1)) == int(snapshot["upgrade_counts"][card_id])
	if not _assert_true(
		store.validate_snapshot(loaded)
		and int(loaded["coins"]) == int(snapshot["coins"])
		and int(loaded["pending_stage"]) == int(snapshot["pending_stage"])
		and family_state_matches
		and upgrade_state_matches,
		"valid snapshot did not preserve its progression state"
	):
		return
	var serialized := FileAccess.get_file_as_string(store.save_path)
	for runtime_key in ["enemies", "projectiles", "portals", "pickups", "vfx", "audio_loops", "camera_offset"]:
		if not _assert_true(serialized.find(runtime_key) == -1, "runtime-only key %s leaked into the snapshot" % runtime_key):
			return

	var invalid := snapshot.duplicate(true)
	invalid["coins"] = -1
	if not _assert_true(not store.save_snapshot(invalid) and int(store.load_snapshot().get("coins", -1)) == int(snapshot["coins"]), "invalid write replaced the last stable snapshot"):
		return

	var file := FileAccess.open(store.save_path, FileAccess.WRITE)
	file.store_string("{ definitely not json")
	file.close()
	if not _assert_true(store.load_snapshot().is_empty(), "corrupted JSON was accepted"):
		return

	var unknown := snapshot.duplicate(true)
	unknown["version"] = 999
	file = FileAccess.open(store.save_path, FileAccess.WRITE)
	file.store_string(JSON.stringify(unknown))
	file.close()
	if not _assert_true(store.load_snapshot().is_empty(), "unknown snapshot version was accepted"):
		return

	var forbidden := snapshot.duplicate(true)
	forbidden["enemies"] = [{"kind": "scrapper"}]
	if not _assert_true(not store.save_snapshot(forbidden), "runtime enemy state was accepted"):
		return

	var player_one: Node = PlayerScript.new()
	var upgrade_one: Node = UpgradeSystemScript.new()
	root.add_child(player_one)
	root.add_child(upgrade_one)
	await process_frame
	upgrade_one.setup(player_one)
	upgrade_one.coins = 73
	upgrade_one.family_levels = {"ballistics": 3, "mobility": 2, "automation": 1}
	upgrade_one._apply_card("damage")
	upgrade_one._apply_card("mine")
	upgrade_one.prepare_settlement(2)
	var progression_snapshot: Dictionary = upgrade_one.get_snapshot_state()
	var player_snapshot: Dictionary = player_one.get_snapshot_state()
	player_snapshot["health"] = 61.0
	player_snapshot["shield"] = 17.0

	var player_two: Node = PlayerScript.new()
	var upgrade_two: Node = UpgradeSystemScript.new()
	root.add_child(player_two)
	root.add_child(upgrade_two)
	await process_frame
	upgrade_two.setup(player_two)
	if not _assert_true(upgrade_two.restore_snapshot_state(progression_snapshot), "growth state could not be restored onto a fresh player"):
		return
	if not _assert_true(player_two.restore_snapshot_state(player_snapshot), "player base state could not be restored"):
		return
	if not _assert_true(
		upgrade_two.coins == 73
		and upgrade_two.upgrade_counts == upgrade_one.upgrade_counts
		and is_equal_approx(player_two.weapon_damage, player_one.weapon_damage)
		and player_two.mine_level == player_one.mine_level,
		"restored card effects did not reproduce the saved build"
	):
		return
	if not _assert_true(
		upgrade_two.settlement_offers == upgrade_one.settlement_offers
		and upgrade_two.settlement_generation == upgrade_one.settlement_generation,
		"stable settlement offers changed during restore"
	):
		return
	if not _assert_true(is_equal_approx(player_two.health.current_health, 61.0) and is_equal_approx(player_two.shield, 17.0), "health or shield was not restored after card effects"):
		return
	player_one.queue_free()
	player_two.queue_free()
	upgrade_one.queue_free()
	upgrade_two.queue_free()

	store.clear_snapshot()
	if not _assert_true(not FileAccess.file_exists(store.save_path) and not store.has_valid_snapshot(), "snapshot cleanup left a continue entry"):
		return
	store.queue_free()
	await process_frame
	print("TEST PASS: SnapshotTest %d" % assertions)
	quit(0)
