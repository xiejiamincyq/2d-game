extends SceneTree

const MainScript = preload("res://scripts/Main.gd")
const SnapshotStoreScript = preload("res://scripts/systems/RunSnapshotStore.gd")
const TestSupport = preload("res://scripts/tests/TestSupport.gd")

var assertions := 0

func _assert_true(condition: bool, message: String) -> bool:
	assertions += 1
	if condition:
		return true
	push_error("TEST FAIL: ContinueTest: " + message)
	paused = false
	quit(1)
	return false

func _initialize() -> void:
	var cleanup: Node = SnapshotStoreScript.new()
	cleanup.save_path = MainScript.HEADLESS_SNAPSHOT_PATH
	root.add_child(cleanup)
	cleanup.clear_snapshot()
	cleanup.queue_free()

	var first: Node = MainScript.new()
	first.audio_enabled = false
	root.add_child(first)
	await process_frame
	if not _assert_true(not first.ui.continue_button.visible, "continue entry was shown without a valid snapshot"):
		return
	first._start_run()
	await process_frame
	TestSupport.stop_audio(first.audio)
	first.upgrade_system.coins = 73
	first.upgrade_system.family_levels = {"ballistics": 3, "mobility": 2, "automation": 1}
	first.upgrade_system._apply_card("damage")
	first.wave_director.wave_index = 1
	first.wave_director.prepared_wave = false
	first.wave_director.wave_running = false
	first.wave_director.waiting_for_advance = true
	first.upgrade_system.prepare_settlement(2)
	var free_offer: Dictionary = first.upgrade_system.settlement_offers[0]
	first.upgrade_system.claim_free_offer(free_offer)
	first.kill_count = 141
	first.elapsed_seconds = 128.5
	first.player.global_position = Vector2(120.0, -80.0)
	first.player.health.current_health = 67.0
	first.player.shield = 19.0
	if not _assert_true(first._save_stable_snapshot("settlement", 3), "settlement boundary was not saved"):
		return
	TestSupport.stop_audio(first.audio)
	paused = false
	await process_frame
	first.free()
	await process_frame
	await process_frame

	var continued: Node = MainScript.new()
	continued.audio_enabled = false
	root.add_child(continued)
	await process_frame
	if not _assert_true(continued.ui.continue_button.visible and not continued.ui.continue_button.disabled, "valid snapshot did not expose Continue"):
		return
	continued._continue_run()
	await process_frame
	TestSupport.stop_audio(continued.audio)
	if not _assert_true(continued.run_state == continued.RunState.SETTLEMENT and paused, "Continue did not restore the stable settlement boundary"):
		return
	if not _assert_true(
		continued.wave_director.wave_index == 1
		and continued.wave_director.waiting_for_advance
		and continued.upgrade_system.coins == 73
		and continued.kill_count == 141
		and is_equal_approx(continued.elapsed_seconds, 128.5),
		"stage, progression, or run statistics were not restored"
	):
		return
	if not _assert_true(
		continued.player.global_position == Vector2(120.0, -80.0)
		and is_equal_approx(continued.player.health.current_health, 67.0)
		and is_equal_approx(continued.player.shield, 19.0),
		"player base state was not restored"
	):
		return
	if not _assert_true(
		continued.enemies.get_child_count() == 0
		and continued.projectiles.get_child_count() == 0
		and continued.portals.get_child_count() == 0
		and continued.pickups.get_child_count() == 0
		and continued.combat_vfx.get_total_effect_count() == 0
		and continued.player.get_node("PlayerCamera").offset == Vector2.ZERO
		and not continued.overdrive_active,
		"Continue restored forbidden runtime combat state"
	):
		return
	continued._on_settlement_close_requested()
	if not _assert_true(
		continued.run_state == continued.RunState.WAVE_INTRO
		and int(continued.snapshot_store.load_snapshot().get("pending_stage", 0)) == 3
		and String(continued.snapshot_store.load_snapshot().get("boundary", "")) == "wave_intro",
		"closing restored settlement did not save the next stage boundary"
	):
		return
	continued._end_run(false)
	if not _assert_true(not continued.snapshot_store.has_valid_snapshot(), "defeat did not clear the continuation snapshot"):
		return
	TestSupport.stop_audio(continued.audio)
	paused = false
	await process_frame
	continued.free()
	await process_frame

	var boss_prep: Node = MainScript.new()
	boss_prep.audio_enabled = false
	root.add_child(boss_prep)
	await process_frame
	boss_prep._start_run()
	await process_frame
	TestSupport.stop_audio(boss_prep.audio)
	boss_prep.wave_director.wave_index = boss_prep.wave_director.waves.size() - 1
	boss_prep.wave_director.prepared_wave = false
	boss_prep.wave_director.wave_running = false
	boss_prep.wave_director.waiting_for_advance = true
	boss_prep.wave_director.pre_boss_settlement_pending = true
	boss_prep.pending_wave_summary = {
		"wave": boss_prep.wave_director.waves.size(),
		"total": boss_prep.wave_director.waves.size(),
		"is_final": false,
		"is_pre_boss_settlement": true,
	}
	if not _assert_true(boss_prep.upgrade_system.prepare_settlement(6), "Boss-preparation settlement fixture could not be prepared"):
		return
	boss_prep._transition_to(boss_prep.RunState.PLAYING)
	boss_prep._transition_to(boss_prep.RunState.WAVE_CLEAR)
	boss_prep._transition_to(boss_prep.RunState.SETTLEMENT)
	var boss_offer: Dictionary = boss_prep.upgrade_system.settlement_offers[0]
	boss_prep._on_settlement_offer_selected(boss_offer)
	var saved_boss_boundary: Dictionary = boss_prep.snapshot_store.load_snapshot()
	if not _assert_true(
		String(saved_boss_boundary.get("boundary", "")) == "boss_settlement"
		and int(saved_boss_boundary.get("pending_stage", 0)) == 6
		and bool(saved_boss_boundary.get("settlement", {}).get("reward_claimed", false)),
		"claiming a Boss-preparation offer did not persist the dedicated stable boundary"
	):
		return
	paused = false
	boss_prep.free()
	await process_frame
	await process_frame

	var continued_boss: Node = MainScript.new()
	continued_boss.audio_enabled = false
	root.add_child(continued_boss)
	await process_frame
	continued_boss._continue_run()
	await process_frame
	TestSupport.stop_audio(continued_boss.audio)
	if not _assert_true(
		continued_boss.run_state == continued_boss.RunState.SETTLEMENT
		and continued_boss.wave_director.wave_index == 5
		and continued_boss.wave_director.is_pre_boss_settlement_pending(),
		"Continue did not restore the Boss-preparation settlement"
	):
		return
	continued_boss._on_settlement_close_requested()
	await process_frame
	if not _assert_true(
		continued_boss.run_state in [continued_boss.RunState.PLAYING, continued_boss.RunState.BOSS_INTRO]
		and continued_boss.wave_director.boss_entrance_started,
		"closing a restored Boss-preparation settlement did not begin the Boss entrance"
	):
		return
	continued_boss._end_run(false)
	TestSupport.stop_audio(continued_boss.audio)
	paused = false
	continued_boss.free()
	await process_frame

	var fresh: Node = MainScript.new()
	fresh.audio_enabled = false
	root.add_child(fresh)
	await process_frame
	fresh._start_run()
	TestSupport.stop_audio(fresh.audio)
	if not _assert_true(
		int(fresh.snapshot_store.load_snapshot().get("pending_stage", 0)) == 1
		and String(fresh.snapshot_store.load_snapshot().get("boundary", "")) == "wave_intro",
		"active New Game did not replace old progress with a clean stage-one boundary"
	):
		return
	TestSupport.stop_audio(fresh.audio)
	fresh.snapshot_store.clear_snapshot()
	paused = false
	await create_timer(0.25, true, false, true).timeout
	fresh.free()
	await process_frame
	await process_frame
	print("TEST PASS: ContinueTest %d" % assertions)
	quit(0)
