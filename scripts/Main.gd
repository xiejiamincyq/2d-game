extends Node2D

const PlayerScript = preload("res://scripts/actors/Player.gd")
const WaveDirectorScript = preload("res://scripts/systems/WaveDirector.gd")
const UpgradeSystemScript = preload("res://scripts/systems/UpgradeSystem.gd")
const RunSnapshotStoreScript = preload("res://scripts/systems/RunSnapshotStore.gd")
const GameUIScript = preload("res://scripts/ui/GameUI.gd")
const CoinPickupScript = preload("res://scripts/pickups/CoinPickup.gd")
const ShieldPickupScript = preload("res://scripts/pickups/ShieldPickup.gd")
const HeartPickupScript = preload("res://scripts/pickups/HeartPickup.gd")
const AudioManagerScript = preload("res://scripts/systems/AudioManager.gd")
const WorldBoundaryScript = preload("res://scripts/world/WorldBoundary.gd")
const ArenaLayoutScript = preload("res://scripts/world/ArenaLayout.gd")
const CombatFeedbackScript = preload("res://scripts/systems/CombatFeedback.gd")
const CombatVfxScript = preload("res://scripts/effects/CombatVfx.gd")
const CameraEffectsScript = preload("res://scripts/effects/CameraEffects.gd")

const WORLD_BOUNDS := Rect2(-1400, -900, 2800, 1800)
const CAMERA_SMOOTHING_CANDIDATES: Array[float] = [0.0, 8.0, 16.0, 20.0]
const CAMERA_SMOOTHING_SPEED: float = 8.0
const OVERDRIVE_MAX_CHARGE := 100.0
const OVERDRIVE_CHARGE_PER_KILL := 9.0
const OVERDRIVE_CHARGE_DECAY_PER_SECOND := 7.0
const OVERDRIVE_DRAIN_PER_SECOND := 34.0
const HEADLESS_SNAPSHOT_PATH := "user://five_minute_overdrive_run_test_v1.json"

enum RunState { START, WAVE_INTRO, PLAYING, BOSS_INTRO, WAVE_CLEAR, SETTLEMENT, PAUSED, RESULT }

var world: Node2D
var enemies: Node2D
var projectiles: Node2D
var portals: Node2D
var pickups: Node2D
var player: Node
var wave_director: Node
var upgrade_system: Node
var ui: Node
var audio: Node
var combat_feedback: Node
var combat_vfx: Node2D
var camera_effects: Node
var arena_layout: Node
var map_seed: int = 0
var game_over: bool = false
var run_started: bool = false
var manual_paused: bool = false
var kill_count: int = 0
var elapsed_seconds: float = 0.0
var shield_drop_timer: float = 6.0
var combo_count: int = 0
var combo_timer: float = 0.0
var overdrive_active: bool = false
var overdrive_charge: float = 0.0
var run_state: RunState = RunState.START
var pending_wave_summary: Dictionary = {}
var snapshot_store: Node
var audio_enabled := true

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	randomize()
	RenderingServer.set_default_clear_color(Color(0.025, 0.032, 0.045))
	snapshot_store = RunSnapshotStoreScript.new()
	if DisplayServer.get_name() == "headless":
		snapshot_store.save_path = HEADLESS_SNAPSHOT_PATH
	add_child(snapshot_store)
	_build_world()
	ui.show_start_screen()
	ui.set_continue_available(snapshot_store.has_valid_snapshot())

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

func spawn_coins(position: Vector2, value: int) -> void:
	var coin := CoinPickupScript.new()
	coin.global_position = position
	coin.value = value
	coin.target_player = player
	pickups.add_child(coin)
	coin.collected.connect(func(amount: int) -> void:
		upgrade_system.add_coins(amount)
		audio.play("coin")
	)

func spawn_shield(position: Vector2, value: float = 9.0) -> void:
	var shield_pickup := ShieldPickupScript.new()
	shield_pickup.global_position = position
	shield_pickup.value = value
	pickups.add_child(shield_pickup)
	shield_pickup.collected.connect(func(amount: float) -> void:
		if player != null and player.has_method("add_shield"):
			player.add_shield(amount)
			audio.play("pickup")
	)

