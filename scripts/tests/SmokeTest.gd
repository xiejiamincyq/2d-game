extends SceneTree

func _initialize() -> void:
	var scene: Node = load("res://scenes/Main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	scene._start_run()
	await process_frame
	if scene.world.process_mode != Node.PROCESS_MODE_PAUSABLE:
		push_error("SmokeTest failed: world is not pausable.")
		quit(1)
		return
	if scene.player.process_mode != Node.PROCESS_MODE_PAUSABLE:
		push_error("SmokeTest failed: player is not pausable.")
		quit(1)
		return
	if scene.wave_director.process_mode != Node.PROCESS_MODE_PAUSABLE:
		push_error("SmokeTest failed: wave director is not pausable.")
		quit(1)
		return
	if not scene.audio.streams.has("bgm") or scene.audio.bgm_player == null or not scene.audio.bgm_player.playing:
		push_error("SmokeTest failed: BGM did not start with the run.")
		quit(1)
		return
	if scene.ui.bgm_volume_slider == null or scene.ui.bgm_toggle_button == null:
		push_error("SmokeTest failed: BGM controls were not created.")
		quit(1)
		return
	scene.ui.bgm_volume_slider.value = 35.0
	scene.ui.bgm_volume_slider.value_changed.emit(35.0)
	if absf(scene.audio.bgm_volume_linear - 0.35) > 0.01:
		push_error("SmokeTest failed: BGM volume slider did not update audio volume.")
		quit(1)
		return
	scene.ui.bgm_toggle_button.button_pressed = true
	scene.ui.bgm_toggle_button.toggled.emit(true)
	if not scene.audio.bgm_muted or scene.audio.bgm_player.volume_db > -70.0:
		push_error("SmokeTest failed: BGM mute button did not mute music.")
		quit(1)
		return
	scene.ui.bgm_toggle_button.button_pressed = false
	scene.ui.bgm_toggle_button.toggled.emit(false)
	if scene.audio.bgm_muted:
		push_error("SmokeTest failed: BGM mute button did not unmute music.")
		quit(1)
		return
	var enemy_script = load("res://scripts/actors/Enemy.gd")
	var projectile_script = load("res://scripts/components/Projectile.gd")
	if not scene.has_method("get_world_bounds"):
		push_error("SmokeTest failed: main scene does not expose world bounds.")
		quit(1)
		return
	var bounds: Rect2 = scene.get_world_bounds()
	scene.player.global_position = bounds.position - Vector2(200, 160)
	scene._enforce_world_bounds()
	if not bounds.has_point(scene.player.global_position):
		push_error("SmokeTest failed: player was not clamped inside world bounds.")
		quit(1)
		return
	var boundary_enemy: CharacterBody2D = enemy_script.new()
	boundary_enemy.global_position = bounds.end + Vector2(320, 260)
	boundary_enemy.setup(enemy_script.EnemyKind.SCRAPPER, 1, scene.projectiles)
	scene.enemies.add_child(boundary_enemy)
	await process_frame
	scene._enforce_world_bounds()
	if not bounds.has_point(boundary_enemy.global_position):
		push_error("SmokeTest failed: enemy was not clamped inside world bounds.")
		quit(1)
		return
	var outside_projectile: Area2D = projectile_script.new()
	outside_projectile.global_position = bounds.end + Vector2(80, 80)
	scene.projectiles.add_child(outside_projectile)
	await process_frame
	scene._enforce_world_bounds()
	await process_frame
	if is_instance_valid(outside_projectile) and outside_projectile.get_parent() != null:
		push_error("SmokeTest failed: projectile outside world bounds was not removed.")
		quit(1)
		return
	boundary_enemy.queue_free()
	await process_frame
	if not scene.audio.streams.has("enemy_hit") or not scene.audio.streams.has("enemy_death"):
		push_error("SmokeTest failed: enemy hit/death sounds are missing.")
		quit(1)
		return
	scene._on_enemy_killed(1)
	scene._on_enemy_killed(1)
	if scene.combo_count != 2 or not scene.ui.combo_panel.visible:
		push_error("SmokeTest failed: combo counter did not appear after chained kills.")
		quit(1)
		return
	scene._process(3.2)
	if scene.combo_count != 0 or scene.ui.combo_panel.visible:
		push_error("SmokeTest failed: combo counter did not clear after timeout.")
		quit(1)
		return
	scene.player._fire()
	var player_projectile = scene.projectiles.get_child(scene.projectiles.get_child_count() - 1)
	if player_projectile.get("lifetime") < 6.0:
		push_error("SmokeTest failed: player projectile lifetime is too short.")
		quit(1)
		return
	scene.player.drone_count = 2
	scene.player._sync_drone_visuals()
	scene.player._update_drone_positions()
	scene.upgrade_system.add_experience(999)
	if not paused:
		push_error("SmokeTest failed: upgrade choice did not pause the full scene tree.")
		quit(1)
		return
	await process_frame
	scene.ui.upgrade_selected.emit({"id": "gun_lines", "label": "分裂枪线", "description": "测试"})
	await process_frame
	if paused:
		push_error("SmokeTest failed: choosing an upgrade did not resume the scene tree.")
		quit(1)
		return
	if scene.player.weapon_lines < 2:
		push_error("SmokeTest failed: gun line upgrade did not apply.")
		quit(1)
		return
	if scene.player.drone_visuals.size() != 2:
		push_error("SmokeTest failed: drone visuals were not created.")
		quit(1)
		return
	if scene.projectiles.get_child_count() <= 0:
		push_error("SmokeTest failed: firing did not create projectile visuals.")
		quit(1)
		return
	var dash_enemy: CharacterBody2D = enemy_script.new()
	dash_enemy.global_position = scene.player.global_position + Vector2(72, 0)
	dash_enemy.setup(enemy_script.EnemyKind.SCRAPPER, 1, scene.projectiles)
	scene.enemies.add_child(dash_enemy)
	await process_frame
	var dash_enemy_health: float = dash_enemy.health.current_health
	var projectile_count_before_dash: int = scene.projectiles.get_child_count()
	var dash_start: Vector2 = scene.player.global_position
	scene.player._start_dash(Vector2.RIGHT)
	if not scene.player.dash_active:
		push_error("SmokeTest failed: right-click dash did not enter dash state.")
		quit(1)
		return
	if scene.player.dash_cooldown_remaining < 1.9:
		push_error("SmokeTest failed: dash cooldown was not set to two seconds.")
		quit(1)
		return
	scene.player._fire()
	if scene.projectiles.get_child_count() != projectile_count_before_dash:
		push_error("SmokeTest failed: player fired primary weapon during dash.")
		quit(1)
		return
	scene.player._update_dash(0.08)
	scene.player._update_passives(0.08)
	if scene.player.global_position.distance_to(dash_start) < 35.0:
		push_error("SmokeTest failed: dash did not move the player enough.")
		quit(1)
		return
	if dash_enemy.health.current_health >= dash_enemy_health:
		push_error("SmokeTest failed: dash melee did not damage an enemy on the path.")
		quit(1)
		return
	dash_enemy.queue_free()
	await process_frame
	scene.player.mine_level = 0
	scene.upgrade_system.apply_upgrade({"id": "mine", "label": "Spike test"})
	var first_spike_damage: float = scene.player.spike_damage
	var first_spike_duration: float = scene.player.spike_duration
	if absf(first_spike_duration - 5.0) > 0.01:
		push_error("SmokeTest failed: initial spike duration should be 5 seconds.")
		quit(1)
		return
	scene.upgrade_system.apply_upgrade({"id": "mine", "label": "Spike test"})
	if scene.player.mine_level != 2:
		push_error("SmokeTest failed: repeat spike upgrade did not increase spike level.")
		quit(1)
		return
	if scene.player.spike_damage <= first_spike_damage or scene.player.spike_duration <= first_spike_duration:
		push_error("SmokeTest failed: repeat spike upgrade did not improve damage and duration.")
		quit(1)
		return
	scene.player.mine_level = 1
	scene.player.spike_duration = 5.0
	scene.player.global_position = Vector2.ZERO
	scene.player._reset_spike_path()
	var spike_script = load("res://scripts/components/SpikeTrap.gd")
	var spike_count_before := 0
	for child in scene.projectiles.get_children():
		if child.get_script() == spike_script:
			spike_count_before += 1
	scene.player._update_passives(0.2)
	var spike_count_after_first := 0
	for child in scene.projectiles.get_children():
		if child.get_script() == spike_script:
			spike_count_after_first += 1
	if spike_count_after_first != spike_count_before + 1:
		push_error("SmokeTest failed: spike path did not place the initial spike.")
		quit(1)
		return
	scene.player._update_passives(3.0)
	var spike_count_after_still := 0
	for child in scene.projectiles.get_children():
		if child.get_script() == spike_script:
			spike_count_after_still += 1
	if spike_count_after_still != spike_count_after_first:
		push_error("SmokeTest failed: spike path placed overlapping spikes while standing still.")
		quit(1)
		return
	scene.player.global_position = Vector2(24, 0)
	scene.player._update_passives(0.2)
	var spike_count_after_short_move := 0
	for child in scene.projectiles.get_children():
		if child.get_script() == spike_script:
			spike_count_after_short_move += 1
	if spike_count_after_short_move != spike_count_after_still:
		push_error("SmokeTest failed: spike path placed a spike before reaching spacing distance.")
		quit(1)
		return
	scene.player.global_position = Vector2(96, 0)
	scene.player._update_passives(0.2)
	var spike_count_after_long_move := 0
	for child in scene.projectiles.get_children():
		if child.get_script() == spike_script:
			spike_count_after_long_move += 1
	if spike_count_after_long_move <= spike_count_after_short_move:
		push_error("SmokeTest failed: spike path did not place spikes along movement path.")
		quit(1)
		return
	scene.player.drone_count = 2
	scene.player.drone_damage = 24.0
	scene.player._sync_drone_visuals()
	scene.player._update_drone_positions()
	var laser_enemy_a: CharacterBody2D = enemy_script.new()
	laser_enemy_a.setup(enemy_script.EnemyKind.BRUISER, 1, scene.projectiles)
	scene.enemies.add_child(laser_enemy_a)
	var laser_enemy_b: CharacterBody2D = enemy_script.new()
	laser_enemy_b.setup(enemy_script.EnemyKind.BRUISER, 1, scene.projectiles)
	scene.enemies.add_child(laser_enemy_b)
	await process_frame
	scene.player._update_drone_positions()
	var drone_origin: Vector2 = scene.player.drone_visuals[0].global_position
	laser_enemy_a.global_position = drone_origin + Vector2(120, 0)
	laser_enemy_b.global_position = scene.player.drone_visuals[1].global_position + Vector2(120, 0)
	var enemy_a_health: float = laser_enemy_a.health.current_health
	var enemy_b_health: float = laser_enemy_b.health.current_health
	scene.player._update_passives(0.5)
	await process_frame
	if laser_enemy_a.health.current_health >= enemy_a_health or laser_enemy_b.health.current_health >= enemy_b_health:
		push_error("SmokeTest failed: continuous drone lasers did not damage separate targets.")
		quit(1)
		return
	if scene.player.drone_lasers.size() != 2 or scene.player.drone_targets.size() != 2:
		push_error("SmokeTest failed: continuous drone laser state was not created.")
		quit(1)
		return
	if scene.player.drone_targets[0] == scene.player.drone_targets[1]:
		push_error("SmokeTest failed: drones targeted the same enemy despite alternatives.")
		quit(1)
		return
	var first_laser = scene.player.drone_lasers[0]
	if not first_laser.visible or first_laser.end_local.length() < 20.0 or first_laser.global_position.distance_to(scene.player.drone_visuals[0].global_position) > 1.0:
		push_error("SmokeTest failed: continuous drone laser did not follow the drone origin.")
		quit(1)
		return
	laser_enemy_a.queue_free()
	laser_enemy_b.queue_free()
	scene.player.drone_count = 0
	scene.player.mine_level = 0
	scene.player.dash_active = false
	scene.player.dash_timer = 0.0
	scene.player.velocity = Vector2.ZERO
	scene.player.dash_hit_bodies.clear()
	scene.player._clear_drone_lasers()
	for lingering_effect in scene.projectiles.get_children():
		lingering_effect.queue_free()
	await process_frame
	await physics_frame
	var enemy: CharacterBody2D = enemy_script.new()
	enemy.global_position = scene.player.global_position + Vector2(20, 0)
	enemy.setup(enemy_script.EnemyKind.SCRAPPER, 1, scene.projectiles)
	scene.enemies.add_child(enemy)
	await process_frame
	enemy._physics_process(0.016)
	if not enemy.is_attacking:
		push_error("SmokeTest failed: close melee enemy did not enter attack state.")
		quit(1)
		return
	if enemy.velocity.length() > 0.01:
		push_error("SmokeTest failed: attacking melee enemy kept moving.")
		quit(1)
		return
	var attack_position: Vector2 = enemy.global_position
	scene.player.global_position += Vector2(120, 0)
	enemy._physics_process(0.2)
	if enemy.global_position.distance_to(attack_position) > 0.1:
		push_error("SmokeTest failed: attacking melee enemy did not stay at its attack start position.")
		quit(1)
		return
	enemy.queue_free()
	await process_frame
	var spitter: CharacterBody2D = enemy_script.new()
	spitter.global_position = scene.player.global_position + Vector2(260, 0)
	spitter.setup(enemy_script.EnemyKind.SPITTER, 1, scene.projectiles)
	scene.enemies.add_child(spitter)
	await process_frame
	spitter._physics_process(0.016)
	var toward_player: Vector2 = (scene.player.global_position - spitter.global_position).normalized()
	if spitter.velocity.dot(toward_player) > 0.01:
		push_error("SmokeTest failed: ranged enemy moved toward the player inside its keep-out distance.")
		quit(1)
		return
	spitter.queue_free()
	await process_frame
	var pickup_count_before: int = scene.pickups.get_child_count()
	scene.spawn_shield(scene.player.global_position + Vector2(180, 0), 20.0)
	await process_frame
	if scene.pickups.get_child_count() <= pickup_count_before:
		push_error("SmokeTest failed: shield pickup was not spawned.")
		quit(1)
		return
	scene.audio.set_laser_active(true)
	if not scene.audio.laser_loop_player.playing:
		push_error("SmokeTest failed: laser loop did not start for end-run regression setup.")
		quit(1)
		return
	scene._end_run(false)
	if scene.player.is_physics_processing():
		push_error("SmokeTest failed: player physics processing continued after defeat.")
		quit(1)
		return
	if scene.audio.laser_loop_player.playing:
		push_error("SmokeTest failed: laser loop continued after defeat.")
		quit(1)
		return
	scene.queue_free()
	await process_frame
	quit(0)
