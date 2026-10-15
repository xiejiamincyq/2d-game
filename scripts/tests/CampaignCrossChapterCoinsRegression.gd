extends SceneTree
## Controlled real-actor clears and UI transactions, NOT ordinary-input victory.
const Support = preload("TestSupport.gd")
const Store = preload("res://scripts/systems/CampaignProgressStore.gd")
const JourneyStore = preload("res://scripts/systems/CampaignJourneyStore.gd")
var assertions := 0
var failures := 0
var owned_path: String
var protected_hashes: Dictionary = {}

func check(ok: bool, message: String) -> void:
	assertions += 1
	if not ok:
		failures += 1
		push_error("TEST FAIL: CampaignCrossChapterCoinsRegression " + message)

func _initialize() -> void: call_deferred("_run")

func _hash(path: String) -> String:
	return FileAccess.get_sha256(path) if FileAccess.file_exists(path) else "MISSING"

func _collect_real_drops(chapter: Node) -> void:
	for pickup in chapter.pickups.get_children():
		if pickup is CoinPickup:
			pickup._physics_process(10.0)
	await process_frame

func _battle(chapter: Node) -> void:
	chapter.ui.proceed_button.pressed.emit()
	check(chapter.director.state == chapter.director.State.COMBAT and not paused, "UI must start actual combat")
	chapter.director.set_process(false)
	chapter.player.set_physics_process(false)
	for step in 120:
		chapter.director._process(0.25)
		if chapter.director.spawn_queue.is_empty() and chapter.director.active_portals.is_empty(): break
	var enemies: Array = chapter.director.get_active_enemies().duplicate()
	check(not enemies.is_empty(), "real encounter must spawn real actors")
	for enemy in enemies: enemy.take_damage(1e9, &"test")
	await process_frame
	await process_frame
	await _collect_real_drops(chapter)
	chapter.director._process(0)
	chapter.director._process(3.1)
	check(paused and chapter.ui.settlement_screen.visible, "real deaths must open actual reward UI")
	chapter.ui.settlement_screen.offer_buttons[0].pressed.emit()
	check(chapter.growth.get_settlement_state().reward_claimed, "actual reward transaction must succeed")
	chapter.ui.settlement_screen.close_button.pressed.emit()

func _wait_scene(script_suffix: String) -> Node:
	for frame in 600:
		if current_scene != null and current_scene.get_script().resource_path.ends_with(script_suffix): return current_scene
		await process_frame
	check(false, "scene transition timeout: " + script_suffix)
	return null

func _cleanup() -> void:
	paused = false
	if is_instance_valid(current_scene):
		Support.stop_audio(current_scene.audio)
		current_scene.free()
	await process_frame
	for suffix in ["", ".bak", ".tmp", ".journey", ".journey.bak", ".journey.tmp"]:
		if FileAccess.file_exists(owned_path + suffix):
			check(DirAccess.remove_absolute(owned_path + suffix) == OK, "owned fixture cleanup failed: " + suffix)
	for path in protected_hashes:
		check(_hash(path) == protected_hashes[path], "default player save changed: " + path)

func _run() -> void:
	for base in [Store.DEFAULT_PATH, JourneyStore.DEFAULT_PATH, "user://five_minute_overdrive_run_v1.json"]:
		for suffix in ["", ".bak", ".tmp"]: protected_hashes[base + suffix] = _hash(base + suffix)
	owned_path = "user://cross_chapter_coins_%d_%d.json" % [OS.get_process_id(), Time.get_ticks_usec()]
	for suffix in ["", ".bak", ".tmp", ".journey", ".journey.bak", ".journey.tmp"]:
		check(not FileAccess.file_exists(owned_path + suffix), "must not reuse existing fixture")
	if failures > 0:
		quit(1)
		return
	var chapter = load("res://scenes/campaign/nursery_chapter.tscn").instantiate()
	chapter.campaign_store_path = owned_path
	# Future coordinator integration may expose a distinct journal path.
	if "journey_store_path" in chapter: chapter.journey_store_path = owned_path + ".journey"
	chapter.audio_enabled = false
	chapter.run_seed = 521
	root.add_child(chapter)
	current_scene = chapter
	check(chapter.player != null and chapter.growth != null, "actual chapter assembled")
	for frame in 360:
		if not chapter.player.is_entrance_active(): break
		await process_frame
	await _battle(chapter)
	await _battle(chapter)
	chapter.ui.supply_button.pressed.emit()
	check(Support.claim_chapter_finale(chapter), "real finale reward transaction before Boss")
	chapter.ui.proceed_button.pressed.emit()
	var boss = chapter.director.get_active_boss()
	check(boss != null, "real Boss spawned")
	for frame in 360:
		if boss.entrance_resolved: break
		await process_frame
	check(boss.take_damage(1e9, &"test") and boss.health.current_health <= 0, "actual Boss health reaches zero")
	await process_frame
	await process_frame
	check(chapter.session.has_pending_clear() and chapter.ui.carry_selector.visible and not chapter.clear_saved, "actual Boss defeat must wait for one inherited ability")
	var chosen: Dictionary = chapter.ui.carry_selector.get_item_metadata(1)
	var selected_id: String = chosen.id
	check(chosen.kind != "evolution" and int(chapter.growth.upgrade_counts.get(selected_id, 0)) > 0, "UI inheritance must be a genuinely earned ordinary card")
	chapter.ui.carry_selector.select(1)
	chapter.ui.carry_selector.item_selected.emit(1)
	check(chapter.clear_saved and chapter.director.state == chapter.director.State.CLEARED, "real accepted clear and save")
	var balance: int = chapter.growth.coins
	check(balance > 0, "real drops and route must create nonzero balance")
	print("COIN TRANSITION: chapter 1 exit balance=%d" % balance)
	await chapter._leave(false)
	var tent = await _wait_scene("Main.gd")
	if tent != null:
		check(tent.campaign_progress.has_cleared(1), "actual tent reload retains real first clear")
		tent._start_primary_campaign()
		var next = await _wait_scene("FoundryChapter.gd")
		if next != null:
			check(next.growth != null, "actual next chapter growth assembled")
			print("COIN TRANSITION: chapter 2 entry balance=%d" % next.growth.coins)
			check(next.growth.coins == balance, "chapter 1 -> tent -> official chapter 2 entry must retain coins (%d != %d)" % [next.growth.coins, balance])
			check(next.growth.upgrade_counts == {selected_id: 1} and next.growth.acquired_evolution_id.is_empty(), "actual next chapter loses chosen ordinary ability or carries entire build/ultimate")
			check(next.player.health.max_health == 110 and next.player.shield == 20, "actual next chapter fixed HP/shield not applied")
	await _cleanup()
	if failures == 0: print("TEST PASS: CampaignCrossChapterCoinsRegression %d" % assertions)
	quit(1 if failures > 0 else 0)