func spawn_heart(position: Vector2, value: float = 20.0) -> void:
	var heart := HeartPickupScript.new()
	heart.global_position = position
	heart.value = value
	pickups.add_child(heart)
	heart.collected.connect(func(amount: float) -> void:
		if player != null and player.has_method("heal"):
			player.heal(amount)
			audio.play("heart")
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
	portals = Node2D.new()
	portals.name = "SpawnPortals"
	portals.process_mode = Node.PROCESS_MODE_PAUSABLE
	world.add_child(portals)
	ui = GameUIScript.new()
	add_child(ui)
	audio = AudioManagerScript.new()
	audio.silent_mode = not audio_enabled
	add_child(audio)
	ui.start_requested.connect(_start_run)
	ui.continue_requested.connect(_continue_run)
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
	arena_layout = ArenaLayoutScript.new()
	arena_layout.name = "ArenaLayout"
	arena_layout.process_mode = Node.PROCESS_MODE_PAUSABLE
	world.add_child(arena_layout)
	var boundary := WorldBoundaryScript.new()
	boundary.name = "WorldBoundary"
	boundary.process_mode = Node.PROCESS_MODE_PAUSABLE
	boundary.setup(WORLD_BOUNDS)
	world.add_child(boundary)

func _start_run() -> void:
	if run_started:
		return
	snapshot_store.clear_snapshot()
	_begin_run({})

func _continue_run() -> void:
	if run_started:
		return
	var snapshot: Dictionary = snapshot_store.load_snapshot()
	if snapshot.is_empty():
		ui.set_continue_available(false)
		return
	_begin_run(snapshot)

func _begin_run(snapshot: Dictionary) -> void:
	if run_started:
		return
	Engine.time_scale = 1.0
	run_started = true
	kill_count = int(snapshot.get("kills", 0))
	elapsed_seconds = float(snapshot.get("elapsed_seconds", 0.0))
	shield_drop_timer = 4.0
	game_over = false
	map_seed = int(snapshot.get("map_seed", randi()))
	var map_version := ArenaLayoutScript.GENERATOR_VERSION if snapshot.is_empty() else int(snapshot.get("map_generator_version", 1))
	arena_layout.generate(WORLD_BOUNDS, map_seed, map_version)
	ui.set_continue_available(false)
	audio.play("start")
	audio.play_bgm()
	player = PlayerScript.new()
	player.process_mode = Node.PROCESS_MODE_PAUSABLE
	player.global_position = Vector2.ZERO
	player.projectile_parent = projectiles
	player.world_bounds = WORLD_BOUNDS
	player.begin_spawn_input_guard()
	player.set_physics_process(false)
	world.add_child(player)
	var camera := Camera2D.new()
	camera.name = "PlayerCamera"
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = CAMERA_SMOOTHING_SPEED
	camera.limit_left = int(WORLD_BOUNDS.position.x)
	camera.limit_top = int(WORLD_BOUNDS.position.y)
	camera.limit_right = int(WORLD_BOUNDS.end.x)
	camera.limit_bottom = int(WORLD_BOUNDS.end.y)
	player.add_child(camera)
	camera.make_current()
	combat_vfx = CombatVfxScript.new()
	combat_vfx.name = "CombatVfx"
	combat_vfx.process_mode = Node.PROCESS_MODE_PAUSABLE
	combat_vfx.z_index = 20
	world.add_child(combat_vfx)
	camera_effects = CameraEffectsScript.new()
	camera_effects.name = "CameraEffects"
	camera_effects.process_mode = Node.PROCESS_MODE_PAUSABLE
	player.add_child(camera_effects)
	camera_effects.setup(camera)
	combat_feedback = CombatFeedbackScript.new()
	combat_feedback.name = "CombatFeedback"
	add_child(combat_feedback)
	combat_feedback.setup(combat_vfx, camera_effects, audio, func() -> bool: return overdrive_active)
	player.fired.connect(func(projectile: Node) -> void:
		projectile.process_mode = Node.PROCESS_MODE_PAUSABLE
		projectile.world_bounds = WORLD_BOUNDS
		projectiles.add_child(projectile)
		if projectile.has_signal("exploded"):
			projectile.exploded.connect(func(position: Vector2, _radius: float) -> void:
				audio.play("explosion")
				combat_vfx.request_effect(&"blast", position, Vector2.UP, 1.4)
			)
		audio.play_shot()
	)
	player.laser_active_changed.connect(audio.set_laser_active)
	player.health_changed.connect(ui.set_health)
	player.shield_changed.connect(ui.set_shield)
	player.died.connect(_on_player_died)
	player.entrance_finished.connect(_on_player_entrance_finished)
	upgrade_system = UpgradeSystemScript.new()
	upgrade_system.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(upgrade_system)
	upgrade_system.progression_state_changed.connect(ui.set_progression_state)
	upgrade_system.settlement_changed.connect(ui.set_settlement_state)
	upgrade_system.upgrade_applied.connect(func(label: String) -> void:
		ui.show_toast(label)
		audio.play("upgrade")
	)
	upgrade_system.setup(player)
	if not snapshot.is_empty():
		var growth_state := {
			"coins": snapshot.get("coins", 0),
			"family_levels": snapshot.get("family_levels", {}),
			"upgrade_counts": snapshot.get("upgrade_counts", {}),
			"evolution": snapshot.get("evolution", ""),
			"settlement": snapshot.get("settlement", {}),
		}
		if not upgrade_system.restore_snapshot_state(growth_state) or not player.restore_snapshot_state(snapshot.get("player", {})):
			snapshot_store.clear_snapshot()
			_restart_run()
			return
		var player_margin: Vector2 = Vector2.ONE * float(player.get_body_radius())
		player.global_position = player.global_position.clamp(WORLD_BOUNDS.position + player_margin, WORLD_BOUNDS.end - player_margin)
	ui.settlement_offer_selected.connect(_on_settlement_offer_selected)
	ui.settlement_close_requested.connect(_on_settlement_close_requested)
	ui.wave_banner_finished.connect(_on_wave_banner_finished)
	wave_director = WaveDirectorScript.new()
	wave_director.process_mode = Node.PROCESS_MODE_PAUSABLE
	wave_director.world_bounds = WORLD_BOUNDS
	add_child(wave_director)
	wave_director.wave_changed.connect(ui.set_wave)
	wave_director.boss_spawned.connect(_on_boss_spawned)
	wave_director.boss_health_changed.connect(ui.set_boss_health)
	wave_director.boss_defeated.connect(func(_boss: Node) -> void: ui.hide_boss_health())
	wave_director.boss_cue.connect(func(cue: StringName) -> void: audio.play_boss_cue(cue))
	wave_director.boss_entrance_warning.connect(func(display_name: String) -> void: ui.show_wave_banner("警告：侦测到最终 Boss —— %s" % display_name, &"boss_entrance", 1.4))
	wave_director.wave_prepared.connect(_on_wave_prepared)
	wave_director.collection_window_started.connect(func(_summary: Dictionary, duration: float) -> void: ui.set_collection_window(duration, duration))
	wave_director.collection_window_changed.connect(ui.set_collection_window)
	wave_director.wave_finished.connect(_on_wave_finished)
	wave_director.enemy_killed.connect(_on_enemy_killed)
	wave_director.damage_resolved.connect(combat_feedback.on_damage_resolved)
	wave_director.victory.connect(_on_victory)
	wave_director.setup(player, enemies, projectiles, portals, false, arena_layout)
	player.set_enemy_provider(wave_director.get_active_enemies)
	ui.set_health(player.health.current_health, player.health.max_health)
	ui.set_shield(player.shield, player.max_shield)
	ui.set_progression_state(upgrade_system.get_progression_state())
	ui.set_run_stats(kill_count, elapsed_seconds)
	if snapshot.is_empty():
		ui.hide_start_screen()
		player.begin_entrance()
	else:
		var boundary := String(snapshot.get("boundary", ""))
		var pending_stage := int(snapshot.get("pending_stage", 0))
		if not wave_director.restore_stable_boundary(pending_stage, boundary):
			snapshot_store.clear_snapshot()
			_restart_run()
			return
		if boundary in ["settlement", "boss_settlement"]:
			var completed_wave := pending_stage if boundary == "boss_settlement" else pending_stage - 1
			pending_wave_summary = {
				"wave": completed_wave,
				"total": wave_director.waves.size(),
				"is_final": false,
				"is_pre_boss_settlement": boundary == "boss_settlement",
			}
			_transition_to(RunState.SETTLEMENT)
			ui.show_settlement()

func _on_player_entrance_finished() -> void:
	if run_state != RunState.START or wave_director == null:
		return
	if not wave_director.prepare_next_wave():
		_fail_progression_gate("玩家入场后首波准备失败")

func _on_boss_spawned(boss: Node, display_name: String, maximum_health: float) -> void:
	ui.show_boss_health(boss, display_name, maximum_health)
	if run_state != RunState.PLAYING or not boss.has_signal("entrance_finished"):
		return
	boss.visible = false
	boss.entrance_finished.connect(_on_boss_entrance_finished.bind(boss), CONNECT_ONE_SHOT)
	if _transition_to(RunState.BOSS_INTRO):
		ui.show_boss_intro(display_name, 1.4)
	else:
		boss.visible = true

func _on_boss_entrance_finished(boss: Node) -> void:
	if is_instance_valid(boss):
		boss.visible = true
	ui.hide_boss_intro()
	if run_state == RunState.BOSS_INTRO:
		_transition_to(RunState.PLAYING)

func _on_wave_prepared(summary: Dictionary) -> void:
	pending_wave_summary = summary.duplicate(true)
	if not _transition_to(RunState.WAVE_INTRO):
		return
	_save_stable_snapshot("wave_intro", int(summary.get("wave", 1)))
	ui.show_wave_banner(
		"侦测到第 %d 波敌人" % int(summary.get("wave", 0)),
		&"wave_intro",
		1.15
	)

func _on_wave_finished(summary: Dictionary) -> void:
	pending_wave_summary = summary.duplicate(true)
	if not _transition_to(RunState.WAVE_CLEAR):
		return
	ui.show_wave_banner(
		"第 %d 波清剿完成" % int(summary.get("wave", 0)),
		&"wave_clear",
		1.05
	)

func _on_wave_banner_finished(context: StringName) -> void:
	if context == &"wave_intro" and run_state == RunState.WAVE_INTRO:
		if wave_director.begin_prepared_wave():
			_transition_to(RunState.PLAYING)
		else:
			_fail_progression_gate("波次启动失败")
		return
	if context != &"wave_clear" or run_state != RunState.WAVE_CLEAR:
		return
	if bool(pending_wave_summary.get("is_final", false)):
		if not wave_director.complete_final_wave():
			_fail_progression_gate("最终波结算失败")
		return
	var completed_wave := int(pending_wave_summary.get("wave", 0))
	if upgrade_system.prepare_settlement(completed_wave):
		_transition_to(RunState.SETTLEMENT)
		ui.show_settlement()
		_save_current_settlement_snapshot(completed_wave)
	else:
		_fail_progression_gate("波次结算生成失败")

func _on_settlement_offer_selected(offer: Dictionary) -> void:
	if run_state != RunState.SETTLEMENT:
		return
	var state: Dictionary = upgrade_system.get_settlement_state()
	var changed: bool = upgrade_system.purchase_settlement_offer(offer) if bool(state.get("reward_claimed", false)) else upgrade_system.claim_free_offer(offer)
	if changed:
		_save_current_settlement_snapshot(int(state.get("wave", wave_director.wave_index + 1)))

func _save_current_settlement_snapshot(completed_wave: int) -> bool:
	var is_pre_boss_settlement: bool = bool(
		bool(pending_wave_summary.get("is_pre_boss_settlement", false))
		or wave_director.is_pre_boss_settlement_pending()
	)
	return _save_stable_snapshot(
		"boss_settlement" if is_pre_boss_settlement else "settlement",
		completed_wave if is_pre_boss_settlement else completed_wave + 1
	)

func _on_settlement_close_requested() -> void:
	if run_state != RunState.SETTLEMENT:
		return
	if not wave_director.can_advance_after_settlement():
		ui.show_toast("下一波尚未就绪，请重试")
		ui.show_settlement()
		return
	var state: Dictionary = upgrade_system.get_settlement_state()
	if not upgrade_system.complete_settlement({"transaction": state.get("transaction", -1)}):
		ui.show_toast("结算尚未完成")
		ui.show_settlement()
		return
	var advances_to_boss: bool = bool(wave_director.is_pre_boss_settlement_pending())
	if not wave_director.advance_after_settlement():
		_fail_progression_gate("下一波推进失败")
		return
	if advances_to_boss and not _transition_to(RunState.PLAYING):
		_fail_progression_gate("Boss 战准备失败")

func _fail_progression_gate(message: String) -> void:
	push_warning(message)
	ui.show_toast(message)
	_end_run(false)

func _on_enemy_killed(_enemy: Node, _source: StringName, _coin_value: int) -> void:
	kill_count += 1
	combo_count += 1
	combo_timer = 3.0
	if not overdrive_active:
		overdrive_charge = minf(OVERDRIVE_MAX_CHARGE, overdrive_charge + OVERDRIVE_CHARGE_PER_KILL)
	if is_equal_approx(overdrive_charge, OVERDRIVE_MAX_CHARGE) and not overdrive_active:
		_set_overdrive(true)
	ui.set_overdrive_charge(overdrive_charge, overdrive_active)
	ui.set_combo(combo_count)
	ui.set_run_stats(kill_count, elapsed_seconds)

func _on_player_died() -> void:
	_end_run(false)

func _on_victory() -> void:
	_end_run(true)

func _save_stable_snapshot(boundary: String, pending_stage: int) -> bool:
	if not run_started or player == null or upgrade_system == null or snapshot_store == null:
		return false
	var growth: Dictionary = upgrade_system.get_snapshot_state()
	var snapshot := {
		"version": RunSnapshotStoreScript.VERSION,
		"boundary": boundary,
		"pending_stage": pending_stage,
		"coins": growth["coins"],
		"family_levels": growth["family_levels"],
		"upgrade_counts": growth["upgrade_counts"],
		"evolution": growth["evolution"],
		"settlement": growth["settlement"],
		"player": player.get_snapshot_state(),
		"kills": kill_count,
		"elapsed_seconds": elapsed_seconds,
		"map_seed": map_seed,
		"map_generator_version": arena_layout.generator_version,
	}
	return snapshot_store.save_snapshot(snapshot)

func _end_run(victory: bool) -> void:
	if game_over:
		return
	game_over = true
	ui.hide_boss_health()
	ui.hide_boss_intro()
	snapshot_store.clear_snapshot()
	if player != null:
		player.set_physics_process(false)
	audio.set_laser_active(false)
	var wave_text := "抵达波次 %d/%d" % [wave_director.wave_index + 1, wave_director.waves.size()]
	audio.play("victory" if victory else "defeat")
	ui.show_result(victory, wave_text, kill_count, elapsed_seconds, upgrade_system.get_progression_state())
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
	if snapshot_store != null:
		snapshot_store.clear_snapshot()
	_reset_combat_feedback()
	get_tree().paused = false
	get_tree().reload_current_scene()

func _transition_to(next_state: RunState) -> bool:
	if next_state == run_state:
		return true
	var allowed: Dictionary = {
		RunState.START: [RunState.WAVE_INTRO, RunState.SETTLEMENT],
		RunState.WAVE_INTRO: [RunState.PLAYING, RunState.RESULT],
		RunState.PLAYING: [RunState.BOSS_INTRO, RunState.WAVE_CLEAR, RunState.PAUSED, RunState.RESULT],
		RunState.BOSS_INTRO: [RunState.PLAYING, RunState.RESULT],
		RunState.WAVE_CLEAR: [RunState.SETTLEMENT, RunState.RESULT],
		RunState.SETTLEMENT: [RunState.WAVE_INTRO, RunState.PLAYING, RunState.RESULT],
		RunState.PAUSED: [RunState.PLAYING, RunState.RESULT],
		RunState.RESULT: [],
	}
	if not next_state in allowed.get(run_state, []):
		return false
	if next_state != RunState.PLAYING:
		_reset_combat_feedback()
	run_state = next_state
	manual_paused = run_state == RunState.PAUSED
	if player != null:
		player.set_physics_process(run_state == RunState.PLAYING)
	get_tree().paused = run_state in [
		RunState.WAVE_INTRO,
		RunState.BOSS_INTRO,
		RunState.WAVE_CLEAR,
		RunState.SETTLEMENT,
		RunState.PAUSED,
		RunState.RESULT,
	]
	match run_state:
		RunState.PLAYING:
			var camera := player.get_node_or_null("PlayerCamera") as Camera2D if player != null else null
			if camera != null:
				# A restored/spawned player may have moved while the camera was
				# paused. Do not animate that setup correction as player movement.
				camera.reset_smoothing()
			ui.hide_start_screen()
			ui.hide_settlement()
			ui.hide_manual_pause()
			ui.hide_result()
		RunState.WAVE_INTRO:
			ui.hide_start_screen()
			ui.hide_settlement()
			ui.hide_manual_pause()
		RunState.BOSS_INTRO:
			ui.hide_manual_pause()
		RunState.WAVE_CLEAR:
			ui.hide_manual_pause()
		RunState.SETTLEMENT:
			ui.hide_manual_pause()
		RunState.PAUSED:
			ui.hide_settlement()
			ui.show_manual_pause()
		RunState.RESULT:
			ui.hide_settlement()
			ui.hide_manual_pause()
	ui.set_aim_reticle_visible(run_state == RunState.PLAYING)
	return true

func get_world_bounds() -> Rect2:
	return WORLD_BOUNDS

func _update_combo(delta: float) -> void:
	if overdrive_active:
		overdrive_charge = maxf(0.0, overdrive_charge - OVERDRIVE_DRAIN_PER_SECOND * delta)
		if is_zero_approx(overdrive_charge):
			_set_overdrive(false)
	else:
		overdrive_charge = maxf(0.0, overdrive_charge - OVERDRIVE_CHARGE_DECAY_PER_SECOND * delta)
	ui.set_overdrive_charge(overdrive_charge, overdrive_active)
	if combo_count <= 0:
		return
	combo_timer -= delta
	if combo_timer <= 0.0:
		combo_count = 0
		combo_timer = 0.0
		ui.clear_combo()

func _enforce_world_bounds() -> void:
	if player != null:
		var player_margin: Vector2 = Vector2.ONE * float(player.get_body_radius())
		player.global_position = player.global_position.clamp(WORLD_BOUNDS.position + player_margin, WORLD_BOUNDS.end - player_margin)
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

func _reset_combat_feedback() -> void:
	_set_overdrive(false)
	if is_instance_valid(combat_feedback):
		combat_feedback.reset_all()
	if is_instance_valid(combat_vfx):
		combat_vfx.clear_all()
	if is_instance_valid(camera_effects):
		camera_effects.clear_all()
	Engine.time_scale = 1.0

func _set_overdrive(active: bool) -> void:
	overdrive_active = active
	if player != null and player.has_method("set_overdrive_active"):
		player.set_overdrive_active(active)
		player.modulate = Color("ff571f") if active else Color.WHITE
	if active:
		ui.set_overdrive(true, overdrive_charge / OVERDRIVE_DRAIN_PER_SECOND)
		audio.play("upgrade")
		if is_instance_valid(combat_vfx):
			combat_vfx.request_effect(&"ring", player.global_position, Vector2.UP, 2.0)
		if is_instance_valid(camera_effects):
			camera_effects.request_impact(0.55, Vector2.UP)

func _exit_tree() -> void:
	_reset_combat_feedback()
