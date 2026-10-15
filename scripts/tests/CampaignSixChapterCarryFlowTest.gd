extends SceneTree
## Six real chapter/UI/journal flows. Controlled damage and legacy prerequisites
## are migration/test fixtures, never evidence of ordinary-input campaign wins.
const Support = preload("TestSupport.gd")
const Registry = preload("res://scripts/campaign/ChapterSceneRegistry.gd")
const Store = preload("res://scripts/systems/CampaignProgressStore.gd")
const Progress = preload("res://scripts/systems/CampaignProgress.gd")
const Session = preload("res://scripts/systems/CampaignSession.gd")
const Journal = preload("res://scripts/systems/CampaignJourneyStore.gd")
var assertions := 0
var failures := 0
var owned_path := ""
var protected_hashes: Dictionary = {}
var case_active := false
var case_token := 0

func check(ok: bool, message: String) -> void:
	assertions += 1
	if not ok:
		failures += 1
		push_error("TEST FAIL: CampaignSixChapterCarryFlowTest " + message)

func _initialize() -> void: call_deferred("_run")
func _hash(path: String) -> String: return FileAccess.get_sha256(path) if FileAccess.file_exists(path) else "MISSING"

func _dispose_scene() -> void:
	paused = false
	if is_instance_valid(current_scene):
		Support.stop_audio(current_scene.audio)
		current_scene.free()
	await process_frame

func _cleanup() -> void:
	await _dispose_scene()
	for suffix in ["", ".bak", ".tmp", ".journey", ".journey.bak", ".journey.tmp"]:
		if FileAccess.file_exists(owned_path + suffix):
			check(DirAccess.remove_absolute(owned_path + suffix) == OK, "owned fixture cleanup failed")
	for path in protected_hashes: check(_hash(path) == protected_hashes[path], "default player save changed: " + path)

func _watchdog(token: int, number: int) -> void:
	if case_active and token == case_token:
		case_active = false
		check(false, "chapter %d actual flow exceeded 30-second watchdog" % number)
		await _cleanup()
		quit(1)

func _wait_scene(number: int) -> Node:
	for frame in 600:
		if current_scene != null and current_scene.has_method("_chapter_number") and current_scene._chapter_number() == number: return current_scene
		await process_frame
	check(false, "actual scene transition timeout for chapter %d" % number)
	return null

func _collect(chapter: Node) -> void:
	for pickup in chapter.pickups.get_children():
		if pickup is CoinPickup: pickup._physics_process(10.0)
	await process_frame

func _battle(chapter: Node) -> void:
	chapter.ui.proceed_button.pressed.emit()
	check(chapter.director.state == chapter.director.State.COMBAT and not paused, "actual UI combat start")
	chapter.director.set_process(false)
	chapter.player.set_physics_process(false)
	for step in 120:
		chapter.director._process(0.25)
		if chapter.director.spawn_queue.is_empty() and chapter.director.active_portals.is_empty(): break
	check(not chapter.director.get_active_enemies().is_empty(), "actual encounter actors spawned")
	# Bounded real deaths include archive fragments born via deferred ownership.
	for generation in 8:
		for enemy in chapter.director.get_active_enemies().duplicate():
			enemy.set_physics_process(false)
			enemy.take_damage(1e9, &"test")
		await process_frame
		await process_frame
		await physics_frame
		if chapter.director.get_active_enemies().is_empty(): break
	await _collect(chapter)
	chapter.director._process(0)
	chapter.director._process(3.1)
	check(paused and chapter.ui.settlement_screen.visible, "real death resolution opens rewards")
	for button in chapter.ui.settlement_screen.offer_buttons:
		if button.is_visible_in_tree() and not button.disabled:
			button.pressed.emit()
			break
	check(chapter.growth.get_settlement_state().reward_claimed, "actual reward transaction succeeds")
	chapter.ui.settlement_screen.close_button.pressed.emit()

func _clear(chapter: Node) -> void:
	for frame in 360:
		if not chapter.player.is_entrance_active(): break
		await process_frame
	await _battle(chapter)
	await _battle(chapter)
	chapter.ui.supply_button.pressed.emit()
	check(Support.claim_chapter_finale(chapter), "actual finale reward before Boss")
	chapter.ui.proceed_button.pressed.emit()
	var boss = chapter.director.get_active_boss()
	check(boss != null, "actual regional Boss spawned")
	for frame in 360:
		if boss.entrance_resolved: break
		await process_frame
	check(boss.take_damage(1e9, &"test") and boss.health.current_health <= 0, "actual Boss health reaches zero")
	await process_frame
	await process_frame
	check(chapter.director.state == chapter.director.State.CLEARED, "Director accepts real Boss defeat")

