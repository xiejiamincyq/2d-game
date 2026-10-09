extends "res://scripts/systems/WaveDirector.gd"
## Chapter-owned flow. Reuses actor/portal spawning, not the six-wave progression.
## The old Overseer is an explicitly transitional Boss until the skeleton gate.

signal encounter_prepared(encounter: Dictionary)
signal encounter_status(encounter: Dictionary, remaining: int)
signal reward_ready(reward: Dictionary)
signal route_ready
signal chapter_boss_ready(display_name: String)
signal chapter_cleared(chapter: int)
signal run_failed(reason: String)

enum State { IDLE, INTRO, COMBAT, COLLECT, REWARD, ROUTE, RESOLVING_ROUTE, BOSS_READY, BOSS, CLEARED, FAILED }
const TRANSITIONAL_BOSS_LABEL := "过渡首领：深渊监工（旧资源，非藤冠守卫成品）"
const SUPPLY_COINS := 12
const SUPPLY_HEAL := 20.0
const RISK_COINS := 35
const PlayerBody = preload("res://scripts/actors/Player.gd")
const BuildSystem = preload("res://scripts/systems/UpgradeSystem.gd")
var state := State.IDLE
var run_seed := 0
var route: StringName = &""
var growth: BuildSystem
var encounters: Array[Dictionary] = []
var encounter_index := 0
var reward_transaction := -1
var collection_remaining := 0.0
var defeated_boss_instance := 0

func start_run(seed_value: int, target: PlayerBody, enemies: Node2D, projectiles: Node2D, portals: Node2D, build: BuildSystem, navigation: ArenaLayout) -> bool:
	if state != State.IDLE or not is_instance_valid(target) or not is_instance_valid(build) or build.player != target:
		return false
	if not is_instance_valid(enemies) or not is_instance_valid(projectiles) or not is_instance_valid(portals) or not is_instance_valid(navigation) or target.health.current_health <= 0:
		return false
	run_seed = seed_value
	spawn_rng.seed = seed_value
	encounters = [
		{"id": &"root_outskirts", "name": "苗圃外围", "scrapper": spawn_rng.randi_range(14, 18), "spitter": spawn_rng.randi_range(2, 3), "rate": 0.18},
		{"id": &"spore_beds", "name": "孢子植床", "scrapper": spawn_rng.randi_range(20, 24), "spitter": spawn_rng.randi_range(4, 5), "rate": 0.15},
		{"id": &"overgrown_detour", "name": "高风险：过生根巢", "scrapper": spawn_rng.randi_range(30, 34), "spitter": spawn_rng.randi_range(6, 7), "rate": 0.12},
	]
	growth = build
	world_bounds = navigation.world_bounds
	super.setup(target, enemies, projectiles, portals, false, navigation)
	target.died.connect(func() -> void: _fail("玩家死亡"))
	_prepare_encounter(0)
	return true

func get_encounter() -> Dictionary:
	return encounters[encounter_index].duplicate(true) if not encounters.is_empty() else {}

func _prepare_encounter(index: int) -> void:
	encounter_index = index
	var encounter := get_encounter()
	# Base spawn helpers use a rate and combat difficulty, not chapter numbering.
	wave_index = 0
	waves = [{"rate": encounter.rate}]
	spawn_queue.clear()
	for count in encounter.scrapper:
		spawn_queue.append(EnemyScript.EnemyKind.SCRAPPER)
	for count in encounter.spitter:
		spawn_queue.append(EnemyScript.EnemyKind.SPITTER)
	for index_value in range(spawn_queue.size() - 1, 0, -1):
		var other := spawn_rng.randi_range(0, index_value)
		var saved := spawn_queue[index_value]
		spawn_queue[index_value] = spawn_queue[other]
		spawn_queue[other] = saved
	state = State.INTRO
	active = true
	spawn_timer = 0
	encounter_prepared.emit(encounter)

func begin_encounter() -> bool:
	if state != State.INTRO:
		return false
	state = State.COMBAT
	_open_portal_attack()
	return true

func _process(delta: float) -> void:
	if not active or state not in [State.COMBAT, State.COLLECT, State.BOSS]:
		return
	if not is_instance_valid(player) or player.health.current_health <= 0:
		_fail("玩家不可继续战斗")
		return
	if state == State.COLLECT:
		collection_remaining = maxf(0, collection_remaining - maxf(delta, 0))
		collection_window_changed.emit(collection_remaining, COLLECTION_WINDOW_SECONDS)
		if collection_remaining == 0:
			if not growth.prepare_settlement(encounter_index + 1):
				_fail("遭遇奖励无法准备")
				return
			reward_transaction = int(growth.get_settlement_state().transaction)
			state = State.REWARD
			reward_ready.emit(growth.get_settlement_state())
	elif not active_portals.is_empty():
		_process_portal_attack(maxf(delta, 0))
	elif state == State.COMBAT:
		if not spawn_queue.is_empty():
			_process_spawn_timer(maxf(delta, 0))
		_handle_combat_entities_cleared()

