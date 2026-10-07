extends SceneTree

const AudioScript = preload("res://scripts/systems/AudioManager.gd")
var assertions := 0
var audio_fixture: Node

func _check(condition: bool, message: String) -> bool:
	assertions += 1
	if condition:
		return true
	push_error("TEST FAIL: AudioLifecycleTest: " + message)
	if is_instance_valid(audio_fixture):
		audio_fixture.free()
		audio_fixture = null
	quit(1)
	return false

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	for silent in [false, true]:
		var audio: Node = AudioScript.new()
		audio_fixture = audio
		audio.silent_mode = silent
		root.add_child(audio)
		audio.play("start")
		audio.play_bgm()
		audio.set_laser_active(true)
		if not silent and not _check(audio.bgm_player.playing and audio.laser_loop_player.playing, "fixture did not start the real looping players"):
			return
		var players: Array[AudioStreamPlayer] = []
		for child in audio.get_children():
			if child is AudioStreamPlayer:
				players.append(child)
		if not _check(audio.has_method("begin_shutdown") and audio.has_method("is_shutdown_complete"), "manager has no explicit draining lifecycle"):
			return
		# Retain only weak observations, including voices replaced before shutdown.
		var observed: Array[WeakRef] = []
		if not silent:
			for player in players:
				if player.has_stream_playback():
					observed.append(weakref(player.get_stream_playback()))
			for index in range(40):
				audio.play("start")
				for player in players:
					if player.has_stream_playback():
						observed.append(weakref(player.get_stream_playback()))
		audio.begin_shutdown()
		audio.begin_shutdown()
		audio.play("start")
		audio.play_bgm()
		audio.set_laser_active(true)
		if not _check(not audio.play_shot() and not audio.play_hit(&"projectile") and not audio.play_kill_confirm() and not audio.play_overdrive_kill() and not audio.play_boss_cue(&"boss_phase"), "disposed manager reported accepted sound requests"):
			return
		paused = true
		var deadline := Time.get_ticks_msec() + 2000
		while not audio.is_shutdown_complete() and Time.get_ticks_msec() < deadline:
			await process_frame
		if not _check(audio.is_shutdown_complete(), "audio thread did not release playback within two seconds while paused"):
			return
		for playback in observed:
			if not _check(playback.get_ref() == null, "a retired or active playback survived successful shutdown"):
				return
		paused = false
		root.remove_child(audio)
		if not _check(audio.streams.is_empty(), "exited manager retained generated streams"):
			return
		for player in players:
			if not _check(not player.playing and player.stream == null, "exited player retained playback or a stream"):
				return
		if not _check(audio.bgm_player == null and audio.laser_loop_player == null and audio.voice_pool.is_empty(), "exited manager retained stale player references"):
			return
		if not _check(audio.get_child_count() == players.size(), "teardown removed child ownership instead of letting Node free them"):
			return
		root.add_child(audio)
		audio.play_bgm()
		if not _check(audio.is_shutdown_complete() and audio.streams.is_empty(), "terminal manager restarted after re-entry"):
			return
		audio.free()
		audio_fixture = null
	await process_frame
	print("TEST PASS: AudioLifecycleTest ", assertions)
	quit()
