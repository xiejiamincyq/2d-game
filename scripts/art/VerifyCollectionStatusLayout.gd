extends "res://scripts/art/VerifyCombatStatusLayout.gd"

func _capture_root() -> String:
	return "res://build/diagnostics/collection-layout/"

func _capture_modes() -> Array[String]:
	return ["collection", "collection_overdrive", "boss_all_collection", "collection_fade"]

func _configure_state(mode: String) -> void:
	super._configure_state("boss_all" if mode == "boss_all_collection" else "clear")
	ui.set_overdrive_charge(60.0, false)
	ui.set_collection_window(0.2 if mode == "collection_fade" else 3.0, 3.0)
	if mode == "collection_overdrive":
		ui.set_overdrive(true, 3.2)
		ui.set_overdrive_charge(100.0, true)
