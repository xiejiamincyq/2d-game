extends SceneTree
const Progress = preload("res://scripts/systems/CampaignProgress.gd")
const LegacyStore = preload("res://scripts/systems/CampaignProgressStore.gd")
var checks := 0
var failures := 0
var directory := ""

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("TEST FAIL: CampaignSessionTest " + message)

func _initialize() -> void:
	var source := "res://scripts/systems/CampaignSession.gd"
	check(ResourceLoader.exists(source, "GDScript"), "shared persistent chapter session missing")
	if failures:
		quit(1)
		return
	var Session = load(source)
	check(Session != null and Session.can_instantiate(), "session script cannot compile")
	if failures:
		quit(1)
		return
	directory = "user://campaign-session-test-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	check(not DirAccess.dir_exists_absolute(directory) and DirAccess.make_dir_absolute(directory) == OK, "unique test directory")
	var legacy_path := directory.path_join("campaign.json")
	var old := Progress.new()
	check(old.record_boss_defeat(1) and old.record_boss_defeat(2), "legacy predecessor fixture")
	check(LegacyStore.new(legacy_path).save_progress(old), "real legacy migration fixture")
	var old_hash := FileAccess.get_sha256(legacy_path)
	var session = Session.new(legacy_path)
	check(session.load(), "old chapter progress cannot migrate")
	check(session.journey.get_entry() == {"loop": 1, "chapter": 3} and session.progress.has_cleared(2), "migration lost old unlock frontier")
	check(session.journey.get_build() == {"coins": 0, "inherited_counts": {}}, "migration invented past coins/abilities")
	check(not FileAccess.file_exists(legacy_path + ".journey") and FileAccess.get_sha256(legacy_path) == old_hash, "load writes user files")
	check(session.loop_for_chapter(2) == 1 and session.loop_for_chapter(4) == 0, "locked chapter/replay admission wrong")
	check(session.checkpoint_coins(72), "actual balance checkpoint failed")
	check(session.record_defeat(1, 3, 72, {"damage": 1, "orbital_storm": 1}), "true clear receipt cannot save")
	check(not session.progress.has_cleared(3) and session.has_pending_clear(), "unselected reward falsely advances progress")
	check(not session.claim_pending("orbital_storm"), "ultimate inherited through session")
	var restored = Session.new(legacy_path)
	check(restored.load() and restored.has_pending_clear() and restored.journey.get_build().coins == 72, "fresh session loses pending Boss reward or balance")
	check(restored.claim_pending("damage"), "selected normal card cannot atomically commit")
	check(restored.progress.has_cleared(3) and restored.journey.get_build() == {"coins": 72, "inherited_counts": {"damage": 1}}, "save atomically loses gold/card/unlock")
	check(not restored.claim_pending("damage"), "duplicate selection grants another ability")
	check(restored.record_defeat(1, 3, 79, {"damage": 2}), "replay cannot preserve actual earned gold")
	check(not restored.has_pending_clear() and restored.journey.get_build().inherited_counts == {"damage": 1}, "replay gives another inheritance")
	check(restored.checkpoint_coins(11), "spent coins did not persist")
	var final_session = Session.new(legacy_path)
	check(final_session.load() and final_session.journey.get_build().coins == 11 and final_session.progress.has_cleared(3), "tent/restart loses shared checkpoint")
	check(FileAccess.get_sha256(legacy_path) == old_hash, "new game overwrote legacy unlock save")
	for chapter in range(4, 7):
		check(final_session.record_defeat(1, chapter, 11 + chapter, {"damage": 1}), "later chapter receipt cannot save")
		check(final_session.claim_pending(""), "no newly earned ability should not softlock")
	check(final_session.journey.get_entry() == {"loop": 2, "chapter": 1} and final_session.progress.is_campaign_complete(), "sixth ends campaign rather than continues next loop")
	check(final_session.loop_for_chapter(6) == 1 and final_session.loop_for_chapter(1) == 2, "sixth replay/new loop policy wrong")
	check(final_session.record_defeat(1, 6, 50, {"damage": 1}) and not final_session.has_pending_clear(), "sixth replay reissues inheritance")
	check(not final_session.record_defeat(2, 3, 50, {"damage": 2}), "future loop chapter skipped")
	# Remove only fixtures created in this unique directory.
	for name in ["campaign.json", "campaign.json.bak", "campaign.json.tmp", "campaign.json.journey", "campaign.json.journey.bak", "campaign.json.journey.tmp"]:
		var owned: String = directory.path_join(name)
		if FileAccess.file_exists(owned):
			check(DirAccess.remove_absolute(owned) == OK, "owned fixture cleanup")
	check(DirAccess.remove_absolute(directory) == OK, "owned directory cleanup")
	if failures == 0:
		print("TEST PASS: CampaignSessionTest %d" % checks)
	quit(0 if failures == 0 else 1)
