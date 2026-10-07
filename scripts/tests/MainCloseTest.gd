extends SceneTree

const MainScript = preload("res://scripts/Main.gd")
const TestSupport = preload("res://scripts/tests/TestSupport.gd")

class CloseFixture extends MainScript:
	signal release_drain
	var finish_count := 0
	var finish_code := -1
	var reload_count := 0
	var drain_calls := 0
	var hold_drain := false
	var fail_drain := false
	func _drain_audio_for_scene_exit() -> bool:
		drain_calls += 1
		var drained: bool = await super._drain_audio_for_scene_exit()
		if hold_drain:
			await release_drain
		return drained and not fail_drain
	func _reload_current_scene() -> void:
		reload_count += 1
	func _finish_close(exit_code: int) -> void:
		finish_count += 1
		finish_code = exit_code

var assertions := 0
var fixture: Node

func _check(condition: bool, message: String) -> bool:
	assertions += 1
	if condition:
		return true
	push_error("TEST FAIL: MainCloseTest: " + message)
	paused = false
	if is_instance_valid(fixture):
		TestSupport.stop_audio(fixture.audio)
		fixture.free()
	quit(1)
	return false

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	for state in ["title", "entrance", "playing", "paused", "result"]:
		fixture = CloseFixture.new()
		root.add_child(fixture)
		await process_frame
		if not _check(not auto_accept_quit, "window close bypasses application drain"):
			return
		if state != "title":
			fixture._start_run()
		if state in ["playing", "paused", "result"]:
			fixture.player.advance_entrance(fixture.player.get_entrance_duration() + 0.01)
			fixture.ui.wave_banner.finish_message()
		if state == "paused":
			fixture._toggle_manual_pause()
		if state == "result":
			fixture._end_run(false)
		var started_before: bool = fixture.run_started
		var state_before: int = fixture.run_state
		var elapsed_before: float = fixture.elapsed_seconds
		var wave_before: int = fixture.wave_director.wave_index if state != "title" else -1
		fixture.notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
		fixture.notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
		if not _check(fixture.closing and paused, state + ": close did not freeze the world"):
			return
		fixture._start_run()
		fixture._continue_run()
		fixture._begin_run({})
		fixture._restart_run()
		fixture._toggle_manual_pause()
		fixture._process(1.0)
		fixture._on_player_entrance_finished()
		fixture._on_wave_banner_finished(&"wave_intro")
		if state != "title" and not _check(fixture.wave_director.wave_index == wave_before and not fixture._save_stable_snapshot("wave_intro", 1), state + ": close accepted a late progression/save callback"):
			return
		if not _check(fixture.run_started == started_before and fixture.run_state == state_before and fixture.elapsed_seconds == elapsed_before, state + ": close accepted new gameplay work"):
			return
		var deadline := Time.get_ticks_msec() + 2500
		while fixture.finish_count == 0 and Time.get_ticks_msec() < deadline:
			await process_frame
		if not _check(fixture.finish_count == 1 and fixture.finish_code == 0 and fixture.audio.is_shutdown_complete(), state + ": close did not drain exactly once"):
			return
		fixture.notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
		if not _check(fixture.finish_count == 1, state + ": repeated close completed twice"):
			return
		paused = false
		fixture.free()
		fixture = null
		await process_frame
	# A controlled await makes restart/close ordering deterministic, not timing-based.
	for fails in [false, true]:
		fixture = CloseFixture.new()
		fixture.audio_enabled = false
		root.add_child(fixture)
		fixture.hold_drain = true
		fixture.fail_drain = fails
		fixture._restart_run()
		fixture._restart_run()
		if not _check(fixture.restarting and fixture.drain_calls == 1 and fixture.reload_count == 0, "restart was not single-flight"):
			return
		fixture._request_close()
		fixture._request_close()
		fixture.release_drain.emit()
		await process_frame
		if not _check(fixture.reload_count == 0 and fixture.finish_count == 1 and fixture.finish_code == (1 if fails else 0), "close did not take precedence over pending restart"):
			return
		paused = false
		fixture.free()
		fixture = null
	for fails in [false, true]:
		fixture = CloseFixture.new()
		fixture.audio_enabled = false
		root.add_child(fixture)
		fixture.fail_drain = fails
		fixture._restart_run()
		await process_frame
		if not _check(fixture.reload_count == (0 if fails else 1) and fixture.finish_count == (1 if fails else 0) and (not fails or fixture.finish_code == 1), "restart mishandled its drain result"):
			return
		paused = false
		fixture.free()
		fixture = null
	print("TEST PASS: MainCloseTest ", assertions)
	quit()
