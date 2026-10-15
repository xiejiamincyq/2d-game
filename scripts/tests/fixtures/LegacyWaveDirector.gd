extends "res://scripts/systems/EncounterCombatCore.gd"
## Historical wave progression, test fixture only; shared combat lives in core.


signal wave_changed(index: int, total: int, remaining: int)
signal wave_cleared(completed_wave: int)
signal wave_prepared(summary: Dictionary)
signal wave_finished(summary: Dictionary)
signal boss_entrance_warning(display_name: String)
signal victory

const OverseerBossScript = preload("res://scripts/actors/OverseerBoss.gd")

const BOSS_PORTAL_WARNING_SECONDS := 1.1
const BOSS_PORTAL_BURST_SECONDS := 0.65
const BOSS_PORTAL_SCALE := 1.8
const BOSS_TRICKLE_INTERVAL := 4.6
const BOSS_TRICKLE_COUNT := 18
const BOSS_TRICKLE_MINION_CAP := 30

var wave_index: int = -1
var intermission: float = 1.2
var waiting_for_advance: bool = false
var prepared_wave: bool = false
var wave_running: bool = false
var boss_portal: Node
var boss_entrance_started := false
var boss_trickle_timer := 0.0
var pre_boss_settlement_pending := false
var boss_settlement_completed := false
var collection_window_active := false
var collection_window_remaining := 0.0

var waves: Array[Dictionary] = [
	{"scrapper": 32, "dasher": 7, "spitter": 2, "bruiser": 0, "marksman": 0, "lobber": 0, "overseer": 0, "rate": 0.13},
	{"scrapper": 40, "dasher": 11, "spitter": 5, "bruiser": 1, "marksman": 2, "lobber": 0, "overseer": 0, "rate": 0.105},
	{"scrapper": 46, "dasher": 16, "spitter": 7, "bruiser": 2, "marksman": 4, "lobber": 2, "overseer": 0, "rate": 0.085},
	{"scrapper": 56, "dasher": 20, "spitter": 9, "bruiser": 3, "marksman": 6, "lobber": 5, "overseer": 0, "rate": 0.07},
	{"scrapper": 62, "dasher": 23, "spitter": 10, "bruiser": 4, "marksman": 7, "lobber": 6, "overseer": 0, "rate": 0.055},
	{"scrapper": 70, "dasher": 26, "spitter": 12, "bruiser": 5, "marksman": 8, "lobber": 7, "overseer": 0, "rate": 0.05},
]

func setup(target_player: Node,enemies: Node,projectiles: Node,portals: Node=null,prepare_initial:=true,navigation: Node=null) -> void:
	super.setup_combat(target_player,enemies,projectiles,portals,navigation)
	if prepare_initial: prepare_next_wave()

func restore_stable_boundary(pending_stage: int, boundary: String) -> bool:
	if pending_stage < 1 or pending_stage > waves.size() or boundary not in ["wave_intro", "settlement", "boss_settlement"]:
		return false
	spawn_queue.clear()
	active_enemies.clear()
	neighbor_grid.invalidate()
	active_portals.clear()
	portal_spawn_queues.clear()
	portal_spawn_timers.clear()
	_reset_boss_tracking()
	collection_window_active = false
	collection_window_remaining = 0.0
	prepared_wave = false
	wave_running = false
	waiting_for_advance = false
	active = true
	if boundary == "boss_settlement":
		if pending_stage != waves.size():
			return false
		wave_index = waves.size() - 1
		waiting_for_advance = true
		pre_boss_settlement_pending = true
		_emit_wave_status()
		return true
	if boundary == "settlement":
		if pending_stage <= 1:
			return false
		wave_index = pending_stage - 2
		waiting_for_advance = true
		_emit_wave_status()
		return true
	wave_index = pending_stage - 2
	return prepare_next_wave()

func _process(delta: float) -> void:
	if not active or player == null:
		return
	if waiting_for_advance or prepared_wave or not wave_running:
		return
	if collection_window_active:
		_process_collection_window(delta)
		return
	if is_instance_valid(boss_portal):
		_process_boss_entrance(delta)
		return
	if not active_portals.is_empty():
		_process_portal_attack(delta)
		return
	if is_instance_valid(active_boss):
		_process_boss_trickle(delta)
		return
	if spawn_queue.is_empty():
		if active_enemies.is_empty():
			_handle_combat_entities_cleared()
		return
	_process_spawn_timer(delta)

