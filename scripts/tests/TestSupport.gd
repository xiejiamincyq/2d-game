extends RefCounted
class_name TestSupport

const CampaignSession = preload("res://scripts/systems/CampaignSession.gd")

static func trap_field_snapshot(field: Node) -> Array:
	var result: Array=[]
	for trap in field.get_children():
		result.append([trap.get_instance_id(),trap.stage,trap.elapsed,trap.enabled,trap.health.current_health])
	return result

static func claim_chapter_carry(chapter: Node) -> bool:
	if chapter.director == null or chapter.director.state != chapter.director.State.CLEARED or chapter.director.defeated_boss_instance <= 0:
		return false
	if chapter.session.has_pending_clear():
		var selector: OptionButton = chapter.ui.carry_selector
		if not selector.is_visible_in_tree() or selector.item_count < 2:
			return false
		var card: Dictionary = selector.get_item_metadata(1)
		if card.kind == "evolution" or int(chapter.growth.upgrade_counts.get(String(card.id), 0)) < 1:
			return false
		selector.select(1)
		selector.item_selected.emit(1)
	return chapter.clear_saved and not chapter.session.has_pending_clear()

static func restore_journey_progress(path: String, progress: RefCounted) -> bool:
	var session := CampaignSession.new(path)
	return session.load() and progress.restore_state(session.progress.to_state())

static func cleanup_journey_fixture(path: String) -> bool:
	var filename := path.trim_prefix("user://")
	if not path.begins_with("user://") or not filename.contains("_" + str(OS.get_process_id())) or "/" in filename or "\\" in filename:
		return false
	for suffix in [".journey", ".journey.bak", ".journey.tmp"]:
		if FileAccess.file_exists(path + suffix) and DirAccess.remove_absolute(path + suffix) != OK:
			return false
	return true

static func claim_chapter_finale(chapter: Node) -> bool:
	# Controlled tests must traverse the real new UI transaction, never skip it
	# by editing Director state or Player stats. Not ordinary-combat evidence.
	if chapter.director.state != chapter.director.State.REWARD or chapter.growth.get_settlement_state().get("stage_kind") != "boss_prep":
		return false
	var screen: Control = chapter.ui.settlement_screen
	if not screen.is_visible_in_tree() or not screen.close_button.disabled:
		return false
	for button in screen.offer_buttons:
		if button.is_visible_in_tree() and not button.disabled:
			button.pressed.emit()
			break
	if not chapter.growth.get_settlement_state().reward_claimed or screen.close_button.disabled:
		return false
	screen.close_button.pressed.emit()
	return chapter.director.state == chapter.director.State.BOSS_READY and not screen.visible

static func stop_audio(audio: Node) -> void:
	if audio == null:
		return
	for child in audio.get_children():
		if child is AudioStreamPlayer:
			child.stop()
			child.stream = null
			child.free()
	audio.set("bgm_player", null)
	audio.set("laser_loop_player", null)
	var voices: Variant = audio.get("voice_pool")
	if voices is Array:
		voices.clear()
	var streams: Variant = audio.get("streams")
	if streams is Dictionary:
		streams.clear()
