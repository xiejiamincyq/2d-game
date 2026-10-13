extends "res://scripts/art/VerifyNurseryChapterFlow.gd"
## Real Main failure-cleanup path, not a victory fixture.
const Support = preload("res://scripts/tests/TestSupport.gd")
func _initialize() -> void: call_deferred("cleanup_checks")
func cleanup_checks() -> void:
	check(has_method("shutdown_failed_scene"),"failure cleanup lacks scene-aware shutdown")
	if failures: quit(1); return
	var main:=MainScene.instantiate()
	var owned:="user://chapter_failure_cleanup_%d.json"%OS.get_process_id()
	check(not FileAccess.file_exists(owned),"owned save must be absent")
	main.campaign_store_path=owned
	main.audio_enabled=false
	root.add_child(main)
	current_scene=main
	await process_frame
	check(main.has_method("_reset_combat_feedback") and main.combat_feedback==null,"formal Main menu should not create legacy combat feedback")
	call("shutdown_failed_scene",main)
	check(main.audio.shutting_down,"actual Main audio did not begin shutdown")
	check(not FileAccess.file_exists(owned),"cleanup wrote permanent progress")
	Support.stop_audio(main.audio)
	main.free()
	await process_frame
	if failures==0: print("TEST PASS: ChapterFailureCleanupTest %d"%assertions)
	quit(1 if failures else 0)