func prepare_next_wave() -> bool:
	if player == null or prepared_wave or wave_running or waiting_for_advance:
		return false
	wave_index += 1
	if wave_index >= waves.size():
		wave_index = waves.size() - 1
		active = false
		return false
	spawn_queue.clear()
	_reset_boss_tracking()
	var wave := waves[wave_index]
	for count in range(int(wave["scrapper"])):
		spawn_queue.append(EnemyScript.EnemyKind.SCRAPPER)
	for count in range(int(wave["dasher"])):
		spawn_queue.append(EnemyScript.EnemyKind.DASHER)
	for count in range(int(wave["spitter"])):
		spawn_queue.append(EnemyScript.EnemyKind.SPITTER)
	for count in range(int(wave["bruiser"])):
		spawn_queue.append(EnemyScript.EnemyKind.BRUISER)
	for count in range(int(wave["marksman"])):
		spawn_queue.append(EnemyScript.EnemyKind.MARKSMAN)
	for count in range(int(wave["lobber"])):
		spawn_queue.append(EnemyScript.EnemyKind.LOBBER)
	for count in range(int(wave["overseer"])):
		spawn_queue.append(EnemyScript.EnemyKind.OVERSEER)
	spawn_queue.shuffle()
	prepared_wave = true
	wave_running = false
	active = true
	intermission = 0.0
	spawn_timer = 0.0
	_emit_wave_status()
	wave_prepared.emit(_get_wave_summary())
	return true

func begin_prepared_wave() -> bool:
	if not active or not prepared_wave or wave_running or waiting_for_advance:
		return false
	prepared_wave = false
	wave_running = true
	spawn_timer = 0.0
	_open_portal_attack()
	return true

func _process_boss_trickle(delta: float) -> void:
	if boss_defeat_pending or boss_defeated_for_wave:
		return
	boss_trickle_timer = maxf(0.0, boss_trickle_timer - delta)
	if boss_trickle_timer > 0.0:
		return
	boss_trickle_timer = BOSS_TRICKLE_INTERVAL
	var minions := 0
	for enemy in active_enemies:
		if enemy != active_boss:
			minions += 1
	var remaining_capacity := BOSS_TRICKLE_MINION_CAP - minions
	if remaining_capacity <= 0:
		return
	var trickle_count := mini(BOSS_TRICKLE_COUNT, remaining_capacity)
	_on_boss_reinforcements_requested(active_boss, trickle_count, BOSS_TRICKLE_COUNT)

func _handle_combat_entities_cleared() -> void:
	if not wave_running or waiting_for_advance:
		return
	if not spawn_queue.is_empty() or not active_enemies.is_empty() or not active_portals.is_empty():
		return
	if is_instance_valid(boss_portal) or is_instance_valid(active_boss):
		return
	if wave_index == waves.size() - 1:
		if boss_defeated_for_wave:
			_finish_current_wave()
		elif boss_settlement_completed and not boss_entrance_started:
			_begin_boss_entrance()
		elif not pre_boss_settlement_pending:
			pre_boss_settlement_pending = true
			_begin_collection_window()
		return
	_begin_collection_window()

func _begin_collection_window() -> bool:
	if collection_window_active or not wave_running or waiting_for_advance:
		return false
	collection_window_active = true
	collection_window_remaining = COLLECTION_WINDOW_SECONDS
	var summary := _get_wave_summary()
	collection_window_started.emit(summary, COLLECTION_WINDOW_SECONDS)
	collection_window_changed.emit(collection_window_remaining, COLLECTION_WINDOW_SECONDS)
	return true

func _process_collection_window(delta: float) -> void:
	collection_window_remaining = maxf(0.0, collection_window_remaining - maxf(0.0, delta))
	collection_window_changed.emit(collection_window_remaining, COLLECTION_WINDOW_SECONDS)
	if is_zero_approx(collection_window_remaining):
		collection_window_active = false
		_finish_current_wave()

func _begin_boss_entrance() -> bool:
	if (
		boss_entrance_started
		or boss_defeated_for_wave
		or not wave_running
		or wave_index != waves.size() - 1
		or portal_parent == null
		or not is_instance_valid(player)
	):
		return false
	boss_entrance_started = true
	var portal: Node = SpawnPortalScript.new()
	portal.name = "OverseerEntrancePortal"
	portal.scale = Vector2.ONE * BOSS_PORTAL_SCALE
	portal.z_index = 4
	portal.ready.connect(portal.set_process.bind(false), CONNECT_ONE_SHOT)
	portal_parent.add_child(portal)
	var boss_portal_position := resolve_arena_spawn_position(sample_portal_position(player.global_position, spawn_rng), 64.0)
	portal.configure(boss_portal_position, BOSS_PORTAL_WARNING_SECONDS, BOSS_PORTAL_BURST_SECONDS)
	portal.burst_started.connect(_on_boss_portal_burst, CONNECT_ONE_SHOT)
	portal.closed.connect(_on_boss_portal_closed, CONNECT_ONE_SHOT)
	boss_portal = portal
	boss_entrance_warning.emit(OverseerBossScript.DISPLAY_NAME)
	_emit_wave_status()
	return true

