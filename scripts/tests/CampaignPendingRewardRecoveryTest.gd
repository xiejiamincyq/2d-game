extends "NurseryChapterTest.gd"
## Controlled real Boss death, save failure, Back and restoration; not human victory.
const Session = preload("res://scripts/systems/CampaignSession.gd")

func check(ok: bool,message: String) -> void:
	assertions += 1
	if not ok:
		failures += 1
		push_error("TEST FAIL: CampaignPendingRewardRecoveryTest "+message)

func _run() -> void:
	var owned := "user://pending_recovery_%d.json" % OS.get_process_id()
	check(not FileAccess.file_exists(owned+".journey"),"unique isolated checkpoint")
	var chapter := _fixture(load("res://scenes/campaign/nursery_chapter.tscn"),owned)
	for frame in 360:
		if not chapter.player.is_entrance_active(): break
		await process_frame
	await _battle(chapter)
	await _battle(chapter)
	chapter.ui.supply_button.pressed.emit()
	check(Support.claim_chapter_finale(chapter),"actual finale reward")
	chapter.ui.proceed_button.pressed.emit()
	var boss: Node = chapter.director.get_active_boss()
	for frame in 360:
		if boss.entrance_resolved: break
		await process_frame
	check(DirAccess.make_dir_absolute(owned+".journey.tmp")==OK,"owned save failure blocker")
	check(boss.take_damage(1e9,&"test"),"real accepted Boss death")
	await process_frame
	await process_frame
	check(chapter._clear_received and not chapter._receipt_saved,"receipt save genuinely failed")
	check(DirAccess.remove_absolute(owned+".journey.tmp")==OK,"owned empty blocker cleanup")
	# Back after a transient failure must retry the victory receipt, not merely coins.
	chapter.ui.return_button.pressed.emit()
	await process_frame
	await process_frame
	var tent = current_scene
	var fresh := Session.new(owned)
	check(fresh.load() and fresh.has_pending_clear(),"Back discarded accepted unsaved Boss reward")
	check(tent.get_script().resource_path=="res://scripts/Main.gd","actual Back did not return tent")
	if not fresh.has_pending_clear():
		await _dispose(tent)
		check(Support.cleanup_journey_fixture(owned),"owned failed fixture cleanup")
		quit(1)
		return
	tent.ui.start_requested.emit()
	await process_frame
	await process_frame
	var recovered = current_scene
	check(recovered!=tent and recovered._resuming_reward and recovered.player==null and recovered.director==null,"recovery invents a fresh Boss combat")
	check(recovered.ui.carry_selector.visible and recovered.ui.next_button.disabled,"pending restored navigation bypass")
	var card: Dictionary = recovered.ui.carry_selector.get_item_metadata(1)
	recovered.ui.carry_selector.select(1)
	recovered.ui.carry_selector.item_selected.emit(1)
	check(recovered.clear_saved and not recovered.session.has_pending_clear(),"restored real UI choice cannot commit")
	check(recovered.session.journey.get_build().inherited_counts=={card.id:1},"restoration grants wrong ability count")
	recovered.ui.next_button.pressed.emit()
	await process_frame
	await process_frame
	var second = current_scene
	check(second._chapter_number()==2 and second.growth.upgrade_counts=={card.id:1},"restored next chapter loses inherited reward")
	await _dispose(second)
	check(Support.cleanup_journey_fixture(owned),"owned journal cleanup")
	if not failures: print("TEST PASS: CampaignPendingRewardRecoveryTest %d"%assertions)
	quit(1 if failures else 0)
