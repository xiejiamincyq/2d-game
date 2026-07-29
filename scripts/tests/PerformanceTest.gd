extends SceneTree

const AudioManagerScript = preload("res://scripts/systems/AudioManager.gd")
const DamageTypes = preload("res://scripts/components/DamageTypes.gd")
const WaveDirectorScript = preload("res://scripts/systems/WaveDirector.gd")
const EnemyScript = preload("res://scripts/actors/Enemy.gd")
const PlayerScript = preload("res://scripts/actors/Player.gd")
const BossProjectilePatternScript = preload("res://scripts/components/BossProjectilePattern.gd")
const CombatVfxScript = preload("res://scripts/effects/CombatVfx.gd")
const TestSupport = preload("res://scripts/tests/TestSupport.gd")

var assertions := 0
var provider_calls := 0
var provided_enemies: Array[Node] = []

class StressEnemy:
	extends Node2D
	var damage_taken := 0.0

	func take_damage(amount: float, _source: StringName = &"generic") -> bool:
		damage_taken += amount
		return false

func _assert_true(condition: bool, message: String) -> bool:
	assertions += 1
	if condition:
		return true
	push_error("TEST FAIL: PerformanceTest: " + message)
	quit(1)
	return false

func _initialize() -> void:
	await process_frame
	var baseline_node_count := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
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
	if not _assert_true(audio.has_method("play_shot"), "audio manager does not expose bounded gunshot playback"):
		return
	if not audio.play_shot() or audio.play_shot():
		_assert_true(false, "gunshot playback did not accept one shot and throttle the immediate duplicate")
		return
	audio._process(0.02)
	if not _assert_true(audio.play_shot(), "gunshot playback did not recover after its cooldown"):
		return
	for index in range(100):
		audio._process(0.1)
		audio.play_hit(DamageTypes.ALL[index % DamageTypes.ALL.size()])
		audio.play_kill_confirm()
	if not _assert_true(audio.get_child_count() == audio_children_before, "100 hit/kill cues grew audio nodes from %d to %d" % [audio_children_before, audio.get_child_count()]):
		return
	for index in range(100):
		audio._process(0.05)
		audio.play_boss_cue(&"boss_barrage")
		audio.play_boss_cue(&"boss_tentacle")
		audio.play_boss_cue(&"boss_phase")
		audio.play_boss_cue(&"boss_transition")
	if not _assert_true(audio.get_child_count() == audio_children_before, "400 boss cues grew audio nodes from %d to %d" % [audio_children_before, audio.get_child_count()]):
		return

	var fixture := Node.new()
	root.add_child(fixture)
	var player := Node2D.new()
	var enemies := Node2D.new()
	var projectiles := Node2D.new()
	var portals := Node2D.new()
	var director: Node = WaveDirectorScript.new()
	fixture.add_child(player)
	fixture.add_child(enemies)
	fixture.add_child(projectiles)
	fixture.add_child(portals)
	fixture.add_child(director)
	director.set_process(false)
	director.player = player
	director.enemy_parent = enemies
	director.projectile_parent = projectiles
	director.world_bounds = Rect2(-1400, -900, 2800, 1800)
	director.wave_index = 4
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

	var automation_player: Node = PlayerScript.new()
	automation_player.set_physics_process(false)
	fixture.add_child(automation_player)
	automation_player.projectile_parent = projectiles
	automation_player.drone_count = 4
	automation_player.drone_laser_piercing = true
	provided_enemies.clear()
	for index in range(250):
		var stress_enemy := StressEnemy.new()
		stress_enemy.position = Vector2(index % 25, index / 25) * 24.0
		fixture.add_child(stress_enemy)
		provided_enemies.append(stress_enemy)
	automation_player.set_enemy_provider(_provide_stress_enemies)
	provider_calls = 0
	var targeting_started := Time.get_ticks_usec()
	for frame in range(300):
		automation_player._update_passives(1.0 / 60.0)
	var targeting_ms := float(Time.get_ticks_usec() - targeting_started) / 1000.0
	if not _assert_true(provider_calls == 300, "four drones fetched/copied the enemy registry %d times for 300 frames instead of once per frame" % provider_calls):
		return

	var pattern_target := Node2D.new()
	var boss_projectiles := Node2D.new()
	var pattern: Node2D = BossProjectilePatternScript.new()
	fixture.add_child(pattern_target)
	fixture.add_child(boss_projectiles)
	fixture.add_child(pattern)
	pattern_target.position = Vector2(420.0, 0.0)
	pattern.configure(boss_projectiles, Rect2(-900.0, -600.0, 1800.0, 1200.0), pattern_target, 912, 4401)
	pattern.set_process(false)
	pattern.start_pattern(&"broken_ring")
	pattern.advance(2.5)
	var spawned_boss_projectiles := boss_projectiles.get_child_count()
	for projectile in boss_projectiles.get_children():
		projectile.queue_free()
	await process_frame
	if not _assert_true(spawned_boss_projectiles > 0, "Boss projectile stress fixture did not emit projectiles"):
		return
	if not _assert_true((pattern.get("_spawned_projectiles") as Array).is_empty(), "naturally freed Boss projectiles remained in the controller tracking array"):
		return

	director.portal_parent = portals
	director.spawn_rng.seed = 7712
	var abandoned_queues: Array[Array] = [[EnemyScript.EnemyKind.SCRAPPER]]
	director._open_portals_for_queues(abandoned_queues)
	var abandoned_portal: Node = director.active_portals[0]
	var abandoned_portal_id := abandoned_portal.get_instance_id()
	abandoned_portal.queue_free()
	await process_frame
	if not _assert_true(
		not director.portal_spawn_queues.has(abandoned_portal_id)
		and not director.portal_spawn_timers.has(abandoned_portal_id)
		and director.active_portals.is_empty(),
		"a portal removed outside its normal close path retained queue/timer state"
	):
		return

	var portal_results: Array[Dictionary] = []
	for frames_per_second in [30, 60, 120]:
		portal_results.append(await _simulate_max_portal_attack(frames_per_second))
		var result: Dictionary = portal_results[-1]
		if not _assert_true(int(result.spawned) == 250, "%dHz max portal attack spawned %d of 250 enemies" % [frames_per_second, result.spawned]):
			return
		if not _assert_true(int(result.portals) == 0 and int(result.queue_entries) == 0 and int(result.timer_entries) == 0, "%dHz max portal attack retained portal state" % frames_per_second):
			return
	if not _assert_true(
		int(portal_results[0].spawned) == int(portal_results[1].spawned)
		and int(portal_results[0].spawned) == int(portal_results[2].spawned),
		"max portal generation changed between 30/60/120Hz"
	):
		return

	var vfx: Node = CombatVfxScript.new()
	fixture.add_child(vfx)
	for index in range(500):
		vfx.request_effect(vfx.SPARK, Vector2(index, 0.0))
		vfx.request_effect(vfx.DEBRIS, Vector2(index, 0.0))
		vfx.request_effect(vfx.RING, Vector2(index, 0.0))
		vfx.request_effect(vfx.AFTERIMAGE, Vector2(index, 0.0))
	if not _assert_true(
		vfx.get_effect_count(vfx.SPARK) == vfx.MAX_SPARKS
		and vfx.get_effect_count(vfx.DEBRIS) == vfx.MAX_DEBRIS
		and vfx.get_effect_count(vfx.RING) == vfx.MAX_RINGS
		and vfx.get_effect_count(vfx.AFTERIMAGE) == vfx.MAX_AFTERIMAGES,
		"combat VFX exceeded or failed to fill its bounded record capacities"
	):
		return
	vfx._process(1.0)
	if not _assert_true(vfx.get_total_effect_count() == 0, "expired combat VFX records were not released"):
		return

	var node_count := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	var audio_players := 0
	for child in audio.get_children():
		if child is AudioStreamPlayer:
			audio_players += 1
	print(
		"PERFORMANCE: registry_1000_lookups_ms=%.3f drone_targeting_300_frames_ms=%.3f portal_250_ms=[%.3f,%.3f,%.3f] nodes=%d audio_players=%d"
		% [
			lookup_ms,
			targeting_ms,
			float(portal_results[0].elapsed_ms),
			float(portal_results[1].elapsed_ms),
			float(portal_results[2].elapsed_ms),
			node_count,
			audio_players,
		]
	)

	fixture.queue_free()
	TestSupport.stop_audio(audio)
	await create_timer(0.25).timeout
	audio.queue_free()
	await process_frame
	await process_frame
	provided_enemies.clear()
	await process_frame
	var released_node_count := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	if not _assert_true(released_node_count <= baseline_node_count, "stress fixtures retained nodes: baseline=%d released=%d" % [baseline_node_count, released_node_count]):
		return
	print("TEST PASS: PerformanceTest %d" % assertions)
	quit(0)