func _process_boss_entrance(delta: float) -> void:
	var portal := boss_portal
	if not is_instance_valid(portal):
		boss_portal = null
		return
	portal.advance(delta)

func _on_boss_portal_burst(portal: Node) -> void:
	if portal != boss_portal or is_instance_valid(active_boss) or boss_defeated_for_wave:
		return
	_spawn_boss_at(portal.global_position)

func _create_boss_actor() -> Node:
	return OverseerBossScript.new()

func _on_boss_portal_closed(portal: Node) -> void:
	if portal == boss_portal:
		boss_portal = null
	portal.queue_free()
	_emit_wave_status()
	call_deferred("_handle_combat_entities_cleared")

func _finish_current_wave() -> void:
	if waiting_for_advance or not wave_running:
		return
	var is_pre_boss_settlement := (
		wave_index == waves.size() - 1
		and pre_boss_settlement_pending
		and not boss_defeated_for_wave
	)
	if wave_index == waves.size() - 1 and not boss_defeated_for_wave and not is_pre_boss_settlement:
		return
	_emit_wave_status()
	collection_window_active = false
	collection_window_remaining = 0.0
	wave_running = false
	waiting_for_advance = true
	var summary := _get_wave_summary()
	wave_finished.emit(summary)
	if not bool(summary["is_final"]) and not bool(summary.get("is_pre_boss_settlement", false)):
		wave_cleared.emit(wave_index + 1)

func advance_after_settlement() -> bool:
	if not can_advance_after_settlement():
		return false
	waiting_for_advance = false
	if pre_boss_settlement_pending:
		pre_boss_settlement_pending = false
		boss_settlement_completed = true
		wave_running = true
		call_deferred("_handle_combat_entities_cleared")
		return true
	return prepare_next_wave()

func can_advance_after_settlement() -> bool:
	return (
		waiting_for_advance
		and active
		and not prepared_wave
		and not wave_running
		and wave_index >= 0
		and (wave_index < waves.size() - 1 or pre_boss_settlement_pending)
	)

func is_pre_boss_settlement_pending() -> bool:
	return pre_boss_settlement_pending and waiting_for_advance

func complete_final_wave() -> bool:
	if not active or not waiting_for_advance or wave_index != waves.size() - 1 or not boss_defeated_for_wave:
		return false
	waiting_for_advance = false
	active = false
	victory.emit()
	return true

func _get_wave_summary() -> Dictionary:
	var is_last_stage := wave_index == waves.size() - 1
	return {
		"wave": wave_index + 1,
		"total": waves.size(),
		"is_final": is_last_stage and boss_defeated_for_wave,
		"is_pre_boss_settlement": is_last_stage and pre_boss_settlement_pending and not boss_defeated_for_wave,
	}

func _emit_wave_status() -> void:
	var portal_remaining := 0
	for queue in portal_spawn_queues.values():
		portal_remaining += (queue as Array).size()
	var boss_remaining := 1 if wave_index == waves.size() - 1 and (prepared_wave or wave_running) and not boss_defeated_for_wave else 0
	var remaining := spawn_queue.size() + portal_remaining + active_enemies.size()
	if boss_remaining > 0 and not is_instance_valid(active_boss):
		remaining += boss_remaining
	wave_changed.emit(wave_index + 1, waves.size(), remaining)

func _reset_boss_tracking() -> void:
	active_boss = null
	boss_portal = null
	boss_entrance_started = false
	boss_defeat_pending = false
	boss_defeated_for_wave = false
	pre_boss_settlement_pending = false
	boss_settlement_completed = false

func _difficulty_index() -> int: return wave_index+1
func _spawn_interval() -> float: return float(waves[wave_index].rate)
func _spawn_boss_at(position: Vector2) -> Node:
	var boss:=super._spawn_boss_at(position)
	if boss!=null: boss_trickle_timer=BOSS_TRICKLE_INTERVAL
	return boss
