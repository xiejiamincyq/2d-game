extends Node
class_name AudioManager

const DamageTypes = preload("res://scripts/components/DamageTypes.gd")
const EnemyScript = preload("res://scripts/actors/Enemy.gd")
const HIT_COOLDOWN := 0.055
const KILL_CONFIRM_COOLDOWN := 0.045
const SHOOT_COOLDOWN := 0.02
const VOICE_POOL_SIZE := 16
const BGM_BPM := 168.0
const BGM_BEATS_PER_BAR := 4
const BGM_BAR_COUNT := 8

var streams: Dictionary = {}
var bgm_profile_id: StringName = &"industrial_hardcore_168"
var bgm_player: AudioStreamPlayer
var bgm_volume_linear: float = 0.65
var bgm_muted: bool = false
var hit_stream_names: Dictionary = {
	DamageTypes.GENERIC: "enemy_hit",
	DamageTypes.PROJECTILE: "hit_projectile",
	DamageTypes.LASER: "hit_laser",
	DamageTypes.ARC: "hit_arc",
	DamageTypes.DASH: "hit_dash",
	DamageTypes.SPIKE: "hit_spike",
}
var hit_cooldowns: Dictionary = {}
var kill_confirm_cooldown: float = 0.0
var shoot_cooldown: float = 0.0
var laser_loop_player: AudioStreamPlayer
var voice_pool: Array[AudioStreamPlayer] = []
var voice_cursor: int = 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	streams["bgm"] = _make_bgm_loop()
	streams["shoot"] = _make_gunshot()
	streams["coin"] = _make_tone(1040.0, 0.07, 0.1, 0.34, 1.35)
	streams["pickup"] = _make_tone(760.0, 0.06, 0.1, 0.28)
	streams["upgrade"] = _make_tone(520.0, 0.18, 0.22, 0.45, 1.8)
	streams["hit"] = _make_tone(180.0, 0.05, 0.18, 0.32)
	streams["enemy_hit"] = _make_impact(0.075, 0.58, 820.0, 0.42)
	streams["hit_light"] = _make_impact(0.045, 0.34, 1680.0, 520.0)
	streams["hit_heavy"] = _make_heavy_impact()
	streams["hit_projectile"] = _make_impact(0.055, 0.5, 980.0, 210.0)
	streams["hit_laser"] = _make_harmonic_impact(0.1, 0.36, 720.0, 0.08)
	streams["hit_arc"] = _make_harmonic_impact(0.12, 0.38, 430.0, 0.16)
	streams["hit_dash"] = _make_impact(0.09, 0.62, 310.0, 95.0)
	streams["hit_spike"] = _make_impact(0.045, 0.24, 2050.0, 620.0)
	streams["kill_confirm"] = _make_kill_confirm()
	streams["overdrive_kill"] = _make_overdrive_kill_confirm()
	streams["laser_loop"] = _make_laser_loop()
	streams["start"] = _make_tone(360.0, 0.22, 0.18, 0.55, 2.2)
	streams["victory"] = _make_tone(740.0, 0.35, 0.16, 0.55, 1.6)
	streams["defeat"] = _make_tone(120.0, 0.45, 0.2, 0.55, 0.55)
	laser_loop_player = AudioStreamPlayer.new()
	laser_loop_player.stream = streams["laser_loop"]
	laser_loop_player.volume_db = -18.0
	add_child(laser_loop_player)
	for index in range(VOICE_POOL_SIZE):
		var voice := AudioStreamPlayer.new()
		voice.volume_db = -8.0
		add_child(voice)
		voice_pool.append(voice)

func _process(delta: float) -> void:
	for source in hit_cooldowns.keys():
		hit_cooldowns[source] = maxf(0.0, float(hit_cooldowns[source]) - delta)
	kill_confirm_cooldown = maxf(0.0, kill_confirm_cooldown - delta)
	shoot_cooldown = maxf(0.0, shoot_cooldown - delta)

func play_hit(source: StringName, feedback_weight: int = EnemyScript.FeedbackWeight.MEDIUM) -> bool:
	var resolved: StringName = source if hit_stream_names.has(source) else DamageTypes.GENERIC
	if float(hit_cooldowns.get(resolved, 0.0)) > 0.0:
		return false
	hit_cooldowns[resolved] = HIT_COOLDOWN
	play(_get_hit_stream_name(resolved, feedback_weight))
	return true

