# Negative fixture: must emit the real timeout error and exit 1, never TEST PASS.
extends SceneTree

const MainScript = preload("res://scripts/Main.gd")

class NeverDrains extends Node:
	func begin_shutdown() -> void:
		pass
	func is_shutdown_complete() -> bool:
		return false

class TimeoutMain extends MainScript:
	func _finish_close(exit_code: int) -> void:
		print("NEGATIVE EXPECTED: timeout exit_code=", exit_code)
		get_tree().quit(exit_code if exit_code == 1 else 3)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := TimeoutMain.new()
	scene.audio_enabled = false
	root.add_child(scene)
	scene.audio.free()
	scene.audio = NeverDrains.new()
	scene.add_child(scene.audio)
	if "--restart" in OS.get_cmdline_user_args():
		scene._restart_run()
	else:
		scene._request_close()
	var deadline := Time.get_ticks_msec() + 3000
	while Time.get_ticks_msec() < deadline:
		await process_frame
	print("NEGATIVE FIXTURE FAILED: close did not finish within bound")
	quit(4)
