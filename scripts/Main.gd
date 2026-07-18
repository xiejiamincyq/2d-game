extends Node2D

const PlayerScript = preload("res://scripts/actors/Player.gd")
const WaveDirectorScript = preload("res://scripts/systems/WaveDirector.gd")
const UpgradeSystemScript = preload("res://scripts/systems/UpgradeSystem.gd")
const GameUIScript = preload("res://scripts/ui/GameUI.gd")
const ExperienceShardScript = preload("res://scripts/pickups/ExperienceShard.gd")
const ShieldPickupScript = preload("res://scripts/pickups/ShieldPickup.gd")
const AudioManagerScript = preload("res://scripts/systems/AudioManager.gd")
const WorldBoundaryScript = preload("res://scripts/world/WorldBoundary.gd")

const WORLD_BOUNDS := Rect2(-1400, -900, 2800, 1800)

enum RunState { START, PLAYING, UPGRADE, PAUSED, RESULT }

var world: Node2D
var enemies: Node2D
var projectiles: Node2D
var pickups: Node2D
var player: Node
var wave_director: Node
var upgrade_system: Node
var ui: Node
var audio: Node
var game_over: bool = false
var run_started: bool = false
var manual_paused: bool = false
var kill_count: int = 0
var elapsed_seconds: float = 0.0
var shield_drop_timer: float = 6.0
var combo_count: int = 0
var combo_timer: float = 0.0
var run_state: RunState = RunState.START

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	randomize()
	RenderingServer.set_default_clear_color(Color(0.025, 0.032, 0.045))
	_build_world()
	ui.show_start_screen()

func _unhandled_input(event: InputEvent) -> void:
	if run_state == RunState.RESULT and event is InputEventKey and event.pressed and event.keycode == KEY_R:
		_restart_run()

func _process(delta: float) -> void:
	if run_state == RunState.PLAYING:
		elapsed_seconds += delta
		_update_combo(delta)
		_update_random_shield_drop(delta)
		_enforce_world_bounds()
		ui.set_run_stats(kill_count, elapsed_seconds)

func spawn_experience(position: Vector2, value: int) -> void:
	var shard := ExperienceShardScript.new()
	shard.global_position = position
	shard.value = value
	pickups.add_child(shard)
	shard.collected.connect(func(amount: int) -> void:
		upgrade_system.add_experience(amount)
		audio.play("xp")
	)

func spawn_shield(position: Vector2, value: float = 9.0) -> void:
	var shield_pickup := ShieldPickupScript.new()
	shield_pickup.global_position = position
	shield_pickup.value = value
	pickups.add_child(shield_pickup)
	shield_pickup.collected.connect(func(amount: float) -> void:
		if player != null and player.has_method("add_shield"):
			player.add_shield(amount)
			audio.play("xp")
	)

func _update_random_shield_drop(delta: float) -> void:
	if player == null:
		return
	shield_drop_timer -= delta
	if shield_drop_timer > 0.0:
		return
	shield_drop_timer = randf_range(11.0, 18.0)
	var angle := randf() * TAU
	var distance := randf_range(220.0, 520.0)
	spawn_shield(player.global_position + Vector2.RIGHT.rotated(angle) * distance, randf_range(7.0, 12.0))

func _build_world() -> void:
	world = Node2D.new()
	world.name = "World"
	world.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(world)
	_draw_floor()
	pickups = Node2D.new()
	pickups.name = "Pickups"
	pickups.process_mode = Node.PROCESS_MODE_PAUSABLE
	world.add_child(pickups)
	enemies = Node2D.new()
	enemies.name = "Enemies"
	enemies.process_mode = Node.PROCESS_MODE_PAUSABLE
	world.add_child(enemies)
	projectiles = Node2D.new()
	projectiles.name = "Projectiles"
	projectiles.process_mode = Node.PROCESS_MODE_PAUSABLE
	world.add_child(projectiles)
	ui = GameUIScript.new()
	add_child(ui)
	audio = AudioManagerScript.new()
	add_child(audio)
	ui.start_requested.connect(_start_run)
	ui.restart_requested.connect(_restart_run)
	ui.pause_requested.connect(_toggle_manual_pause)
	ui.bgm_volume_changed.connect(audio.set_bgm_volume)
	ui.bgm_mute_changed.connect(audio.set_bgm_muted)

