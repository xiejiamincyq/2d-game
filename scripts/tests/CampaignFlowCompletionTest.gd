extends "res://scripts/art/VerifyNurseryChapterFlow.gd"
## Pure proof-contract guard. Progress fixtures are NOT actual chapter victories.
var requested_chapter := 1
func chapter_number() -> int: return requested_chapter
func check(ok: bool,label: String) -> void:
	assertions += 1
	if not ok: failures += 1; push_error("TEST FAIL: CampaignFlowCompletionTest "+label)
func _initialize() -> void: call_deferred("completion_checks")
func completion_checks() -> void:
	check(has_method("has_expected_saved_clear"),"ordinary proof has no terminal-chapter completion rule")
	if failures: quit(1); return
	for number in range(1,7):
		requested_chapter = number
		var progress := Progress.new()
		check(not call("has_expected_saved_clear",progress),"empty progress proves victory")
		for predecessor in range(1,number): check(progress.record_boss_defeat(predecessor),"sequential unit fixture")
		check(not call("has_expected_saved_clear",progress),"predecessors alone prove current victory")
		check(progress.record_boss_defeat(number) and call("has_expected_saved_clear",progress),"actual saved chapter boundary rejected: "+str(number))
		if number==6: check(progress.is_campaign_complete() and not progress.is_unlocked(7),"terminal fixture invents seventh")
	for invalid in [0,7]:
		requested_chapter = invalid
		var complete := Progress.new()
		for number in range(1,7): complete.record_boss_defeat(number)
		check(not call("has_expected_saved_clear",complete),"invalid chapter proves completion")
	if not failures: print("TEST PASS: CampaignFlowCompletionTest %d"%assertions)
	quit(1 if failures else 0)
