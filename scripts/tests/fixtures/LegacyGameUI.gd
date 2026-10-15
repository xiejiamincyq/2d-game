extends "res://scripts/ui/GameUI.gd"
## Offline historical regression fixture. Excluded from all game exports.
signal legacy_start_requested
signal continue_requested
const LegacyMenu=preload("res://scripts/tests/fixtures/LegacyCampaignStartScreen.gd")
var continue_button: Button

func _build_start_screen() -> void:
	start_screen = LegacyMenu.new()
	start_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(start_screen)
	start_backdrop = start_screen
	start_panel = start_screen.cover_panel
	start_button = start_screen.start_button
	continue_button = start_screen.continue_button
	start_screen.start_requested.connect(func() -> void: start_requested.emit())
	start_screen.legacy_start_requested.connect(func() -> void: legacy_start_requested.emit())
	start_screen.continue_requested.connect(func() -> void: continue_requested.emit())
	start_screen.chapter_requested.connect(func(chapter: int) -> void: chapter_requested.emit(chapter))
	start_screen.quit_requested.connect(func() -> void: quit_requested.emit())
	start_screen.bgm_volume_changed.connect(_forward_bgm_volume)
	start_screen.bgm_mute_changed.connect(_forward_bgm_mute)


func set_continue_available(available: bool) -> void:
	start_screen.set_continue_available(available)

func _unhandled_input(event: InputEvent) -> void:
	if start_screen.visible and event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_C and start_screen.page==LegacyMenu.Page.LEGACY:
		start_screen._continue()
		return
	super._unhandled_input(event)
