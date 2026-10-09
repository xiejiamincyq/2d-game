extends SceneTree

var assertions := 0
var failures := 0

func check(ok: bool, message: String) -> void:
	assertions += 1
	if not ok:
		failures += 1
		push_error("TEST FAIL: CampaignProgressTest " + message)

func _initialize() -> void:
	var path := "res://scripts/systems/CampaignProgress.gd"
	check(FileAccess.file_exists(path), "sequential boss unlock model is not implemented")
	if failures > 0:
		quit(1)
		return
	var progress_script = load(path)
	var progress = progress_script.new()
	check(progress.get_highest_unlocked_chapter() == 1, "new campaign must start at chapter one")
	check(not progress.is_campaign_complete(), "new campaign is already complete")
	for chapter in range(1, 7):
		check(progress.is_unlocked(chapter) == (chapter == 1), "new campaign unlocked incorrect chapter")
		check(not progress.has_cleared(chapter), "new campaign marks a boss defeated")
	for invalid in [-1, 0, 7, 100]:
		check(not progress.is_unlocked(invalid), "invalid chapter can be entered")
		check(not progress.record_boss_defeat(invalid), "invalid boss unlock accepted")
		check(not progress.has_cleared(invalid), "invalid chapter is marked cleared")
	check(not progress.record_boss_defeat(2), "locked boss signal skipped chapter one")
	for chapter in range(1, 7):
		var before: Dictionary = progress.to_state()
		if chapter < 6:
			check(not progress.record_boss_defeat(chapter + 1), "locked boss skipped the current frontier")
			check(progress.to_state() == before, "rejected boss mutated progress")
		check(progress.record_boss_defeat(chapter), "frontier boss defeat was not recorded")
		check(progress.has_cleared(chapter), "accepted boss defeat lost clear state")
		check(progress.get_highest_unlocked_chapter() == mini(chapter + 1, 6), "unlock did not advance exactly one chapter")
		check(progress.is_campaign_complete() == (chapter == 6), "campaign completion not tied to sixth boss")
		var after: Dictionary = progress.to_state()
		for replay in range(1, chapter + 1):
			check(not progress.record_boss_defeat(replay), "duplicate/replay boss defeat claims a new unlock")
			check(progress.to_state() == after, "replaying a chapter changed permanent progress")
		var restored = progress_script.new()
		# JSON parses numeric values as floats; test actual encode/decode.
		check(restored.restore_state(JSON.parse_string(JSON.stringify(after))), "valid JSON state did not restore")
		check(restored.to_state() == after, "restored progress differs")
		var exported: Dictionary = progress.to_state()
		exported["cleared_chapters"].clear()
		check(progress.to_state() == after, "caller mutated progress through exported array")
	check(not progress.is_unlocked(7), "sixth boss created a seventh chapter")
	var invalid_states: Array[Dictionary] = [
		{}, {"version": 2, "cleared_chapters": []}, {"version": "1", "cleared_chapters": []},
		{"version": true, "cleared_chapters": []}, {"version": 1.5, "cleared_chapters": []},
		{"version": NAN, "cleared_chapters": []}, {"version": INF, "cleared_chapters": []},
		{"version": 1, "cleared_chapters": [2]}, {"version": 1, "cleared_chapters": [1, 3]},
		{"version": 1, "cleared_chapters": [1, 1]}, {"version": 1, "cleared_chapters": [0]},
		{"version": 1, "cleared_chapters": [1, 2, 3, 4, 5, 6, 7]},
		{"version": 1, "cleared_chapters": ["1"]}, {"version": 1, "cleared_chapters": [true]},
		{"version": 1, "cleared_chapters": [1.5]}, {"version": 1, "cleared_chapters": [NAN]},
		{"version": 1, "cleared_chapters": [INF]}, {"version": 1, "cleared_chapters": {}},
		{"version": 1, "cleared_chapters": [], "pending_stage": 6},
		{"version": 1, "pending_stage": 6, "boundary": "boss_settlement"},
	]
	var completed: Dictionary = progress.to_state()
	for state in invalid_states:
		check(not progress.restore_state(state), "invalid/legacy state accepted: " + str(state))
		check(progress.to_state() == completed, "rejected import destroyed existing progress")
	var fresh = progress_script.new()
	check(fresh.restore_state({"version": 1, "cleared_chapters": []}), "empty valid campaign cannot restore")
	check(fresh.get_highest_unlocked_chapter() == 1, "empty restored campaign lost initial unlock")
	if failures == 0:
		print("TEST PASS: CampaignProgressTest %d" % assertions)
	quit(0 if failures == 0 else 1)
