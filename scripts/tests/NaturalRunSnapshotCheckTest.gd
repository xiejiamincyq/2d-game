extends SceneTree

const Harness = preload("res://scripts/art/VerifyNaturalRun.gd")

func _initialize() -> void:
	var state := {"position": [float(Vector2(541.576354980469, -435.326477050781).x), float(Vector2(541.576354980469, -435.326477050781).y)], "coins": 52, "settlement": {"generation": 1, "closed": false, "offers": [{"id": "drone", "rank": 1}]}}
	var saved: Dictionary = JSON.parse_string(JSON.stringify(state))
	if not Harness.persisted_state_matches(state, saved):
		push_error("TEST FAIL: NaturalRunSnapshotCheckTest: faithful JSON round-trip was rejected")
		quit(1)
		return
	var assertions := 1
	for change in ["position", "coins", "rank", "closed", "missing", "extra"]:
		var different := saved.duplicate(true)
		match change:
			"position": different.position[0] += 0.001
			"coins": different.coins += 1
			"rank": different.settlement.offers[0].rank += 1
			"closed": different.settlement.closed = 0
			"missing": different.erase("coins")
			"extra": different["unexpected"] = true
		assertions += 1
		if Harness.persisted_state_matches(state, different):
			push_error("TEST FAIL: NaturalRunSnapshotCheckTest: changed %s accepted" % change)
			quit(1)
			return
	print("TEST PASS: NaturalRunSnapshotCheckTest %d" % assertions)
	quit(0)
