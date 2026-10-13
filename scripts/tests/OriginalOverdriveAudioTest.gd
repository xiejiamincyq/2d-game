extends SceneTree

const AudioScript = preload("res://scripts/systems/AudioManager.gd")
var assertions := 0
var failed := false

func _check(condition: bool, message: String) -> bool:
	assertions += 1
	if not condition:
		failed = true
		push_error("TEST FAIL: OriginalOverdriveAudioTest: " + message)
	return condition

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var audio: Node = AudioScript.new()
	root.add_child(audio)
	var cue: AudioStream = audio.streams["overdrive_kill"]
	if _check(cue is AudioStreamWAV, "overdrive cue must be project-original PCM, not the untraced MP3"):
		var wav: AudioStreamWAV = cue
		_check(wav.resource_path.is_empty(), "generated cue unexpectedly references an external asset")
		_check(wav.get_meta(&"origin", "") == "project-original-synthesis-v1", "cue lacks explicit synthesis provenance")
		_check(wav.format == AudioStreamWAV.FORMAT_16_BITS and wav.mix_rate == 22050 and not wav.stereo, "PCM format changed")
		_check(wav.loop_mode == AudioStreamWAV.LOOP_DISABLED, "one-shot cue must not loop")
		_check(wav.get_length() >= 0.16 and wav.get_length() <= 0.20, "cue must remain short under dense kills")
		_check(wav.data.size() == 7938, "0.18 second mono cue has wrong sample count")
		_check(wav.data != audio.streams["kill_confirm"].data, "overdrive must remain distinct from ordinary kills")
		var peak := 0.0
		var square_sum := 0.0
		var signed_sum := 0.0
		var clipped := 0
		var end_peak := 0.0
		var samples := wav.data.size() / 2
		for i in range(samples):
			var value := float(wav.data.decode_s16(i * 2)) / 32767.0
			peak = maxf(peak, absf(value))
			square_sum += value * value
			signed_sum += value
			if absf(value) >= 0.99:
				clipped += 1
			if i >= samples - 110:
				end_peak = maxf(end_peak, absf(value))
		_check(peak >= 0.3 and peak <= 0.85 and clipped == 0, "cue is silent, clipped, or too hot")
		_check(sqrt(square_sum / samples) >= 0.04 and sqrt(square_sum / samples) <= 0.25, "cue energy exceeds the bounded mix envelope")
		_check(absf(signed_sum / samples) < 0.01, "cue has excessive DC offset")
		_check(wav.data.decode_s16(0) == 0 and wav.data.decode_s16(wav.data.size() - 2) == 0 and end_peak < 0.003, "cue lacks quiet boundaries")
		print("Original overdrive metrics: peak=%.6f rms=%.6f dc=%.6f tail_peak=%.6f samples=%d" % [peak, sqrt(square_sum / samples), signed_sum / samples, end_peak, samples])
		var second: Node = AudioScript.new()
		root.add_child(second)
		_check(second.streams["overdrive_kill"].data == wav.data, "synthesis changed across manager instances")
		second.begin_shutdown()
		while not second.is_shutdown_complete():
			await process_frame
		second.free()
		_check(audio.play_overdrive_kill(), "first overdrive cue rejected")
		_check(not audio.play_overdrive_kill() and not audio.play_kill_confirm(), "kill cooldown no longer shared")
		audio._process(1.0)
		_check(audio.play_kill_confirm(), "ordinary cue did not recover after cooldown")
		for i in range(64):
			audio.play("overdrive_kill")
		_check(audio.voice_pool.size() == 16 and audio.get_child_count() == 17, "dense kills allocated extra players")
		for voice in audio.voice_pool:
			_check(is_equal_approx(voice.volume_db, -8.0), "cue bypassed voice gain")
	audio.begin_shutdown()
	var deadline := Time.get_ticks_msec() + 2000
	while not audio.is_shutdown_complete() and Time.get_ticks_msec() < deadline:
		await process_frame
	_check(audio.is_shutdown_complete(), "audio playback failed to drain")
	audio.free()
	await process_frame
	if not failed:
		print("TEST PASS: OriginalOverdriveAudioTest %d" % assertions)
	quit(1 if failed else 0)
