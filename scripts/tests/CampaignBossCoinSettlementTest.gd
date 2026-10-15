extends "res://scripts/tests/CampaignSixChapterCarryFlowTest.gd"
## Actual distant Boss deaths. High damage fixture, not ordinary-input victories.
func check(ok: bool,message: String) -> void:
	assertions += 1
	if not ok:
		failures += 1
		push_error("TEST FAIL: CampaignBossCoinSettlementTest "+message)
func _run() -> void:
	for base in [Store.DEFAULT_PATH,Journal.DEFAULT_PATH]:
		for suffix in ["",".bak",".tmp"]: protected_hashes[base+suffix] = _hash(base+suffix)
	for number in range(1,7):
		owned_path = "user://boss_coins_%d_%d.json"%[OS.get_process_id(),number]
		check(_hash(owned_path+".journey")=="MISSING","unique fixture")
		var legacy := Progress.new()
		for previous in range(1,number): check(legacy.record_boss_defeat(previous),"controlled predecessor")
		check(Store.new(owned_path).save_progress(legacy),"legacy prerequisite fixture")
		var chapter = Registry.instantiate_chapter(number)
		chapter.campaign_store_path = owned_path
		chapter.audio_enabled = false
		chapter.run_seed = 521
		root.add_child(chapter)
		current_scene = chapter
		for frame in 360:
			if not chapter.player.is_entrance_active(): break
			await process_frame
		await _battle(chapter)
		await _battle(chapter)
		chapter.ui.supply_button.pressed.emit()
		check(Support.claim_chapter_finale(chapter),"actual finale")
		chapter.ui.proceed_button.pressed.emit()
		var boss = chapter.director.get_active_boss()
		for frame in 360:
			if boss.entrance_resolved: break
			await process_frame
		check(boss.global_position.distance_to(chapter.player.global_position)>200,"actual distant kill fixture")
		chapter.spawn_coins(boss.global_position,7) # Unclaimed floor loot is not a Boss reward.
		var before: int = chapter.growth.coins
		var reward: int = boss.coin_value
		check(reward==60 and boss.take_damage(1e9,&"test"),"accepted actual Boss death")
		boss.died.emit(boss,reward,&"test") # Duplicate notification of the real dead body.
		await process_frame
		await process_frame
		check(chapter.growth.coins==before+reward,"chapter %d final Boss reward lost or double paid"%number)
		check(chapter.session.journey.get_build().coins==before+reward,"chapter %d receipt excludes terminal reward"%number)
		check(Support.claim_chapter_carry(chapter),"actual ordinary carry selection")
		chapter.ui.return_button.pressed.emit()
		await process_frame
		await process_frame
		check(current_scene.campaign_session.journey.get_build().coins==before+reward,"tent loses Boss reward or sweeps unrelated floor loot")
		await _cleanup()
	if not failures: print("TEST PASS: CampaignBossCoinSettlementTest %d"%assertions)
	quit(1 if failures else 0)
