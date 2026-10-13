extends RefCounted
class_name TestSupport

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
