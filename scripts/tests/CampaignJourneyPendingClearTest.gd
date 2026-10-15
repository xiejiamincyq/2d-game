extends SceneTree
const Journey = preload("res://scripts/systems/CampaignJourney.gd")
var checks := 0
var failures := 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("TEST FAIL: CampaignJourneyPendingClearTest " + message)

func _initialize() -> void:
	var journey := Journey.new()
	for method in ["begin_pending_clear", "get_pending_clear", "finalize_pending_clear"]:
		check(journey.has_method(method), "missing durable pending reward API: " + method)
	if failures:
		quit(1)
		return
	var earned := {"damage": 1, "orbital_storm": 1}
	check(journey.call("begin_pending_clear", 1, 1, 91, earned), "actual first clear receipt not accepted")
	check(journey.to_state().cleared_stage == 0 and journey.get_build().inherited_counts.is_empty(), "unselected ability already awarded")
	check(journey.get_entry() == {"loop": 1, "chapter": 1} and journey.get_build().coins == 91, "pending entry/balance differs from actual clear")
	var pending: Dictionary = journey.call("get_pending_clear")
	check(pending == {"loop": 1, "chapter": 1, "coins": 91, "earned_counts": earned}, "receipt loses actual earned abilities")
	var before: Dictionary = journey.to_state()
	check(not journey.checkpoint_coins(33) and journey.to_state() == before, "pending balance changed by another activity")
	check(not journey.call("begin_pending_clear", 1, 2, 30, {}) and journey.to_state() == before, "another Boss replaced pending reward")
	pending.earned_counts.clear()
	check(journey.to_state() == before, "exported pending receipt aliases model")
	var restored := Journey.new()
	check(restored.restore_state(JSON.parse_string(JSON.stringify(before))) and restored.to_state() == before, "new-process JSON receipt not restored canonically")
	for invalid_choice in ["orbital_storm", "mine", ""]:
		check(not restored.call("finalize_pending_clear", invalid_choice) and restored.to_state() == before, "invalid/missing selection awarded ability")
	check(restored.call("finalize_pending_clear", "damage"), "earned normal selection not committed")
	check(restored.get_build() == {"coins": 91, "inherited_counts": {"damage": 1}} and restored.get_entry() == {"loop": 1, "chapter": 2}, "one selection fails atomic gold/ability/frontier result")
	check((restored.call("get_pending_clear") as Dictionary).is_empty() and not restored.call("finalize_pending_clear", "damage"), "repeated selection gives another reward")
	check(restored.call("begin_pending_clear", 1, 2, 100, {"damage": 1}), "capped/unchanged build receipt rejected")
	check(restored.call("finalize_pending_clear", "") and restored.to_state().cleared_stage == 2, "no eligible ability softlocks progress")
	var committed := restored.to_state()
	for invalid_pending in [{"loop": 2, "chapter": 3, "coins": 100, "earned_counts": {}}, {"loop": 1, "chapter": 4, "coins": 100, "earned_counts": {}}, {"loop": 1, "chapter": 3, "coins": 101, "earned_counts": {}}, {"loop": 1, "chapter": 3, "coins": 100, "earned_counts": {"unknown": 1}}, {"loop": 1, "chapter": 3, "coins": 100, "earned_counts": {"damage": true}}, {"loop": 1, "chapter": 3, "coins": 100, "earned_counts": {}}]:
		var bad := committed.duplicate(true)
		bad.pending_clear = invalid_pending
		check(not restored.restore_state(bad) and restored.to_state() == committed, "impossible pending receipt accepted or changed memory")
	var old_checkpoint := committed.duplicate(true)
	old_checkpoint.erase("pending_clear")
	check(restored.restore_state(old_checkpoint) and restored.to_state() == committed, "earlier four-field v1 candidate cannot migrate")
	if failures == 0:
		print("TEST PASS: CampaignJourneyPendingClearTest %d" % checks)
	quit(0 if failures == 0 else 1)