func _handle_combat_entities_cleared() -> void:
	if state != State.COMBAT or not spawn_queue.is_empty() or not active_enemies.is_empty() or not active_portals.is_empty():
		return
	state = State.COLLECT
	collection_remaining = COLLECTION_WINDOW_SECONDS
	collection_window_started.emit(get_encounter(), COLLECTION_WINDOW_SECONDS)

func claim_reward(offer: Dictionary) -> bool:
	return state == State.REWARD and growth.claim_free_offer(offer)

func purchase_reward(offer: Dictionary) -> bool:
	return state == State.REWARD and growth.purchase_settlement_offer(offer)

func finish_reward() -> bool:
	if state != State.REWARD:
		return false
	var reward: Dictionary = growth.get_settlement_state()
	if int(reward.wave) != encounter_index + 1 or int(reward.transaction) != reward_transaction or not reward.reward_claimed:
		return false
	if not growth.complete_settlement({"transaction": reward_transaction}):
		return false
	if encounter_index == 0:
		_prepare_encounter(1)
	elif encounter_index == 1:
		state = State.ROUTE
		route_ready.emit()
	else:
		growth.add_coins(RISK_COINS)
		_prepare_boss()
	return true

func choose_route(choice: StringName) -> bool:
	if state != State.ROUTE or choice not in [&"supply", &"risk"]:
		return false
	route = choice
	# Latch before currency/health signals publish to synchronous UI listeners.
	state = State.RESOLVING_ROUTE
	if choice == &"supply":
		growth.add_coins(SUPPLY_COINS)
		player.heal(SUPPLY_HEAL)
		_prepare_boss()
	else:
		_prepare_encounter(2)
	return true

func _prepare_boss() -> void:
	state = State.BOSS_READY
	chapter_boss_ready.emit(TRANSITIONAL_BOSS_LABEL)

func begin_boss() -> bool:
	if state != State.BOSS_READY:
		return false
	state = State.BOSS
	var boss := _spawn_boss_at(Vector2(0, -500))
	if not is_instance_valid(boss):
		_fail("过渡首领创建失败")
		return false
	return true

func _on_boss_died(boss: Node, dropped_coins: int, source: StringName) -> void:
	if state != State.BOSS or boss != active_boss or boss.health.current_health > 0 or not boss.death_resolved:
		return
	super._on_boss_died(boss, dropped_coins, source)

func _on_boss_tree_exiting(boss: Node) -> void:
	if boss != active_boss:
		return
	var defeated: bool = state == State.BOSS and boss == active_boss and boss_defeat_pending and boss.death_resolved and boss.health.current_health <= 0
	var instance_id := boss.get_instance_id()
	super._on_boss_tree_exiting(boss)
	if defeated:
		defeated_boss_instance = instance_id
		state = State.CLEARED
		active = false
		chapter_cleared.emit(1)
	elif state == State.BOSS:
		_fail("首领未被击败而退出")

func _on_enemy_tree_exiting(enemy: Node) -> void:
	if not active_enemies.has(enemy):
		return
	var cancelled: bool = state in [State.COMBAT, State.BOSS] and not enemy.get_meta(&"kill_resolved", false)
	super._on_enemy_tree_exiting(enemy)
	if cancelled:
		_fail("敌人未被击败而退出")

func _fail(reason: String) -> void:
	if state in [State.FAILED, State.CLEARED]:
		return
	state = State.FAILED
	active = false
	spawn_queue.clear()
	run_failed.emit(reason)

func _emit_wave_status() -> void:
	var remaining := active_enemies.size() + spawn_queue.size()
	for queue in portal_spawn_queues.values():
		remaining += queue.size()
	encounter_status.emit(get_encounter(), remaining)

# Explicitly reject old progression/snapshot entry points on this subclass.
func restore_stable_boundary(_pending_stage: int, _boundary: String) -> bool:
	return false
func prepare_next_wave() -> bool:
	return false
func begin_prepared_wave() -> bool:
	return false
func advance_after_settlement() -> bool:
	return false
func can_advance_after_settlement() -> bool:
	return false
func is_pre_boss_settlement_pending() -> bool:
	return false
func complete_final_wave() -> bool:
	return false
