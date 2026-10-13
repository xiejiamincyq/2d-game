extends RefCounted

# Project-authored PCM; no sampled audio or external asset is used.
static func build() -> AudioStreamWAV:
	const SAMPLE_RATE := 22050
	const SAMPLE_COUNT := 3969
	var data := PackedByteArray()
	data.resize(SAMPLE_COUNT * 2)
	var noise_seed := 0x3C71A29
	var previous_noise := 0.0
	var body_phase := 0.0
	for i in range(SAMPLE_COUNT):
		noise_seed = int((1103515245 * noise_seed + 12345) & 0x7fffffff)
		var t := float(i) / SAMPLE_RATE
		var progress := float(i) / (SAMPLE_COUNT - 1)
		var noise := float(noise_seed % 2000) / 1000.0 - 1.0
		var high_noise := (noise - previous_noise) * 0.5
		previous_noise = noise
		body_phase += TAU * lerpf(230.0, 70.0, progress) / SAMPLE_RATE
		var body := sin(body_phase) * exp(-t * 28.0) * 0.42
		var crack := high_noise * exp(-t * 85.0) * 0.52
		# Two quiet delayed fractures give a crunchy tail, not a long blast.
		for onset in [0.014, 0.038]:
			var age: float = t - onset
			if age >= 0.0:
				crack += high_noise * minf(1.0, age / 0.0015) * exp(-age * 125.0) * 0.22
		var envelope := minf(1.0, t / 0.002) * pow(1.0 - progress, 2.0)
		var sample := (body + crack) * envelope * 0.76
		data.encode_s16(i * 2, int(clampf(sample, -0.84, 0.84) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = SAMPLE_RATE
	wav.stereo = false
	wav.data = data
	wav.set_meta(&"origin", "project-original-synthesis-v1")
	return wav
