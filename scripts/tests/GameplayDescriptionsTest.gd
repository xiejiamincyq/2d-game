extends SceneTree
const Upgrades = preload("res://scripts/systems/UpgradeSystem.gd")
const Pause = preload("res://scripts/ui/PauseScreen.gd")
const Player = preload("res://scripts/actors/Player.gd")
var assertions := 0
var failures := 0
func check(ok: bool, label: String) -> void:
	assertions += 1
	if not ok:
		failures += 1
		push_error("TEST FAIL: GameplayDescriptionsTest " + label)
func _initialize() -> void:
	await process_frame
	var upgrades := Upgrades.new()
	root.add_child(upgrades)
	var descriptions := {}
	for card in upgrades.upgrade_pool:
		descriptions[card.id] = card.description
		check(not String(card.description).is_empty(), card.id + " empty description")
	check(descriptions.thunder_matrix.contains("间隔 +50%"), "matrix interval absent")
	check(descriptions.orbital_storm.contains("48%") and descriptions.orbital_storm.contains("30%"), "grenade inherited/base speeds stale")
	check(not descriptions.orbital_storm.contains("弹速 -60%"), "old grenade speed remains")
	check(descriptions.arc.contains("基础伤害 +16%"), "arc rank improvement vague")
	check(descriptions.health.contains("原上限 40%") and descriptions.health.contains("原缺失生命 20%"), "repair amount incomplete")
	check(descriptions.rift_overdrive.contains("不穿地形") and descriptions.rift_overdrive.contains("间距 -30%"), "assassin terrain or density explanation wrong")
	var player := Player.new()
	root.add_child(player)
	player.set_physics_process(false)
	upgrades.setup(player)
	player.health.max_health = 100.0
	player.health.current_health = 50.0
	upgrades._apply_upgrade_effect("health")
	check(player.health.max_health == 120.0 and player.health.current_health == 100.0, "real repair no longer matches described effect")
	var state := upgrades.get_snapshot_state()
	var old_offer: Dictionary = upgrades._find_catalog_entry("thunder_matrix").duplicate(true)
	old_offer["description"] = "旧版全屏电弧说明"
	old_offer["cost"] = 137
	old_offer["sold"] = true
	old_offer["transaction"] = 8
	state["settlement"]["offers"] = [old_offer]
	check(upgrades.restore_snapshot_state(state), "old card snapshot rejected")
	check(upgrades.settlement_offers[0].description == descriptions.thunder_matrix, "saved card retained outdated description")
	check(upgrades.settlement_offers[0].cost == 137 and upgrades.settlement_offers[0].sold and upgrades.settlement_offers[0].transaction == 8, "description migration changed transaction facts")
	var pause := Pause.new()
	root.add_child(pause)
	var labels := pause.find_children("*", "Label", true, false)
	var help := ""
	for label in labels:
		help += label.text
	check(help.contains("三倍") and help.contains("爪击") and help.contains("扑击"), "current combat help missing")
	for size in [Vector2(640, 360), Vector2(1280, 720)]:
		root.size = Vector2i(size)
		pause.apply_viewport_size(size)
		await process_frame
		await process_frame
		check(pause.get_required_size().x <= size.x and pause.get_required_size().y <= size.y, "pause help exceeds viewport %s" % size)
	pause.queue_free()
	upgrades.queue_free()
	player.queue_free()
	await process_frame
	if failures == 0:
		print("TEST PASS: GameplayDescriptionsTest %d" % assertions)
	quit(0 if failures == 0 else 1)
