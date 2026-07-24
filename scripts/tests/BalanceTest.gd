extends SceneTree

const DamageTypes = preload("res://scripts/components/DamageTypes.gd")
const EnemyScript = preload("res://scripts/actors/Enemy.gd")
const OverseerBossScript = preload("res://scripts/actors/OverseerBoss.gd")
const AudioManagerScript = preload("res://scripts/systems/AudioManager.gd")
const UpgradeSystemScript = preload("res://scripts/systems/UpgradeSystem.gd")
const TestSupport = preload("res://scripts/tests/TestSupport.gd")

func _fail(message: String) -> void:
	push_error("BalanceTest failed: " + message)
	quit(1)

func _initialize() -> void:
	var enemy: Node = EnemyScript.new()
	enemy.setup(EnemyScript.EnemyKind.SCRAPPER, 1, root)
	root.add_child(enemy)
	await process_frame
	var received := {"source": &""}
	enemy.hit.connect(func(source: StringName) -> void: received["source"] = source)
	enemy.take_damage(1.0, DamageTypes.LASER)
	if received["source"] != DamageTypes.LASER:
		_fail("enemy hit signal did not preserve the damage source.")
		return

	var audio: Node = AudioManagerScript.new()
	root.add_child(audio)
	await process_frame
	var gunshot := audio.streams.get("shoot") as AudioStreamWAV
	if gunshot == null:
		_fail("procedural gunshot stream is missing.")
		return
	var gunshot_duration := float(gunshot.data.size() / 2) / float(gunshot.mix_rate)
	if gunshot_duration < 0.06 or gunshot_duration > 0.09:
		_fail("gunshot duration %.3fs escaped the 0.06-0.09s ballistic window." % gunshot_duration)
		return
	var segment_samples := maxi(1, int(float(gunshot.mix_rate) * 0.01))
	var early_square_sum := 0.0
	var tail_square_sum := 0.0
	for sample_index in range(segment_samples):
		var early_sample := float(gunshot.data.decode_s16(sample_index * 2)) / 32767.0
		var tail_byte_index := gunshot.data.size() - (segment_samples - sample_index) * 2
		var tail_sample := float(gunshot.data.decode_s16(tail_byte_index)) / 32767.0
		early_square_sum += early_sample * early_sample
		tail_square_sum += tail_sample * tail_sample
	var early_rms := sqrt(early_square_sum / float(segment_samples))
	var tail_rms := sqrt(tail_square_sum / float(segment_samples))
	if early_rms < 0.18 or early_rms < tail_rms * 2.5:
		_fail("gunshot envelope lacks a strong crack and fast tail decay (early %.3f, tail %.3f)." % [early_rms, tail_rms])
		return
	var light_hit := audio.streams.get("hit_light") as AudioStreamWAV
	var heavy_hit := audio.streams.get("hit_heavy") as AudioStreamWAV
	if light_hit == null or heavy_hit == null or light_hit == heavy_hit:
		_fail("light and heavy enemy hit profiles are not distinct WAV streams.")
		return
	var light_duration := float(light_hit.data.size() / 2) / float(light_hit.mix_rate)
	var heavy_duration := float(heavy_hit.data.size() / 2) / float(heavy_hit.mix_rate)
	if light_duration > 0.055 or heavy_duration < 0.12 or heavy_duration > 0.14:
		_fail("enemy weight hit durations are outside their light/heavy windows (%.3f/%.3f)." % [light_duration, heavy_duration])
		return
	if audio.get("bgm_profile_id") != &"industrial_hardcore_168":
		_fail("BGM did not select the industrial hardcore 168 BPM profile.")
		return
	var bgm := audio.streams.get("bgm") as AudioStreamWAV
	if bgm == null or bgm.loop_mode != AudioStreamWAV.LOOP_FORWARD or bgm.loop_begin != 0 or bgm.loop_end <= 0:
		_fail("hardcore BGM is not configured as a full seamless forward loop.")
		return
	var expected_duration := 32.0 * 60.0 / 168.0
	var actual_duration := float(bgm.loop_end) / float(bgm.mix_rate)
	if absf(actual_duration - expected_duration) > 0.001:
		_fail("hardcore BGM loop duration %.4f did not preserve eight 4/4 bars at 168 BPM." % actual_duration)
		return
	var loop_start_sample := float(bgm.data.decode_s16(0)) / 32767.0
	var loop_end_sample := float(bgm.data.decode_s16(bgm.data.size() - 2)) / 32767.0
	if absf(loop_start_sample) > 0.03 or absf(loop_end_sample) > 0.03 or absf(loop_end_sample - loop_start_sample) > 0.03:
		_fail("hardcore BGM loop boundary would produce an audible click.")
		return
	var peak := 0.0
	var square_sum := 0.0
	var sampled := 0
	for byte_index in range(0, bgm.data.size() - 1, 8):
		var sample := float(bgm.data.decode_s16(byte_index)) / 32767.0
		peak = maxf(peak, absf(sample))
		square_sum += sample * sample
		sampled += 1
	var rms := sqrt(square_sum / maxf(1.0, float(sampled)))
	if peak < 0.55 or peak > 0.98 or rms < 0.12 or rms > 0.42:
		_fail("hardcore BGM loudness escaped the safe impact window (peak %.3f, RMS %.3f)." % [peak, rms])
		return
	if audio.streams.has("enemy_death"):
		_fail("enemy death audio stream is still configured.")
		return
	var expected_sources: Array[StringName] = [
		DamageTypes.PROJECTILE,
		DamageTypes.LASER,
		DamageTypes.ARC,
		DamageTypes.DASH,
		DamageTypes.SPIKE,
	]
	if DamageTypes.ALL != expected_sources:
		_fail("damage source collection does not contain exactly the five requested sources in order.")
		return
	for source in expected_sources:
		if not audio.hit_stream_names.has(source):
			_fail("missing source-specific hit stream for %s." % source)
			return
	var child_count_before: int = audio.get_child_count()
	if not audio.play_hit(DamageTypes.PROJECTILE):
		_fail("first projectile hit was unexpectedly throttled.")
		return
	if audio.play_hit(DamageTypes.PROJECTILE):
		_fail("repeated projectile hit was not throttled.")
		return
	if not audio.play_hit(DamageTypes.ARC):
		_fail("one hit category blocked another category.")
		return
	if audio.get_child_count() != child_count_before:
		_fail("hit playback grew the fixed audio voice pool.")
		return
	var unknown_source: StringName = &"unknown_test_source"
	if not audio.hit_stream_names.has(DamageTypes.GENERIC) or audio.hit_stream_names.has(unknown_source):
		_fail("generic fallback stream mapping is missing or the unknown test source was explicitly configured.")
		return
	var fallback_child_count_before: int = audio.get_child_count()
	if not audio.play_hit(unknown_source):
		_fail("unknown hit source did not play through the generic fallback.")
		return
	if audio.get_child_count() != fallback_child_count_before:
		_fail("generic fallback grew the fixed audio voice pool.")
		return
	var loop_player: AudioStreamPlayer = audio.laser_loop_player
	audio.set_laser_active(true)
	if not loop_player.playing:
		_fail("laser loop did not start.")
		return
	audio.set_laser_active(false)
	if loop_player.playing or audio.laser_loop_player != loop_player:
		_fail("laser loop did not stop cleanly on the reusable player.")
		return

	var fake_player := Node.new()
	root.add_child(fake_player)
	var upgrades: Node = UpgradeSystemScript.new()
	root.add_child(upgrades)
	upgrades.setup(fake_player)
	if not upgrades.add_coins(40) or not upgrades.spend_coins(15) or upgrades.coins != 25:
		_fail("coin economy did not preserve a deterministic non-negative balance.")
		return
	if upgrades.spend_coins(26) or upgrades.coins != 25:
		_fail("coin economy accepted an unaffordable purchase.")
		return

	var enemy_kinds: Array[int] = [
		EnemyScript.EnemyKind.SCRAPPER,
		EnemyScript.EnemyKind.DASHER,
		EnemyScript.EnemyKind.SPITTER,
		EnemyScript.EnemyKind.BRUISER,
	]
	var base_coin_values: Array[int] = [1, 2, 3, 8]
	var expected_feedback_weights: Array[int] = [
		EnemyScript.FeedbackWeight.MEDIUM,
		EnemyScript.FeedbackWeight.LIGHT,
		EnemyScript.FeedbackWeight.LIGHT,
		EnemyScript.FeedbackWeight.HEAVY,
	]
	var wave_enemies: Array[Node] = []
	for kind_index in range(enemy_kinds.size()):
		for wave_index in range(1, 9):
			var wave_enemy: Node = EnemyScript.new()
			wave_enemy.setup(enemy_kinds[kind_index], wave_index, root)
			root.add_child(wave_enemy)
			wave_enemies.append(wave_enemy)
			var actual_feedback_weight: Variant = wave_enemy.get("feedback_weight")
			if actual_feedback_weight != expected_feedback_weights[kind_index]:
				_fail("enemy kind %d has feedback weight %s instead of %d." % [enemy_kinds[kind_index], actual_feedback_weight, expected_feedback_weights[kind_index]])
				return
			var expected_coins: int = base_coin_values[kind_index]
			if wave_enemy.coin_value != expected_coins:
				_fail("enemy kind %d wave %d coin value was %d instead of %d." % [enemy_kinds[kind_index], wave_index, wave_enemy.coin_value, expected_coins])
				return
			if enemy_kinds[kind_index] == EnemyScript.EnemyKind.BRUISER and wave_index == 2:
				if not is_equal_approx(wave_enemy.health.max_health, 378.0):
					_fail("wave-two Bruiser health %.2f did not equal the 378 combat-weight target." % wave_enemy.health.max_health)
					return
				var base_weapon_ttk: float = wave_enemy.health.max_health / (10.0 * 13.0)
				if base_weapon_ttk < 2.7 or base_weapon_ttk > 3.1:
					_fail("wave-two Bruiser base-weapon TTK %.3fs escaped the 2.7-3.1s target." % base_weapon_ttk)
					return

	var boss_max_health: float = OverseerBossScript.BASE_MAX_HEALTH
	if boss_max_health < 9000.0 or boss_max_health > 12000.0:
		_fail("Boss max health %.1f escaped the 9000-12000 tuning band." % boss_max_health)
		return
	var standard_weapon_damage := 10.0 * pow(1.12, 2.0)
	var standard_fire_rate := 13.0 * pow(1.10, 2.0)
	var standard_build_dps := standard_weapon_damage * standard_fire_rate
	var boss_ttk := boss_max_health / standard_build_dps
	if boss_ttk < 45.0 or boss_ttk > 65.0:
		_fail("standard-build Boss TTK %.2fs escaped the 45-65s target (dps %.2f)." % [boss_ttk, standard_build_dps])
		return
	var boss_cues: Array = ["boss_phase", "boss_transition", "boss_tentacle", "boss_barrage", "boss_death"]
	var seen_boss_streams: Dictionary = {}
	for cue in boss_cues:
		var cue_stream := audio.streams.get(cue) as AudioStreamWAV
		if cue_stream == null:
			_fail("Boss cue stream %s is missing or not a WAV stream." % cue)
			return
		if seen_boss_streams.has(cue_stream):
			_fail("Boss cue stream %s reuses another cue's stream." % cue)
			return
		seen_boss_streams[cue_stream] = true
	if not audio.has_method("play_boss_cue"):
		_fail("audio manager does not expose play_boss_cue.")
		return
	if not audio.play_boss_cue(&"boss_phase"):
		_fail("first boss phase cue was unexpectedly rejected.")
		return
	if audio.play_boss_cue(&"boss_unknown_cue"):
		_fail("unknown boss cue was accepted instead of a safe no-op.")
		return
	if not audio.play_boss_cue(&"boss_tentacle"):
		_fail("first tentacle cue was unexpectedly throttled.")
		return
	if audio.play_boss_cue(&"boss_tentacle"):
		_fail("repeated tentacle cue was not throttled.")
		return
	var boss_cue_children_before: int = audio.get_child_count()
	audio.play_boss_cue(&"boss_barrage")
	audio.play_boss_cue(&"boss_transition")
	audio.play_boss_cue(&"boss_death")
	if audio.get_child_count() != boss_cue_children_before:
		_fail("boss cue playback grew the fixed audio voice pool.")
		return
	enemy.queue_free()
	bgm = null
	TestSupport.stop_audio(audio)
	await create_timer(0.25).timeout
	audio.queue_free()
	upgrades.queue_free()
	fake_player.queue_free()
	for wave_enemy in wave_enemies:
		wave_enemy.queue_free()
	await process_frame
	await process_frame
	await create_timer(0.1).timeout
	print("TEST PASS: BalanceTest 89")
	quit(0)