func play_shot() -> bool:
	if shoot_cooldown > 0.0:
		return false
	shoot_cooldown = SHOOT_COOLDOWN
	play("shoot")
	return true

func play_kill_confirm() -> bool:
	if kill_confirm_cooldown > 0.0:
		return false
	kill_confirm_cooldown = KILL_CONFIRM_COOLDOWN
	play("kill_confirm")
	return true

func play_overdrive_kill() -> bool:
	if kill_confirm_cooldown > 0.0:
		return false
	kill_confirm_cooldown = KILL_CONFIRM_COOLDOWN
	play("overdrive_kill")
	return true

func _get_hit_stream_name(source: StringName, feedback_weight: int) -> String:
	if feedback_weight == EnemyScript.FeedbackWeight.LIGHT:
		return "hit_light"
	if feedback_weight == EnemyScript.FeedbackWeight.HEAVY:
		return "hit_heavy"
	return String(hit_stream_names.get(source, "enemy_hit"))

func set_laser_active(active: bool) -> void:
	if active and not laser_loop_player.playing:
		laser_loop_player.play()
	elif not active and laser_loop_player.playing:
		laser_loop_player.stop()

func play(name: String) -> void:
	if not streams.has(name):
		return
	var voice: AudioStreamPlayer = null
	for candidate in voice_pool:
		if not candidate.playing:
			voice = candidate
			break
	if voice == null:
		voice = voice_pool[voice_cursor]
		voice_cursor = (voice_cursor + 1) % voice_pool.size()
		voice.stop()
	voice.stream = streams[name]
	voice.volume_db = -8.0
	voice.play()

func play_bgm() -> void:
	if bgm_player == null:
		bgm_player = AudioStreamPlayer.new()
		bgm_player.stream = streams["bgm"]
		add_child(bgm_player)
	_apply_bgm_volume()
	if not bgm_player.playing:
		bgm_player.play()

func stop_bgm() -> void:
	if bgm_player != null:
		bgm_player.stop()

func set_bgm_volume(value: float) -> void:
	bgm_volume_linear = clampf(value, 0.0, 1.0)
	_apply_bgm_volume()

func set_bgm_muted(muted: bool) -> void:
	bgm_muted = muted
	_apply_bgm_volume()

func _apply_bgm_volume() -> void:
	if bgm_player == null:
		return
	if bgm_muted or bgm_volume_linear <= 0.001:
		bgm_player.volume_db = -80.0
	else:
		bgm_player.volume_db = linear_to_db(bgm_volume_linear) - 10.0

func _make_tone(freq: float, duration: float, attack: float, volume: float, sweep: float = 1.0) -> AudioStreamWAV:
	var sample_rate := 22050
	var sample_count := int(duration * sample_rate)
	var data := PackedByteArray()
	data.resize(sample_count * 2)
	for i in range(sample_count):
		var t := float(i) / float(sample_rate)
		var progress := float(i) / maxf(1.0, float(sample_count - 1))
		var env := minf(1.0, progress / maxf(0.001, attack)) * (1.0 - progress)
		var current_freq := lerpf(freq, freq * sweep, progress)
		var sample := sin(TAU * current_freq * t) * env * volume
		var value := int(clampf(sample, -1.0, 1.0) * 32767.0)
		data.encode_s16(i * 2, value)
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = sample_rate
	wav.stereo = false
	wav.data = data
	return wav

