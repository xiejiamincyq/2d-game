extends SceneTree

const Growth = preload("res://scripts/systems/UpgradeSystem.gd")
var assertions := 0
var failures := 0

func check(ok: bool, message: String) -> void:
	assertions += 1
	if not ok:
		failures += 1
		push_error("TEST FAIL: CampaignCarryRulesTest " + message)

func _initialize() -> void:
	var source := "res://scripts/systems/CampaignCarryRules.gd"
	check(ResourceLoader.exists(source, "GDScript"), "shared six-chapter carry rules missing")
	if failures > 0:
		quit(1)
		return
	var rules = load(source)
	var growth := Growth.new()
	var catalog: Array[Dictionary] = growth.upgrade_pool.duplicate(true)
	growth.free()
	for chapter in range(1, 7):
		for replay in range(3):
			check(rules.base_stats(chapter) == {"health": 90 + 10 * chapter, "shield": 20}, "chapter/replay base stats differ")
	for chapter in [-1, 0, 7]:
		check(rules.base_stats(chapter).is_empty(), "invalid chapter accepted")
	check(rules.validate_counts({}, catalog), "empty inherited build rejected")
	check(rules.validate_counts({"mine": 1, "move_speed": 2}, catalog), "valid prerequisite build rejected")
	for invalid in [{"orbital_storm": 1}, {"thunder_matrix": 1}, {"rift_overdrive": 1}, {"unknown": 1}, {"damage": 6}, {"damage": 0}, {"damage": true}, {"damage": 1.5}, {"damage": NAN}, {"drone_damage": 1}]:
		check(not rules.validate_counts(invalid, catalog), "invalid inherited build accepted: " + str(invalid))
	var earned := {"damage": 2, "mine": 1, "move_speed": 1, "orbital_storm": 1}
	check(rules.eligible_ids(earned, {}, catalog) == ["damage", "mine"], "unearned/evolution/orphan cards eligible")
	check(rules.eligible_ids(earned, {"mine": 1}, catalog) == ["damage", "move_speed"], "inherited prerequisite not recognized")
	check(rules.eligible_ids({"damage": 5}, {"damage": 5}, catalog).is_empty(), "capped/unchanged card rewarded")
	check(rules.eligible_ids({"damage": 1.5}, {}, catalog).is_empty(), "invalid earned rank eligible")
	if failures == 0:
		print("TEST PASS: CampaignCarryRulesTest %d" % assertions)
	quit(0 if failures == 0 else 1)
