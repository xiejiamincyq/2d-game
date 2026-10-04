extends "res://scripts/art/VerifyNaturalRunRendered.gd"

var overdrive_image: Image
var overdrive_record: Dictionary = {}

func _capture() -> void:
	super._capture()
	if started == 0 or reloading or not terminal.is_empty() or not is_instance_valid(view) or not view.is_inside_tree() or not is_instance_valid(scene) or not is_instance_valid(scene.player) or overdrive_image != null:
		return
	if scene.run_state != scene.RunState.PLAYING or not scene.player.overdrive_active:
		return
	overdrive_image = view.get_texture().get_image()
	if overdrive_image == null or overdrive_image.is_empty() or overdrive_image.get_size() != Vector2i(1280, 720):
		valid = false
		terminal = "capture_error"
		return
	overdrive_record = _visual_info()
	overdrive_record.merge({"frame": Engine.get_physics_frames(), "process_frame": Engine.get_process_frames(), "wall": float(Time.get_ticks_usec() - started) / 1000000.0})

func _source_hashes() -> Dictionary:
	var hashes := super._source_hashes()
	hashes["scripts/art/VerifyFriendlyNatural.gd"] = FileAccess.get_sha256("res://scripts/art/VerifyFriendlyNatural.gd")
	return hashes

func _finish() -> void:
	var path := capture_dir + "overdrive-extra.png"
	if overdrive_image == null or overdrive_image.save_png(path) != OK:
		valid = false
	else:
		overdrive_record.merge({"path": path.trim_prefix("res://"), "sha256": FileAccess.get_sha256(path), "source_sha256": source_before, "scope": "one actual natural post-draw overdrive frame; supplementary, not a seventh quota clip"})
		var file := FileAccess.open(capture_dir.trim_suffix("/") + "-overdrive.json", FileAccess.WRITE)
		if file == null:
			valid = false
		else:
			file.store_string(JSON.stringify(overdrive_record))
			file.close()
	overdrive_image = null
	await super._finish()
