extends SceneTree
## Actual Player/Growth reconstruction, not a Boss-clear or full-campaign claim.
const Player = preload("res://scripts/actors/Player.gd")
const Growth = preload("res://scripts/systems/UpgradeSystem.gd")
var assertions := 0
var failures := 0

func check(ok: bool, message: String) -> void:
	assertions += 1
	if not ok:
		failures += 1
		push_error("TEST FAIL: CampaignChapterCarryBuildTest " + message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var probe := Growth.new()
	var available := probe.has_method("setup_chapter_with_carry")
	probe.free()
	check(available, "shared chapter carry initialization missing")
	if not available:
		quit(1)
		return
	for chapter in range(1, 7):
		for replay in range(2):
			var player := Player.new()
			root.add_child(player)
			player.set_physics_process(false)
			var growth := Growth.new()
			root.add_child(growth)
			var build := {"coins": 57, "inherited_counts": {"damage": 2, "mine": 1, "move_speed": 1}}
			check(growth.call("setup_chapter_with_carry", player, chapter, build), "actual chapter carry setup")
			check(player.health.max_health == 90 + chapter * 10 and player.health.current_health == player.health.max_health, "six-chapter HP base/replay changed")
			check(player.shield == 20 and player.max_shield == 20, "chapter does not start with fixed full shield")
			check(is_equal_approx(player.weapon_damage, 10 * 1.14 * 1.14), "carried damage rank not applied exactly twice")
			check(player.mine_level == 1 and is_equal_approx(player.move_speed, Player.BASE_MOVE_SPEED * 1.09), "dependent ability/core not restored")
			check(growth.coins == 57 and growth.upgrade_counts == build.inherited_counts, "actual coins/build lost")
			check(growth.family_levels == {"ballistics": 1, "mobility": 1, "automation": 1} and growth.acquired_evolution_id.is_empty() and player.active_build_evolutions.is_empty(), "ultimate/family progression accidentally carried")
			var before: Dictionary = growth.get_snapshot_state()
			check(not growth.call("setup_chapter_with_carry", player, chapter, build) and growth.get_snapshot_state() == before, "repeat initialization stacked build")
			check(is_equal_approx(player.weapon_damage, 10 * 1.14 * 1.14), "repeated setup changed actual damage")
			growth.free()
			player.free()
			await process_frame
	var player := Player.new()
	root.add_child(player)
	player.set_physics_process(false)
	for invalid in [{}, {"coins": -1, "inherited_counts": {}}, {"coins": true, "inherited_counts": {}}, {"coins": 0, "inherited_counts": {"thunder_matrix": 1}}, {"coins": 0, "inherited_counts": {"drone_damage": 1}}, {"coins": 0, "inherited_counts": {}, "extra": true}]:
		var growth := Growth.new()
		check(not growth.call("setup_chapter_with_carry", player, 6, invalid), "invalid carry accepted")
		check(player.health.max_health == 100 and player.shield == 0 and player.weapon_damage == 10 and growth.player == null, "invalid carry partially changed actor/context")
		growth.free()
	player.free()
	await process_frame
	if failures == 0:
		print("TEST PASS: CampaignChapterCarryBuildTest %d" % assertions)
	quit(0 if failures == 0 else 1)