func _provide_stress_enemies() -> Array[Node]:
	provider_calls += 1
	return provided_enemies

func _simulate_max_portal_attack(frames_per_second: int) -> Dictionary:
	var stress_fixture := Node2D.new()
	var stress_player := Node2D.new()
	var stress_enemies := Node2D.new()
	var stress_projectiles := Node2D.new()
	var stress_portals := Node2D.new()
	var stress_director: Node = WaveDirectorScript.new()
	root.add_child(stress_fixture)
	stress_fixture.add_child(stress_player)
	stress_fixture.add_child(stress_enemies)
	stress_fixture.add_child(stress_projectiles)
	stress_fixture.add_child(stress_portals)
	stress_fixture.add_child(stress_director)
	stress_director.set_process(false)
	stress_director.player = stress_player
	stress_director.enemy_parent = stress_enemies
	stress_director.projectile_parent = stress_projectiles
	stress_director.portal_parent = stress_portals
	stress_director.world_bounds = Rect2(-2400.0, -1600.0, 4800.0, 3200.0)
	stress_director.wave_index = 4
	stress_director.spawn_rng.seed = 91270
	var queues: Array[Array] = []
	for portal_index in range(5):
		var queue: Array = []
		for enemy_index in range(50):
			queue.append(EnemyScript.EnemyKind.SCRAPPER)
		queues.append(queue)
	stress_director._open_portals_for_queues(queues)
	var started := Time.get_ticks_usec()
	var delta := 1.0 / float(frames_per_second)
	for frame in range(ceili(11.0 * frames_per_second)):
		stress_director._process_portal_attack(delta)
	var elapsed_ms := float(Time.get_ticks_usec() - started) / 1000.0
	var result := {
		"spawned": stress_enemies.get_child_count(),
		"portals": stress_director.active_portals.size(),
		"queue_entries": stress_director.portal_spawn_queues.size(),
		"timer_entries": stress_director.portal_spawn_timers.size(),
		"elapsed_ms": elapsed_ms,
	}
	stress_fixture.queue_free()
	await process_frame
	await process_frame
	return result