func _case(number: int) -> void:
	case_active = true
	case_token += 1
	create_timer(30, true, false, true).timeout.connect(_watchdog.bind(case_token, number))
	owned_path = "user://six_carry_%d_%d_c%d.json" % [OS.get_process_id(), Time.get_ticks_usec(), number]
	check(not FileAccess.file_exists(owned_path) and not FileAccess.file_exists(owned_path + ".journey"), "unique isolated fixture")
	var legacy := Progress.new()
	for previous in range(1, number): check(legacy.record_boss_defeat(previous), "controlled legacy prerequisite migration")
	check(Store.new(owned_path).save_progress(legacy), "owned legacy migration fixture saved")
	var old_sha := _hash(owned_path)
	var chapter = Registry.instantiate_chapter(number)
	chapter.campaign_store_path = owned_path
	chapter.audio_enabled = false
	chapter.run_seed = 521
	root.add_child(chapter)
	current_scene = chapter
	check(chapter.run_loop == 1 and chapter.growth.coins == 0, "migrated first-loop chapter starts with zero owned coins")
	check(chapter.player.health.max_health == 90 + number * 10 and chapter.player.shield == 20, "shared fixed chapter HP and shield")
	await _clear(chapter)
	check(chapter.session.has_pending_clear() and not chapter.clear_saved, "real defeat persists pending selection")
	check(chapter.ui.carry_selector.visible and chapter.ui.replay_button.disabled and chapter.ui.return_button.disabled, "pending choice cannot bypass reward")
	var card: Dictionary = chapter.ui.carry_selector.get_item_metadata(1)
	var selected: String = card.id
	check(card.kind != "evolution" and chapter.growth.upgrade_counts.get(selected, 0) > 0, "choice is genuinely earned ordinary ability")
	chapter.ui.carry_selector.select(1)
	chapter.ui.carry_selector.item_selected.emit(1)
	var balance: int = chapter.growth.coins
	check(balance > 0 and chapter.clear_saved, "actual choice finalizes nonzero balance")
	var fresh := Session.new(owned_path)
	check(fresh.load() and fresh.journey.get_build() == {"coins": balance, "inherited_counts": {selected: 1}}, "fresh journal retains exact single ability and coins")
	check(_hash(owned_path) == old_sha, "read-only legacy fixture not rewritten")
	check(chapter.ui.next_button.visible == (number < 6) and chapter.ui.replay_button.visible and chapter.ui.return_button.visible, "all-six clear button policy")
	if number < 6:
		chapter.ui.next_button.pressed.emit()
		var next = await _wait_scene(number + 1)
		if next != null:
			check(next.run_loop == 1 and next.growth.coins == balance and next.growth.upgrade_counts == {selected: 1} and next.growth.acquired_evolution_id.is_empty(), "actual next button preserves only selected ordinary ability and coins")
			check(next.player.health.max_health == 100 + number * 10 and next.player.shield == 20, "next actual chapter base stats are not stacked")
	else:
		chapter.ui.replay_button.pressed.emit()
		await process_frame
		await process_frame
		var replay = await _wait_scene(6)
		check(replay != chapter and replay.run_loop == 1 and replay.growth.coins == balance, "sixth replay stays Loop1 Chapter6 with coins")
		await _clear(replay)
		check(replay.clear_saved and not replay.session.has_pending_clear() and not replay.ui.carry_selector.visible, "actual replay clear grants no second selection")
		check(replay.session.journey.get_build().inherited_counts == {selected: 1} and replay.session.journey.get_entry() == {"loop": 2, "chapter": 1}, "replay does not stack ability or advance checkpoint twice")
		var replay_balance: int = replay.growth.coins
		replay.ui.return_button.pressed.emit()
		for frame in 600:
			if current_scene.get_script().resource_path.ends_with("Main.gd"): break
			await process_frame
		check(current_scene.get_script().resource_path.ends_with("Main.gd"), "sixth returns actual tent")
		current_scene.ui.start_requested.emit()
		var loop_two = await _wait_scene(1)
		if loop_two != null:
			check(loop_two.run_loop == 2 and loop_two.growth.coins == replay_balance and loop_two.growth.upgrade_counts == {selected: 1}, "tent Continue enters Loop2 Chapter1 with replay coins and single inherited ability")
			check(loop_two.player.health.max_health == 100 and loop_two.player.shield == 20, "Loop2 entry does not repeatedly stack base stats")
	case_active = false
	await _cleanup()
	print("SIX CHAPTER CARRY: case %d complete, assertions=%d failures=%d" % [number, assertions, failures])

func _run() -> void:
	for base in [Store.DEFAULT_PATH, Journal.DEFAULT_PATH, "user://five_minute_overdrive_run_v1.json"]:
		for suffix in ["", ".bak", ".tmp"]: protected_hashes[base + suffix] = _hash(base + suffix)
	for number in range(1, 7): await _case(number)
	if failures == 0: print("TEST PASS: CampaignSixChapterCarryFlowTest %d" % assertions)
	quit(1 if failures > 0 else 0)
