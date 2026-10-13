extends SceneTree
## Pure entry selection: fixtures are not actual victories or save migrations.
const Progress = preload("res://scripts/systems/CampaignProgress.gd")
var assertions := 0
var failures := 0

func check(ok: bool, message: String) -> void:
	assertions += 1
	if not ok:
		failures += 1
		push_error("TEST FAIL: CampaignEntryPolicyTest " + message)

func _initialize() -> void:
	var path := "res://scripts/systems/CampaignEntryPolicy.gd"
	check(ResourceLoader.exists(path, "GDScript"), "formal default entry policy is missing")
	if failures:
		quit(1)
		return
	var policy = load(path)
	var ready := [1, 2, 3, 4, 5, 6]
	for clears in range(0, 7):
		var progress := Progress.new()
		for chapter in range(1, clears + 1):
			check(progress.record_boss_defeat(chapter), "sequential fixture rejected")
		var before: Dictionary = progress.to_state()
		var ready_before := ready.duplicate()
		var expected := mini(clears + 1, 6)
		check(policy.default_chapter(progress, ready, true) == expected, "frontier or terminal replay selection")
		check(policy.default_chapter(progress, ready, false) == 0, "unsafe storage silently permits entry")
		check(policy.default_chapter(progress, [], true) == 0, "missing content falls back to demo")
		for missing in range(1, 7):
			var partial := ready.duplicate()
			partial.erase(missing)
			check(policy.default_chapter(progress, partial, true) == (0 if missing == expected else expected), "ready gaps skip locked frontier or block unrelated replay")
		check(policy.default_chapter(progress, [0, 7, -1], true) == 0, "invalid ready IDs invent a chapter")
		check(progress.to_state() == before and ready == ready_before, "selection mutates caller state")
		check(not progress.is_unlocked(7), "terminal selection invents seventh chapter")
	var empty := Progress.new()
	check(policy.default_chapter(empty, [2, 3, 4, 5, 6], true) == 0, "new campaign skips first missing region")
	check(policy.default_chapter(empty, [1, 1, 7], true) == 1, "duplicate readiness changes frontier")
	check(policy.default_chapter(null, ready, true) == 0, "null model starts a campaign")
	if not failures:
		print("TEST PASS: CampaignEntryPolicyTest %d" % assertions)
	quit(1 if failures else 0)
