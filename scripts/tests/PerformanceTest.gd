extends SceneTree

const AudioManagerScript = preload("res://scripts/systems/AudioManager.gd")
const DamageTypes = preload("res://scripts/components/DamageTypes.gd")
const WaveDirectorScript = preload("res://scripts/systems/WaveDirector.gd")
const EnemyScript = preload("res://scripts/actors/Enemy.gd")
const TestSupport = preload("res://scripts/tests/TestSupport.gd")

var assertions := 0

func _assert_true(condition: bool, message: String) -> bool:
	assertions += 1
	if condition:
		return true
	push_error("TEST FAIL: PerformanceTest: " + message)
	quit(1)
	return false

func _initialize() -> void:
	var player_source := FileAccess.get_file_as_string("res://scripts/actors/Player.gd")
	if not _assert_true(player_source.count('get_nodes_in_group("enemies")') <= 1, "Player still performs repeated enemy group scans"):
		return
	for path in [
		"res://scripts/components/Projectile.gd",
		"res://scripts/pickups/CoinPickup.gd",
		"res://scripts/pickups/ShieldPickup.gd",
	]:
		var source := FileAccess.get_file_as_string(path)
		if not _assert_true(source.find("queue_redraw()") == -1, "%s redraws a static visual every frame" % path):
			return
	var enemy_source := FileAccess.get_file_as_string("res://scripts/actors/Enemy.gd").replace("\r\n", "\n")
	var conditional_redraw := "\tif flash_timer > 0.0:\n\t\tflash_timer = maxf(0.0, flash_timer - delta)\n\t\tqueue_redraw()"
	if not _assert_true(enemy_source.find(conditional_redraw) != -1, "Enemy redraw is not gated by its flash state"):
		return

	var audio: Node = AudioManagerScript.new()
	root.add_child(audio)
	await process_frame
	var audio_children_before: int = audio.get_child_count()
	for index in range(100):
		audio._process(0.1)
		audio.play_hit(DamageTypes.ALL[index % DamageTypes.ALL.size()])
		audio.play_kill_confirm()
	if not _assert_true(audio.get_child_count() == audio_children_before, "100 hit/kill cues grew audio nodes from %d to %d" % [audio_children_before, audio.get_child_count()]):
		return

	var fixture := Node.new()
	root.add_child(fixture)
	var player := Node2D.new()
	var enemies := Node2D.new()
	var projectiles := Node2D.new()
	var director: Node = WaveDirectorScript.new()
	fixture.add_child(player)
	fixture.add_child(enemies)
	fixture.add_child(projectiles)
	fixture.add_child(director)
	director.set_process(false)
	director.player = player
	director.enemy_parent = enemies
	director.projectile_parent = projectiles
	director.world_bounds = Rect2(-1400, -900, 2800, 1800)
	director.wave_index = 7
	for index in range(250):
		director._spawn_enemy(EnemyScript.EnemyKind.SCRAPPER)
	var registry: Variant = director.get("active_enemies")
	if not _assert_true(registry is Array, "WaveDirector did not expose an active enemy registry"):
		return
	if not _assert_true(registry.size() == 250, "enemy registry contained %d of 250 enemies" % registry.size()):
		return
	var lookup_started := Time.get_ticks_usec()
	for index in range(1000):
		director.get_active_enemies()
	var lookup_ms := float(Time.get_ticks_usec() - lookup_started) / 1000.0
	for index in range(125):
		registry[index].queue_free()
	await process_frame
	if not _assert_true(registry.size() == 125, "enemy registry did not shrink on tree exit"):
		return

	var node_count := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	var audio_players := 0
	for child in audio.get_children():
		if child is AudioStreamPlayer:
			audio_players += 1
	print("PERFORMANCE: registry_1000_lookups_ms=%.3f nodes=%d audio_players=%d" % [lookup_ms, node_count, audio_players])

	fixture.queue_free()
	TestSupport.stop_audio(audio)
	await create_timer(0.25).timeout
	audio.queue_free()
	await process_frame
	await process_frame
	print("TEST PASS: PerformanceTest %d" % assertions)
	quit(0)
