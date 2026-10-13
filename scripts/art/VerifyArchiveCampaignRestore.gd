extends SceneTree
## Fresh process/read-only evidence progress, never the player's real save.
const MainScene = preload("res://scenes/Main.tscn")
const Support = preload("res://scripts/tests/TestSupport.gd")
var failures := 0
var checks := 0
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error("TEST FAIL: VerifyArchiveCampaignRestore "+label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var args := OS.get_cmdline_user_args()
	check(args.size()==1 and args[0].is_valid_identifier(),"explicit evidence folder required")
	if failures: quit(1); return
	var folder := "res://build/diagnostics/campaign-goal/"+args[0]+"/"
	var path := folder+"campaign.json"; var report_path := folder+"restore-report.json"
	check(FileAccess.file_exists(path) and not FileAccess.file_exists(report_path),"existing evidence save and fresh report required")
	if failures: quit(1); return
	var before := FileAccess.get_sha256(path)
	var main = MainScene.instantiate(); main.audio_enabled = false; main.campaign_store_path = path
	root.add_child(main); current_scene = main; await process_frame
	check(main.campaign_progress.has_cleared(1) and main.campaign_progress.has_cleared(2) and main.campaign_progress.has_cleared(3) and main.campaign_progress.has_cleared(4) and main.campaign_progress.is_unlocked(5),"fresh Main loses real fourth clear/unlock5")
	main.ui.start_screen.regions_button.pressed.emit(); main.ui.start_screen.chapter_buttons[3].pressed.emit()
	check(main._can_start_campaign_chapter(4) and not main.ui.start_screen.launch_button.disabled and main.ui.start_screen.chapter_buttons[3].text.contains("已通关"),"fourth replay unavailable")
	main.ui.start_screen.chapter_buttons[4].pressed.emit()
	check(not main._can_start_campaign_chapter(5) and main.ui.start_screen.launch_button.disabled and main.ui.start_screen.chapter_buttons[4].text.contains("已解锁") and main.ui.start_screen.launch_button.text.contains("制作中"),"unbuilt fifth gate wrong")
	check(not main.campaign_progress.is_unlocked(6) and not main._can_start_campaign_chapter(6),"restore skips sequence")
	check(FileAccess.get_sha256(path)==before,"restore rewrites existing evidence save")
	var file := FileAccess.open(report_path,FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed":failures==0,"checks":checks,"process_id":OS.get_process_id(),"progress_sha256":before,"state":main.campaign_progress.to_state(),"ready_chapters":main.CAMPAIGN_READY_CHAPTERS,"scope":"Fresh engine process/actual Main reads prior isolated real-input chapter-four clear. Evidence progress read-only, fresh diagnostic report only. Not another natural run, OS input or human playtest."},"\t")); file.close()
	Support.stop_audio(main.audio); main.free(); await process_frame
	if not failures: print("TEST PASS: VerifyArchiveCampaignRestore %d"%checks)
	quit(1 if failures else 0)
