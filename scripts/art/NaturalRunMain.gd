extends "res://scripts/Main.gd"

# Only startup RNG/save destination differ; all game states/rules stay inherited.
# Refuse standalone use: never fall back to the real user's store.
func _ready() -> void:
	var config: Dictionary = get_tree().get_meta("natural_run_config", {})
	if config.is_empty() or not String(config.save_path).begins_with("user://natural-run/"):
		push_error("NaturalRunMain requires preassigned isolated save metadata")
		get_tree().quit(2)
		return
	process_mode = Node.PROCESS_MODE_ALWAYS
	seed(int(config.seed))
	audio_enabled = false
	RenderingServer.set_default_clear_color(Color(0.025, 0.032, 0.045))
	snapshot_store = RunSnapshotStoreScript.new()
	snapshot_store.save_path = config.save_path
	add_child(snapshot_store)
	_build_world()
	ui.show_start_screen()
	ui.set_continue_available(snapshot_store.has_valid_snapshot())

func _begin_run(snapshot: Dictionary) -> void:
	super._begin_run(snapshot)
	# Initial portals do not open until the unmodified entrance/banner completes.
	wave_director.spawn_rng.seed = int(get_tree().get_meta("natural_run_config").seed) + 1000003
