extends SceneTree
## Fresh-process, read-only Main restore of a prior actual chapter clear proof.
const Main = preload("res://scenes/Main.tscn")
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error("TEST FAIL: VerifyCampaignRestore " + message)
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	var path := ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--progress="):
			path = argument.trim_prefix("--progress=")
	check(path.begins_with("res://build/diagnostics/campaign-goal/") and not path.contains("..") and FileAccess.file_exists(path), "explicit existing isolated evidence path required")
	if failures > 0:
		quit(1)
		return
	var before := FileAccess.get_sha256(path)
	var main = Main.instantiate()
	main.audio_enabled = false
	main.campaign_store_path = path
	root.add_child(main)
	current_scene = main
	await process_frame
	check(main.campaign_progress.has_cleared(1) and main.campaign_progress.is_unlocked(2), "fresh Main lost saved first Boss unlock")
	main.ui.start_screen.select_chapter(2)
	check(main.ui.start_screen.chapter_buttons[1].text.contains("已解锁") and main.ui.start_screen.launch_button.disabled, "unlocked but unbuilt second chapter launched")
	main.ui.start_screen.select_chapter(1)
	check(not main.ui.start_screen.launch_button.disabled, "cleared first chapter cannot be replayed")
	check(FileAccess.get_sha256(path) == before, "read-only restore changed permanent data")
	var file := FileAccess.open(path.get_base_dir() + "/restore-report.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"valid": failures == 0, "process_id": OS.get_process_id(), "progress_file": path, "progress_sha256": before, "main_sha256": FileAccess.get_sha256("res://scripts/Main.gd"), "state": main.campaign_progress.to_state(), "scope": "Fresh engine process, actual read-only Main menu load; first clear/unlock/replay, unbuilt second remains unavailable"}, "\t"))
	file.close()
	if failures == 0:
		print("TEST PASS: VerifyCampaignRestore fresh Main progress/unlock/replay")
	main.audio.begin_shutdown()
	main.free()
	await process_frame
	quit(1 if failures > 0 else 0)
