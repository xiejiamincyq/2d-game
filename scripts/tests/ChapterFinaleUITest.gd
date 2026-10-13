extends "ChapterFinaleFlowTest.gd"
## Controlled real Chapter UI integration; not ordinary combat or balance.

func _run() -> void:
	var before := FileAccess.get_sha256(Store.DEFAULT_PATH) if FileAccess.file_exists(Store.DEFAULT_PATH) else ""
	var chapter: Node = _fixture()
	if chapter == null: quit(1); return
	await _clear_encounter(chapter)
	await _clear_encounter(chapter)
	chapter.ui.supply_button.pressed.emit()
	var screen: Control = chapter.ui.settlement_screen
	if not check(chapter.director.state == chapter.director.State.REWARD and screen.is_visible_in_tree(), "route UI did not show the final reward"):
		await _dispose(chapter)
		quit(1)
		return
	check(screen.title_label.text.contains("首领前整备"), "finale title still says normal encounter loot")
	check(screen.wave_label.text.contains("2") and not screen.wave_label.text.contains("波"), "finale encounter count wording is missing or fakes a wave")
	check(screen.close_button.text.contains("迎战首领") and screen.close_button.disabled, "finale close does not explain/gate Boss entry")
	check(screen.hint_label.text.contains("3级") and screen.hint_label.text.contains("模块"), "actual chapter qualification is not explained")
	check(paused and not chapter.ui.flow_root.visible, "reward failed to pause combat or hid behind flow modal")
	check(screen.offer_buttons.size() == 6, "finale did not reuse the six real choices")
	var chosen: Dictionary = screen.current_offers[0]
	check(chosen.id == "orbital_storm" and screen.offer_buttons[0].text.contains("免费领取"), "focused build's real free evolution is not readable")
	for extent in [Vector2(960,540), Vector2(1280,720), Vector2(1920,1080)]:
		chapter.ui.apply_viewport_size(extent)
		await process_frame
		check(screen.get_required_size().x <= extent.x and screen.get_required_size().y <= extent.y, "reward overflows %s" % extent)
	chapter.ui.settlement_screen.offer_buttons[0].pressed.emit()
	check(chapter.player.active_build_evolutions.has("orbital_storm") and not screen.close_button.disabled, "UI free evolution did not update real Player/close gate")
	check(screen.hint_label.text.contains("迎战首领") and not screen.hint_label.text.contains("下一波"), "claimed reward resets to legacy wording")
	chapter.ui.settlement_screen.close_button.pressed.emit()
	check(chapter.director.state == chapter.director.State.BOSS_READY and chapter.ui.proceed_button.is_visible_in_tree() and not screen.visible, "UI close failed to show true Boss preparation")
	check(not FileAccess.file_exists(chapter.campaign_store_path), "UI wrote a premature permanent clear")
	await _dispose(chapter)
	check(before == (FileAccess.get_sha256(Store.DEFAULT_PATH) if FileAccess.file_exists(Store.DEFAULT_PATH) else ""), "user save changed")
	if failures == 0: print("TEST PASS: ChapterFinaleUITest %d" % assertions)
	quit(1 if failures > 0 else 0)