func _make_gunshot() -> AudioStreamWAV:
	var sample_rate := 22050
	var duration := 0.072
	var sample_count := int(duration * sample_rate)
	var data := PackedByteArray()
	data.resize(sample_count * 2)
	var noise_seed := 0x51A7B00
	for i in range(sample_count):
		noise_seed = int((1103515245 * noise_seed + 12345) & 0x7fffffff)
		var t := float(i) / float(sample_rate)
		var progress := float(i) / maxf(1.0, float(sample_count - 1))
		var attack := minf(1.0, t / 0.0015)
		var noise := (float(noise_seed % 2000) / 1000.0) - 1.0
		var crack := noise * exp(-t * 165.0) * 0.88
		var body_frequency := lerpf(145.0, 72.0, progress)
		var body := sin(TAU * body_frequency * t) * exp(-t * 38.0) * 0.48
		var snap_frequency := lerpf(1180.0, 260.0, progress)
		var snap := sin(TAU * snap_frequency * t) * exp(-t * 62.0) * 0.38
		var sample := (crack + body + snap) * attack * 0.82
		data.encode_s16(i * 2, int(clampf(sample, -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = sample_rate
	wav.stereo = false
	wav.data = data
	return wav

func _make_bgm_loop() -> AudioStreamWAV:
	var sample_rate := 16000
	var total_beats := BGM_BEATS_PER_BAR * BGM_BAR_COUNT
	var seconds_per_beat := 60.0 / BGM_BPM
	var duration := float(total_beats) * seconds_per_beat
	var sample_count := int(duration * sample_rate)
	var data := PackedByteArray()
	data.resize(sample_count * 2)
	var bass_notes := PackedFloat32Array([
		55.0, 55.0, 65.41, 55.0,
		49.0, 55.0, 73.42, 65.41,
		55.0, 82.41, 73.42, 55.0,
		49.0, 55.0, 65.41, 49.0,
	])
	var motif_notes := PackedFloat32Array([220.0, 196.0, 220.0, 246.94])
	var noise_seed := 0x4D3C2B1A
	for i in range(sample_count):
		noise_seed = int((1103515245 * noise_seed + 12345) & 0x7fffffff)
		var t := float(i) / float(sample_rate)
		var beat_position := t / seconds_per_beat
		var beat_index := int(floor(beat_position)) % total_beats
		var beat_phase := fmod(beat_position, 1.0)
		var beat_time := beat_phase * seconds_per_beat
		var bar_beat := beat_index % BGM_BEATS_PER_BAR
		var eighth_position := beat_position * 2.0
		var eighth_index := int(floor(eighth_position)) % bass_notes.size()
		var eighth_phase := fmod(eighth_position, 1.0)
		var eighth_time := eighth_phase * seconds_per_beat * 0.5
		var sixteenth_position := beat_position * 4.0
		var sixteenth_index := int(floor(sixteenth_position)) % 16
		var sixteenth_phase := fmod(sixteenth_position, 1.0)

		var kick_envelope := minf(1.0, beat_phase / 0.012) * exp(-beat_phase * 10.5)
		var kick_frequency := lerpf(165.0, 46.0, minf(1.0, beat_phase * 2.4))
		var kick_body := sin(TAU * kick_frequency * beat_time)
		var kick_click := sin(TAU * 1850.0 * beat_time) * exp(-beat_phase * 52.0)
		var kick_accent := 1.0 if bar_beat in [0, 2] else 0.86
		var kick := clampf((kick_body * 1.5 + kick_click * 0.38) * kick_envelope, -1.0, 1.0) * kick_accent

		var bass_attack := minf(1.0, eighth_phase / 0.035)
		var bass_envelope := bass_attack * pow(1.0 - eighth_phase, 0.72)
		var bass_frequency: float = bass_notes[eighth_index]
		var bass_saw := fmod(bass_frequency * eighth_time, 1.0) * 2.0 - 1.0
		var bass_sub := sin(TAU * bass_frequency * 0.5 * eighth_time)
		var bass_gate := 1.0 if eighth_index not in [3, 7, 11, 15] else 0.28
		var bass := clampf((bass_saw * 0.72 + bass_sub * 0.58) * 1.45, -1.0, 1.0) * bass_envelope * bass_gate

		var noise := (float(noise_seed % 2000) / 1000.0) - 1.0
		var transient_attack := minf(1.0, sixteenth_phase / 0.025)
		var hat_envelope := transient_attack * exp(-sixteenth_phase * (12.0 if sixteenth_index % 4 == 2 else 24.0))
		var metallic := sin(TAU * 3150.0 * t) * 0.55 + sin(TAU * 4725.0 * t) * 0.28
		var hat := (noise * 0.72 + metallic * 0.28) * hat_envelope

		var snare_envelope := minf(1.0, beat_phase / 0.018) * exp(-beat_phase * 16.0) if bar_beat in [1, 3] else 0.0
		var snare_tone := sin(TAU * 190.0 * beat_time) * 0.38
		var snare := (noise * 0.78 + snare_tone) * snare_envelope

		var motif_step := int(floor(beat_position * 0.5)) % 4
		var motif_frequency: float = motif_notes[motif_step]
		var motif_phase := fmod(beat_position * 0.5, 1.0)
		var motif_attack := minf(1.0, motif_phase / 0.08)
		var motif_envelope := motif_attack * pow(1.0 - motif_phase, 1.5)
		var motif_wave := signf(sin(TAU * motif_frequency * t)) * 0.62 + sin(TAU * motif_frequency * 2.0 * t) * 0.18
		var motif := motif_wave * motif_envelope

		var sidechain := lerpf(0.42, 1.0, minf(1.0, beat_phase * 4.8))
		var raw_mix := kick * 0.66 + bass * 0.5 * sidechain + snare * 0.25 + hat * 0.12 + motif * 0.09 * sidechain
		var sample := clampf(raw_mix * 0.92, -0.94, 0.94)
		var value := int(clampf(sample, -1.0, 1.0) * 32767.0)
		data.encode_s16(i * 2, value)
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = sample_rate
	wav.stereo = false
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_begin = 0
	wav.loop_end = sample_count
	wav.data = data
	return wav

func _make_impact(duration: float, volume: float, start_freq: float, end_freq: float) -> AudioStreamWAV:
	var sample_rate := 22050
	var sample_count := int(duration * sample_rate)
	var data := PackedByteArray()
	data.resize(sample_count * 2)
	var noise_seed := 12345
	for i in range(sample_count):
		noise_seed = int((1103515245 * noise_seed + 12345) & 0x7fffffff)
		var t := float(i) / float(sample_rate)
		var progress := float(i) / maxf(1.0, float(sample_count - 1))
		var env := pow(1.0 - progress, 2.2)
		var noise := (float(noise_seed % 2000) / 1000.0) - 1.0
		var sweep_freq := lerpf(start_freq, end_freq, progress)
		var tone := sin(TAU * sweep_freq * t) * 0.55
		var click := sin(TAU * (sweep_freq * 2.1) * t) * (1.0 - progress) * 0.28
		var sample := (noise * 0.45 + tone + click) * env * volume
		var value := int(clampf(sample, -1.0, 1.0) * 32767.0)
		data.encode_s16(i * 2, value)
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = sample_rate
	wav.stereo = false
	wav.data = data
	return wav

func _make_heavy_impact() -> AudioStreamWAV:
	var sample_rate := 22050
	var duration := 0.13
	var sample_count := int(duration * sample_rate)
	var data := PackedByteArray()
	data.resize(sample_count * 2)
	var noise_seed := 0x2F6E2B1
	for i in range(sample_count):
		noise_seed = int((1103515245 * noise_seed + 12345) & 0x7fffffff)
		var t := float(i) / float(sample_rate)
		var progress := float(i) / maxf(1.0, float(sample_count - 1))
		var attack := minf(1.0, t / 0.002)
		var envelope := attack * pow(1.0 - progress, 1.7)
		var frequency := lerpf(180.0, 55.0, progress)
		var low_body := sin(TAU * frequency * t) * 0.72
		var low_harmonic := sin(TAU * frequency * 2.0 * t) * 0.22
		var noise := ((float(noise_seed % 2000) / 1000.0) - 1.0) * exp(-t * 45.0) * 0.28
		var sample := (low_body + low_harmonic + noise) * envelope * 0.74
		data.encode_s16(i * 2, int(clampf(sample, -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = sample_rate
	wav.stereo = false
	wav.data = data
	return wav

func _make_harmonic_impact(duration: float, volume: float, frequency: float, noise_mix: float) -> AudioStreamWAV:
	var sample_rate := 22050
	var sample_count := int(duration * sample_rate)
	var data := PackedByteArray()
	data.resize(sample_count * 2)
	var noise_seed := 24681
	for i in range(sample_count):
		noise_seed = int((1103515245 * noise_seed + 12345) & 0x7fffffff)
		var t := float(i) / float(sample_rate)
		var progress := float(i) / maxf(1.0, float(sample_count - 1))
		var attack := minf(1.0, progress / 0.12)
		var envelope := attack * pow(1.0 - progress, 1.8)
		var harmonic := sin(TAU * frequency * t) + sin(TAU * frequency * 2.0 * t) * 0.36
		var noise := ((float(noise_seed % 2000) / 1000.0) - 1.0) * noise_mix
		data.encode_s16(i * 2, int(clampf((harmonic * 0.55 + noise) * envelope * volume, -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = sample_rate
	wav.stereo = false
	wav.data = data
	return wav

func _make_kill_confirm() -> AudioStreamWAV:
	var sample_rate := 22050
	var duration := 0.12
	var sample_count := int(duration * sample_rate)
	var data := PackedByteArray()
	data.resize(sample_count * 2)
	var noise_seed := 97531
	for i in range(sample_count):
		noise_seed = int((1103515245 * noise_seed + 12345) & 0x7fffffff)
		var t := float(i) / float(sample_rate)
		var progress := float(i) / maxf(1.0, float(sample_count - 1))
		var envelope := pow(1.0 - progress, 2.0)
		var low_frequency := lerpf(230.0, 78.0, progress)
		var low_impact := sin(TAU * low_frequency * t) * 0.72
		var confirm_click := sin(TAU * 1320.0 * t) * exp(-progress * 18.0) * 0.5
		var noise := ((float(noise_seed % 2000) / 1000.0) - 1.0) * exp(-progress * 24.0) * 0.22
		var sample := (low_impact + confirm_click + noise) * envelope * 0.68
		data.encode_s16(i * 2, int(clampf(sample, -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = sample_rate
	wav.stereo = false
	wav.data = data
	return wav

func _make_overdrive_kill_confirm() -> AudioStreamWAV:
	# A short forged-metal hit: a dense low steel contact first, followed by a
	# brighter, slightly detuned ring. It keeps the weight of armor-on-metal
	# without the long medieval tail, so rapid Overdrive kills stay punchy.
	var sample_rate := 22050
	var duration := 0.11
	var sample_count := int(duration * sample_rate)
	var data := PackedByteArray()
	data.resize(sample_count * 2)
	var noise_seed := 0x4F564452
	for i in range(sample_count):
		noise_seed = int((1103515245 * noise_seed + 12345) & 0x7fffffff)
		var t := float(i) / float(sample_rate)
		var attack := minf(1.0, t / 0.0012)
		var impact_envelope := attack * exp(-t * 58.0)
		var ring_time := maxf(0.0, t - 0.006)
		var ring_attack := minf(1.0, ring_time / 0.0025)
		var ring_envelope := ring_attack * exp(-ring_time * 24.0)
		var noise := (float(noise_seed % 2000) / 1000.0) - 1.0
		var steel_body := (
			sin(TAU * 390.0 * t) * 0.7
			+ sin(TAU * 780.0 * t) * 0.3
		) * impact_envelope
		var contact := noise * exp(-t * 150.0) * 0.28
		var bright_ring := (
			sin(TAU * 2480.0 * ring_time) * 0.7
			+ sin(TAU * 3725.0 * ring_time) * 0.31
			+ sin(TAU * 5140.0 * ring_time) * 0.15
		) * ring_envelope
		var sample := (steel_body + contact + bright_ring) * 0.78
		data.encode_s16(i * 2, int(clampf(sample, -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = sample_rate
	wav.stereo = false
	wav.data = data
	return wav

func _make_laser_loop() -> AudioStreamWAV:
	var sample_rate := 22050
	var duration := 1.0
	var sample_count := int(duration * sample_rate)
	var data := PackedByteArray()
	data.resize(sample_count * 2)
	for i in range(sample_count):
		var t := float(i) / float(sample_rate)
		var modulation := 0.82 + 0.18 * sin(TAU * 3.0 * t)
		var harmonics := sin(TAU * 180.0 * t) * 0.55 + sin(TAU * 360.0 * t) * 0.28 + sin(TAU * 540.0 * t) * 0.12
		data.encode_s16(i * 2, int(clampf(harmonics * modulation * 0.22, -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = sample_rate
	wav.stereo = false
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_begin = 0
	wav.loop_end = sample_count
	wav.data = data
	return wav
