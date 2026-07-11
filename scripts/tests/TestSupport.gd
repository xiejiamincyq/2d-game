extends RefCounted
class_name TestSupport

static func stop_audio(audio: Node) -> void:
	if audio == null:
		return
	for child in audio.get_children():
		if child is AudioStreamPlayer:
			child.stop()
			child.stream = null
			child.free()
	if audio.get("bgm_player") != null:
		audio.set("bgm_player", null)
	if audio.get("laser_loop_player") != null:
		audio.set("laser_loop_player", null)
	var streams: Variant = audio.get("streams")
	if streams is Dictionary:
		streams.clear()
