extends SceneTree

const Cue = preload("res://scripts/systems/OriginalOverdriveCue.gd")

func _initialize() -> void:
	var path := "res://build/diagnostics/campaign-goal/original-overdrive-preview-v1.wav"
	if FileAccess.file_exists(path):
		push_error("Original overdrive preview already exists; preserving it")
		quit(1)
		return
	var result := Cue.build().save_to_wav(path)
	if result != OK:
		push_error("Unable to save original cue preview: %d" % result)
		quit(1)
		return
	print("TEST PASS: PreviewOriginalOverdriveCue 1")
	quit(0)
