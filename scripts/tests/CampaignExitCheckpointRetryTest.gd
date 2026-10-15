extends SceneTree
## Independent review reproduction. Real scene/coin/UI, not a victory fixture.
const Support = preload("res://scripts/tests/TestSupport.gd")
var checks := 0
var failures := 0
func check(ok: bool,message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("TEST FAIL: CampaignExitCheckpointRetryTest "+message)
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	var path := "user://exit_retry_%d.json"%OS.get_process_id()
	check(not FileAccess.file_exists(path+".journey"),"unique isolated path")
	var chapter = load("res://scenes/campaign/nursery_chapter.tscn").instantiate()
	chapter.campaign_store_path = path
	chapter.audio_enabled = false
	root.add_child(chapter)
	current_scene = chapter
	chapter.spawn_coins(chapter.player.position,37)
	check(chapter.pickups.get_child_count()==1,"real coin fixture")
	chapter.pickups.get_child(0)._try_collect()
	await process_frame
	check(chapter.growth.coins==37 and not chapter.clear_saved,"actual uncompleted run balance")
	check(DirAccess.make_dir_absolute(path+".journey.tmp")==OK,"owned empty write blocker")
	chapter.ui.return_button.pressed.emit()
	check(not chapter.leaving and chapter.ui.retry_save_button.visible,"failed Back must remain retryable")
	check(not chapter.ui.retry_save_button.text.contains("通关"),"ordinary checkpoint falsely labelled clear")
	check(DirAccess.remove_absolute(path+".journey.tmp")==OK,"owned empty blocker cleanup")
	chapter.ui.retry_save_button.pressed.emit()
	await process_frame
	await process_frame
	var restored = current_scene
	check(restored!=chapter and restored.get_script().resource_path=="res://scripts/Main.gd","retry does not complete original Back")
	if restored!=chapter:
		check(restored.campaign_session.journey.get_build().coins==37,"retry loses actual coins")
		check(restored.campaign_session.journey.to_state().cleared_stage==0,"retry invents Boss clear")
	paused = false
	Support.stop_audio(restored.audio)
	restored.free()
	await process_frame
	check(Support.cleanup_journey_fixture(path),"owned journal cleanup")
	if not failures: print("TEST PASS: CampaignExitCheckpointRetryTest %d"%checks)
	quit(1 if failures else 0)
