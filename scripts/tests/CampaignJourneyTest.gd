extends SceneTree

var assertions := 0
var failures := 0

func check(ok: bool, message: String) -> void:
	assertions += 1
	if not ok:
		failures += 1
		push_error("TEST FAIL: CampaignJourneyTest " + message)

func _initialize() -> void:
	var source := "res://scripts/systems/CampaignJourney.gd"
	check(ResourceLoader.exists(source, "GDScript"), "persistent journey model missing")
	if failures > 0:
		quit(1)
		return
	var Journey = load(source)
	var journey = Journey.new()
	check(journey.get_entry() == {"loop": 1, "chapter": 1}, "new journey skips first chapter")
	check(journey.get_build() == {"coins": 0, "inherited_counts": {}}, "new journey creates rewards")
	var before: Dictionary = journey.to_state()
	for invalid in [[1, 2, 30, {"damage": 1}, "damage"], [0, 1, 30, {"damage": 1}, "damage"], [1, 1, -1, {"damage": 1}, "damage"], [1, 1, 30, {"orbital_storm": 1}, "orbital_storm"], [1, 1, 30, {"damage": 1}, "mine"], [1, 1, 30, {"damage": 1}, ""]]:
		check(not journey.commit_clear(invalid[0], invalid[1], invalid[2], invalid[3], invalid[4]), "invalid clear accepted")
		check(journey.to_state() == before, "rejected clear changed journey")
	for chapter in range(1, 7):
		var inherited: Dictionary = journey.get_build().inherited_counts
		var earned := inherited.duplicate(true)
		var selected := "damage" if chapter < 6 else "mine"
		earned[selected] = int(earned.get(selected, 0)) + 1
		check(journey.commit_clear(1, chapter, chapter * 13, earned, selected), "chapter clear rejected")
		check(journey.get_build().coins == chapter * 13, "coins added rather than checkpointed")
		var after: Dictionary = journey.to_state()
		check(not journey.commit_clear(1, chapter, chapter * 13, earned, selected), "duplicate signal granted extra rank")
		check(journey.to_state() == after, "duplicate signal mutated reward")
		check(journey.commit_clear(1, chapter, chapter * 13 - 2, earned, ""), "replay without duplicate reward cannot checkpoint balance")
		check(journey.get_build().inherited_counts == after.inherited_counts, "replay duplicated inherited stats")
	check(journey.get_entry() == {"loop": 2, "chapter": 1}, "sixth ends journey rather than next loop")
	check(journey.commit_clear(2, 1, 120, {"damage": 5, "mine": 2}, "mine"), "second loop reward rejected")
	check(journey.get_entry() == {"loop": 2, "chapter": 2}, "second loop did not advance")
	check(journey.checkpoint_coins(5), "spending checkpoint rejected")
	check(journey.get_build().coins == 5, "spending balance lost")
	var exported: Dictionary = journey.to_state()
	exported.inherited_counts.clear()
	check(not journey.get_build().inherited_counts.is_empty(), "exported dictionary aliases live data")
	var state: Dictionary = journey.to_state()
	var restored = Journey.new()
	check(restored.restore_state(JSON.parse_string(JSON.stringify(state))), "JSON roundtrip rejected")
	check(restored.to_state() == state, "JSON restore changed progress/coins/cards")
	for impossible in [{"version": 1, "cleared_stage": 0, "coins": 0, "inherited_counts": {"damage": 1}}, {"version": 1, "cleared_stage": 1, "coins": 0, "inherited_counts": {"damage": 2}}]:
		check(not restored.restore_state(impossible), "more carried ranks than legitimate clears accepted")
		check(restored.to_state() == state, "impossible reward import modified live journey")
	for field in ["version", "cleared_stage", "coins", "inherited_counts"]:
		var bad := state.duplicate(true)
		bad.erase(field)
		check(not restored.restore_state(bad) and restored.to_state() == state, "missing field destroys checkpoint")
	for bad_values in [{"version": 2}, {"cleared_stage": -1}, {"cleared_stage": 1.5}, {"coins": true}, {"coins": NAN}, {"coins": -1}, {"inherited_counts": {"thunder_matrix": 1}}, {"inherited_counts": {"damage": 6}}, {"extra": true}]:
		var bad := state.duplicate(true)
		bad.merge(bad_values, true)
		check(not restored.restore_state(bad) and restored.to_state() == state, "invalid checkpoint accepted/mutated model")
	if failures == 0:
		print("TEST PASS: CampaignJourneyTest %d" % assertions)
	quit(0 if failures == 0 else 1)