func _draw_floor() -> void:
	var floor := Node2D.new()
	floor.name = "CyberWastelandFloor"
	floor.process_mode = Node.PROCESS_MODE_PAUSABLE
	floor.set_script(load("res://scripts/world/FloorGrid.gd"))
	world.add_child(floor)
	var boundary := WorldBoundaryScript.new()
	boundary.name = "WorldBoundary"
	boundary.process_mode = Node.PROCESS_MODE_PAUSABLE
	boundary.setup(WORLD_BOUNDS)
	world.add_child(boundary)

func _start_run() -> void:
	if run_started:
		return
	run_started = true
	kill_count = 0
	elapsed_seconds = 0.0
	shield_drop_timer = 4.0
	game_over = false
	audio.play("start")
	audio.play_bgm()
	player = PlayerScript.new()
	player.process_mode = Node.PROCESS_MODE_PAUSABLE
	player.global_position = Vector2.ZERO
	player.projectile_parent = projectiles
	player.world_bounds = WORLD_BOUNDS
	world.add_child(player)
	var camera := Camera2D.new()
	camera.name = "PlayerCamera"
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 8.0
	camera.limit_left = int(WORLD_BOUNDS.position.x)
	camera.limit_top = int(WORLD_BOUNDS.position.y)
	camera.limit_right = int(WORLD_BOUNDS.end.x)
	camera.limit_bottom = int(WORLD_BOUNDS.end.y)
	player.add_child(camera)
	camera.make_current()
	player.fired.connect(func(projectile: Node) -> void:
		projectile.process_mode = Node.PROCESS_MODE_PAUSABLE
		projectile.world_bounds = WORLD_BOUNDS
		projectiles.add_child(projectile)
		audio.play("shoot")
	)
	player.laser_active_changed.connect(audio.set_laser_active)
	player.health_changed.connect(ui.set_health)
	player.shield_changed.connect(ui.set_shield)
	player.died.connect(_on_player_died)
	upgrade_system = UpgradeSystemScript.new()
	upgrade_system.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(upgrade_system)
	upgrade_system.setup(player)
	upgrade_system.experience_changed.connect(ui.set_experience)
	upgrade_system.choices_ready.connect(_on_upgrade_choices_ready)
	upgrade_system.upgrade_applied.connect(func(label: String) -> void:
		ui.show_toast(label)
		audio.play("upgrade")
	)
	upgrade_system.upgrade_queue_completed.connect(func() -> void: _transition_to(RunState.PLAYING))
	ui.upgrade_selected.connect(_on_upgrade_selected)
	wave_director = WaveDirectorScript.new()
	wave_director.process_mode = Node.PROCESS_MODE_PAUSABLE
	wave_director.world_bounds = WORLD_BOUNDS
	add_child(wave_director)
	wave_director.wave_changed.connect(ui.set_wave)
	wave_director.enemy_killed.connect(_on_enemy_killed)
	wave_director.victory.connect(_on_victory)
	wave_director.setup(player, enemies, projectiles)
	player.set_enemy_provider(wave_director.get_active_enemies)
	ui.set_health(player.health.current_health, player.health.max_health)
	ui.set_shield(player.shield, player.max_shield)
	ui.set_experience(upgrade_system.experience, upgrade_system.required_experience, upgrade_system.level)
	ui.set_run_stats(kill_count, elapsed_seconds)
	_transition_to(RunState.PLAYING)

func _on_upgrade_choices_ready(choices: Array[Dictionary]) -> void:
	if _transition_to(RunState.UPGRADE):
		ui.show_upgrades(choices)

func _on_upgrade_selected(choice: Dictionary) -> void:
	upgrade_system.apply_upgrade(choice)

