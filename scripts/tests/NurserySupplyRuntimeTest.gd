extends "NurseryChapterTest.gd"
## Controlled actual enemy deaths/deferred pickups, not human combat balance.
const Heart = preload("res://scripts/pickups/HeartPickup.gd")
const Shield = preload("res://scripts/pickups/ShieldPickup.gd")
func _run() -> void:
	var chapter = _fixture(load("res://scenes/campaign/nursery_chapter.tscn"), "user://nursery_supply_%d.json" % OS.get_process_id())
	for frame in 360:
		if not chapter.player.is_entrance_active(): break
		await process_frame
	for encounter in 2:
		var counts := [0,0]
		var observer := func(pickup: Node) -> void:
			if pickup.get_script()==Heart: counts[0] += 1
			if pickup.get_script()==Shield:
				counts[1] += 1
				check(pickup.value==9.0, "actual small shield value changed")
		chapter.pickups.child_entered_tree.connect(observer)
		await _battle(chapter)
		chapter.pickups.child_entered_tree.disconnect(observer)
		check(counts[0]>=1 and counts[1]>=1, "accepted deaths did not create both guaranteed pickup types")
	check(not FileAccess.file_exists(chapter.campaign_store_path), "supply test wrote premature progress")
	await _dispose(chapter)
	if failures==0: print("TEST PASS: NurserySupplyRuntimeTest %d" % assertions)
	quit(1 if failures else 0)
