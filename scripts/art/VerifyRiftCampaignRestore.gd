extends SceneTree
## Fresh process reads an isolated ordinary-input sixth clear. No save writes.
const MainScene = preload("res://scenes/Main.tscn")
const Support = preload("res://scripts/tests/TestSupport.gd")
var failures := 0
var checks := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error("TEST FAIL: VerifyRiftCampaignRestore "+label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var args := OS.get_cmdline_user_args()
	check(args.size()==1 and args[0].is_valid_identifier(), "explicit evidence folder required")
	if failures: quit(1); return
	var folder := "res://build/diagnostics/campaign-goal/"+args[0]+"/"
	var path := folder+"campaign.json"
	var restore_path := folder+"restore-report.json"
	check(FileAccess.file_exists(path) and FileAccess.file_exists(folder+"report.json") and not FileAccess.file_exists(restore_path), "ordinary evidence save and fresh restore report required")
	if failures: quit(1); return
	var flow = JSON.parse_string(FileAccess.get_file_as_string(folder+"report.json"))
	check(flow is Dictionary and flow.get("valid")==true and flow.get("chapter")==6, "prior ordinary sixth flow did not pass")
	if failures: quit(1); return
	for source in flow.sources:
		check(FileAccess.get_sha256("res://"+source)==flow.sources[source], "ordinary proof source changed: "+source)
	if failures: quit(1); return
	var before := FileAccess.get_sha256(path)
	var main = MainScene.instantiate()
	main.audio_enabled = false; main.campaign_store_path = path
	root.add_child(main); current_scene = main; await process_frame
	for chapter in range(1,7):
		check(main.campaign_progress.has_cleared(chapter), "fresh Main lost chapter "+str(chapter))
		check(main._can_start_campaign_chapter(chapter), "cleared chapter replay unavailable")
	check(main.campaign_progress.is_campaign_complete() and not main.campaign_progress.is_unlocked(7) and not main._can_start_campaign_chapter(7), "terminal restore fabricates seventh gate")
	main.ui.start_screen.regions_button.pressed.emit()
	main.ui.start_screen.chapter_buttons[5].pressed.emit()
	check(not main.ui.start_screen.launch_button.disabled and main.ui.start_screen.chapter_buttons[5].text.contains("已通关"), "actual sixth replay menu unavailable")
	check(FileAccess.get_sha256(path)==before, "read-only Main restore rewrites evidence save")
	var file := FileAccess.open(restore_path, FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed":failures==0,"checks":checks,"process_id":OS.get_process_id(),"progress_sha256":before,"state":main.campaign_progress.to_state(),"ready_chapters":main.CAMPAIGN_READY_CHAPTERS,"restore_source_sha256":FileAccess.get_sha256("res://scripts/art/VerifyRiftCampaignRestore.gd"),"scope":"Fresh engine process/actual Main reads prior isolated ordinary-input sixth Boss clear. Existing progress read-only; fresh report only. Prerequisites1..5 were prepared fixtures, NOT a six-chapter ordinary chain or human/OS input acceptance."}, "\t"))
	file.close()
	Support.stop_audio(main.audio); main.free(); await process_frame
	if not failures: print("TEST PASS: VerifyRiftCampaignRestore %d"%checks)
	quit(1 if failures else 0)