func _on_enemy_killed(_enemy: Node, _source: StringName, _xp_value: int) -> void:
	kill_count += 1
	combo_count += 1
	combo_timer = 3.0
	ui.set_combo(combo_count)
	ui.set_run_stats(kill_count, elapsed_seconds)

func _on_enemy_hit(source: StringName) -> void:
	audio.play_hit(source)

func _on_player_died() -> void:
	_end_run(false)

func _on_victory() -> void:
	_end_run(true)

func _end_run(victory: bool) -> void:
	if game_over:
		return
	game_over = true
	if player != null:
		player.set_physics_process(false)
	audio.set_laser_active(false)
	var wave_text := "抵达波次 %d/%d" % [wave_director.wave_index + 1, wave_director.waves.size()]
	audio.play("victory" if victory else "defeat")
	ui.show_result(victory, wave_text, kill_count, elapsed_seconds, upgrade_system.level)
	_transition_to(RunState.RESULT)

func _toggle_manual_pause() -> void:
	if not run_started or game_over:
		return
	if run_state == RunState.PLAYING:
		_transition_to(RunState.PAUSED)
	elif run_state == RunState.PAUSED:
		_transition_to(RunState.PLAYING)

func _restart_run() -> void:
	manual_paused = false
	get_tree().paused = false
	get_tree().reload_current_scene()

func _transition_to(next_state: RunState) -> bool:
	if next_state == run_state:
		return true
	var allowed: Dictionary = {
		RunState.START: [RunState.PLAYING],
		RunState.PLAYING: [RunState.UPGRADE, RunState.PAUSED, RunState.RESULT],
		RunState.UPGRADE: [RunState.PLAYING, RunState.RESULT],
		RunState.PAUSED: [RunState.PLAYING, RunState.RESULT],
		RunState.RESULT: [RunState.PLAYING],
	}
	if not next_state in allowed.get(run_state, []):
		return false
	run_state = next_state
	manual_paused = run_state == RunState.PAUSED
	get_tree().paused = run_state in [RunState.UPGRADE, RunState.PAUSED, RunState.RESULT]
	match run_state:
		RunState.PLAYING:
			ui.hide_start_screen()
			ui.hide_upgrades()
			ui.hide_manual_pause()
			ui.hide_result()
		RunState.UPGRADE:
			ui.hide_manual_pause()
		RunState.PAUSED:
			ui.hide_upgrades()
			ui.show_manual_pause()
		RunState.RESULT:
			ui.hide_upgrades()
			ui.hide_manual_pause()
	return true

func get_world_bounds() -> Rect2:
	return WORLD_BOUNDS

func _update_combo(delta: float) -> void:
	if combo_count <= 0:
		return
	combo_timer -= delta
	if combo_timer <= 0.0:
		combo_count = 0
		combo_timer = 0.0
		ui.clear_combo()

func _enforce_world_bounds() -> void:
	if player != null:
		player.global_position = player.global_position.clamp(WORLD_BOUNDS.position + Vector2(13, 13), WORLD_BOUNDS.end - Vector2(13, 13))
	for enemy in get_tree().get_nodes_in_group("enemies"):
		var enemy_node := enemy as Node2D
		if enemy_node == null:
			continue
		var margin := Vector2(16, 16)
		var body_radius_value = enemy.get("body_radius")
		if body_radius_value != null:
			margin = Vector2(float(body_radius_value), float(body_radius_value))
		enemy_node.global_position = enemy_node.global_position.clamp(WORLD_BOUNDS.position + margin, WORLD_BOUNDS.end - margin)
	for projectile in projectiles.get_children():
		var projectile_node := projectile as Node2D
		if projectile_node != null and not WORLD_BOUNDS.has_point(projectile_node.global_position):
			projectile_node.queue_free()
	for pickup in pickups.get_children():
		var pickup_node := pickup as Node2D
		if pickup_node != null:
			pickup_node.global_position = pickup_node.global_position.clamp(WORLD_BOUNDS.position + Vector2(12, 12), WORLD_BOUNDS.end - Vector2(12, 12))
