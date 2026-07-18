extends Node
class_name AudioManager

const DamageTypes = preload("res://scripts/components/DamageTypes.gd")
const HIT_COOLDOWN := 0.055
const KILL_CONFIRM_COOLDOWN := 0.045
const VOICE_POOL_SIZE := 16

var streams: Dictionary = {}
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
var laser_loop_player: AudioStreamPlayer
var voice_pool: Array[AudioStreamPlayer] = []
var voice_cursor: int = 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	streams["bgm"] = _make_bgm_loop()
	streams["shoot"] = _make_tone(660.0, 0.035, 0.18, 0.35)
	streams["xp"] = _make_tone(920.0, 0.06, 0.1, 0.3)
	streams["upgrade"] = _make_tone(520.0, 0.18, 0.22, 0.45, 1.8)
	streams["hit"] = _make_tone(180.0, 0.05, 0.18, 0.32)
	streams["enemy_hit"] = _make_impact(0.075, 0.58, 820.0, 0.42)
	streams["hit_projectile"] = _make_impact(0.055, 0.5, 980.0, 210.0)
	streams["hit_laser"] = _make_harmonic_impact(0.1, 0.36, 720.0, 0.08)
	streams["hit_arc"] = _make_harmonic_impact(0.12, 0.38, 430.0, 0.16)
	streams["hit_dash"] = _make_impact(0.09, 0.62, 310.0, 95.0)
	streams["hit_spike"] = _make_impact(0.07, 0.48, 1450.0, 360.0)
	streams["kill_confirm"] = _make_kill_confirm()
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

func play_hit(source: StringName) -> bool:
	var resolved: StringName = source if hit_stream_names.has(source) else DamageTypes.GENERIC
	if float(hit_cooldowns.get(resolved, 0.0)) > 0.0:
		return false
	hit_cooldowns[resolved] = HIT_COOLDOWN
	play(String(hit_stream_names.get(resolved, "enemy_hit")))
	return true

func play_kill_confirm() -> bool:
	if kill_confirm_cooldown > 0.0:
		return false
	kill_confirm_cooldown = KILL_CONFIRM_COOLDOWN
	play("kill_confirm")
	return true

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

func _make_bgm_loop() -> AudioStreamWAV:
	var sample_rate := 22050
	var duration := 8.0
	var sample_count := int(duration * sample_rate)
	var data := PackedByteArray()
	data.resize(sample_count * 2)
	for i in range(sample_count):
		var t := float(i) / float(sample_rate)
		var beat := int(floor(t * 4.0)) % 16
		var beat_phase := fmod(t * 4.0, 1.0)
		var pulse := exp(-beat_phase * 10.0)
		var kick := sin(TAU * lerpf(88.0, 42.0, minf(1.0, beat_phase * 2.0)) * t) * pulse
		var bass_gate := 0.55 if beat in [0, 3, 6, 8, 11, 14] else 0.22
		var bass := sin(TAU * 55.0 * t) * bass_gate
		var arp_notes := PackedFloat32Array([220.0, 277.0, 330.0, 415.0])
		var arp_step: float = arp_notes[int(floor(t * 8.0)) % 4]
		var arp := sin(TAU * arp_step * t) * 0.16
		var shimmer := sin(TAU * 1320.0 * t) * 0.035 * (0.35 + pulse)
		var envelope := 0.82 + sin(TAU * t / duration) * 0.02
		var sample := (kick * 0.58 + bass * 0.34 + arp + shimmer) * envelope * 0.34
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
