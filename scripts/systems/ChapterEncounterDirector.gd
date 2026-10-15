extends "res://scripts/systems/EncounterCombatCore.gd"
## Shared chapter combat/clearance/reward lifecycle; chapter identity lives in subclasses.

signal encounter_prepared(encounter: Dictionary)
signal encounter_status(encounter: Dictionary, remaining: int)
signal reward_ready(reward: Dictionary)
signal route_ready
signal chapter_boss_ready(display_name: String)
signal chapter_cleared(chapter: int)
signal run_failed(reason: String)

enum State { IDLE, INTRO, COMBAT, COLLECT, REWARD, ROUTE, RESOLVING_ROUTE, BOSS_READY, BOSS, CLEARED, FAILED }
const SUPPLY_COINS := 12
const SUPPLY_HEAL := 20.0
const RISK_COINS := 35
const PlayerBody = preload("res://scripts/actors/Player.gd")
const BuildSystem = preload("res://scripts/systems/UpgradeSystem.gd")
const LoopRules = preload("res://scripts/systems/CampaignLoopRules.gd")
const VisitorFactory = preload("res://scripts/campaign/RegionalEnemyFactory.gd")
var run_loop := 1
var pending_births: Array[Node] = []
var state := State.IDLE:
	set(value):
		state = value
		if value not in [State.COMBAT,State.BOSS]: _cancel_pending_births()
		_on_state_changed(value)
var run_seed := 0
var route: StringName = &""
var growth: BuildSystem
var encounters: Array[Dictionary] = []
var encounter_index := 0
var reward_transaction := -1
var collection_remaining := 0.0
var defeated_boss_instance := 0
var _finale_reward_pending := false
var _finale_reward_completed := false

func configure_loop(value: int) -> bool:
	if state!=State.IDLE or value<1 or value>LoopRules.MAX_LOOP: return false
	run_loop=value
	return true

func _create_enemy_actor(kind: int) -> Node:
	var visitor:=LoopRules.foreign_role(kind)
	var actor: Node
	if not visitor.is_empty():
		actor=VisitorFactory.create_actor(visitor.chapter,visitor.role,encounter_index+_chapter_number(),projectile_parent,player)
		actor.world_bounds=world_bounds
	else:
		actor=_create_chapter_enemy_actor(kind)
	_apply_combat_scaling(actor)
	return actor

func _create_chapter_enemy_actor(kind: int) -> Node:
	return super._create_enemy_actor(kind)

func population_load() -> int:
	var load_value:=pending_births.size()
	for actor in active_enemies:
		if not is_instance_valid(actor) or actor.is_queued_for_deletion() or actor.health.current_health<=0: continue
		# A full mote owns two future fragments; reserve both before it dies.
		load_value+=2 if actor.has_signal("offspring_prepared") and actor.get("is_fragment")==false else 1
	return load_value

func _can_spawn_enemy(kind: int) -> bool:
	var cost:=2 if _chapter_number()==4 and kind==EnemyScript.EnemyKind.SCRAPPER else 1
	return population_load()+cost<=LoopRules.MAX_POPULATION_LOAD

func _apply_combat_scaling(actor: Node) -> void:
	if not is_instance_valid(actor) or actor.has_meta(&"campaign_loop_hp"): return
	actor.set_meta(&"campaign_loop_hp",run_loop)
	var health: Node=actor.health
	var bonus: float=health.max_health*(LoopRules.health_scale(run_loop)-1.0)
	if actor.is_inside_tree(): health.increase_max(bonus)
	else: health.max_health+=bonus

func start_run(seed_value: int, target: PlayerBody, enemies: Node2D, projectiles: Node2D, portals: Node2D, build: BuildSystem, navigation: ArenaLayout) -> bool:
	if state != State.IDLE or not is_instance_valid(target) or not is_instance_valid(build) or build.player != target:
		return false
	if not is_instance_valid(enemies) or not is_instance_valid(projectiles) or not is_instance_valid(portals) or not is_instance_valid(navigation) or target.health.current_health <= 0:
		return false
	run_seed = seed_value
	spawn_rng.seed = seed_value
	encounters = _build_encounters()
	if encounters.size()!=3: return false
	growth = build
	world_bounds = navigation.world_bounds
	super.setup_combat(target, enemies, projectiles, portals, navigation)
	target.died.connect(func() -> void: _fail("玩家死亡"))
	target.tree_exiting.connect(_on_combat_owner_departure)
	enemies.tree_exiting.connect(_on_combat_owner_departure)
	_on_run_started()
	_prepare_encounter(0)
	return true

func get_encounter() -> Dictionary:
	return encounters[encounter_index].duplicate(true) if not encounters.is_empty() else {}

func get_attack_targets() -> Array[Node]:
	# Clearance debt is not the weapon roster. Never query other viewport groups.
	if not _birth_context_active(): return []
	var targets: Array[Node] = get_active_enemies().duplicate()
	if is_instance_valid(projectile_parent) and projectile_parent.is_inside_tree() and not projectile_parent.is_queued_for_deletion():
		for hazard in projectile_parent.get_children():
			if hazard is Node2D and not hazard.is_queued_for_deletion() and hazard.is_in_group(&"enemies") and hazard.has_method("take_damage"):
				targets.append(hazard)
	return targets

func _prepare_encounter(index: int) -> void:
	encounter_index = index
	var encounter := get_encounter()
	spawn_queue = LoopRules.compose(_encounter_kinds(encounter),_chapter_number(),run_loop)
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
	if state != State.COMBAT or not pending_births.is_empty() or not spawn_queue.is_empty() or not active_enemies.is_empty() or not active_portals.is_empty():
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
	if _finale_reward_pending:
		_finale_reward_pending = false
		_finale_reward_completed = true
		_prepare_boss()
	elif encounter_index == 0:
		_prepare_encounter(1)
	elif encounter_index == 1:
		state = State.ROUTE
		route_ready.emit()
	else:
		state = State.RESOLVING_ROUTE
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
	if growth.is_chapter_run() and not _finale_reward_completed:
		# Close the synchronous notification/reentry boundary before publishing
		# a new transaction. Risk's previous REWARD is not the new finale.
		state = State.RESOLVING_ROUTE
		if not growth.prepare_chapter_finale(encounter_index + 1):
			_fail("首领前整备奖励无法准备")
			return
		reward_transaction = int(growth.get_settlement_state().transaction)
		_finale_reward_pending = true
		state = State.REWARD
		reward_ready.emit(growth.get_settlement_state())
		return
	state = State.BOSS_READY
	chapter_boss_ready.emit(_boss_label())

func begin_boss() -> bool:
	if state != State.BOSS_READY or not _boss_available():
		return false
	state = State.BOSS
	var boss := _spawn_boss_at(_boss_position())
	if not is_instance_valid(boss):
		_fail("章节首领创建失败")
		return false
	return true

func _on_boss_died(boss: Node, dropped_coins: int, source: StringName) -> void:
	if state != State.BOSS or boss != active_boss or boss.health.current_health > 0 or not boss.death_resolved:
		return
	super._on_boss_died(boss, dropped_coins, source)

func _settle_coin_reward(enemy: Node, coin_value: int) -> int:
	if enemy == active_boss and state == State.BOSS:
		# The final modal pauses homing pickups. Credit only this accepted Boss's
		# reward before publishing clear; kill_resolved already reserves it once.
		growth.add_coins(coin_value)
		return 0
	return coin_value

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
		chapter_cleared.emit(_chapter_number())
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
	var remaining := active_enemies.size() + spawn_queue.size() + pending_births.size()
	for queue in portal_spawn_queues.values():
		remaining += queue.size()
	encounter_status.emit(get_encounter(), remaining)

func _spawn_interval() -> float:
	return float(get_encounter().get("rate",0.2))

# Small concrete chapter policy hooks; not a generic event framework.
func _chapter_number() -> int: return 0
func _build_encounters() -> Array[Dictionary]: return []
func _encounter_kinds(_encounter: Dictionary) -> Array[int]: return []
func _boss_label() -> String: return ""
func _boss_position() -> Vector2: return Vector2.ZERO
func _boss_available() -> bool: return false
func _on_run_started() -> void: pass
func _on_state_changed(_next: State) -> void: pass
func _exit_tree() -> void:
	_cancel_pending_births()
	_on_state_changed(State.FAILED)
func _on_enemy_died(enemy: Node,coins: int,source: StringName) -> void:
	if not active_enemies.has(enemy) or enemy.health.current_health>0 or not enemy.death_resolved: return
	super._on_enemy_died(enemy,coins,source)
func _on_portal_closed(portal: Node) -> void:
	if not active_portals.has(portal): return
	if state in [State.COMBAT,State.BOSS] and not portal_spawn_queues.get(portal.get_instance_id(),[]).is_empty():
		_fail("门户提前关闭，仍有敌人待生成")
	super._on_portal_closed(portal)
func _on_portal_tree_exiting(portal: Node,portal_id: int) -> void:
	var cancelled: bool = active_portals.has(portal) and not portal_spawn_queues.get(portal_id,[]).is_empty()
	super._on_portal_tree_exiting(portal,portal_id)
	if cancelled and state in [State.COMBAT,State.BOSS]: _fail("门户未完成生成而退出")

func _register_enemy(enemy: Node) -> bool:
	if not super._register_enemy(enemy): return false
	# Fragments and incubated offspring enter outside _create_enemy_actor.
	_apply_combat_scaling(enemy)
	if enemy.has_signal("offspring_prepared"):
		enemy.offspring_prepared.connect(_on_offspring_prepared.bind(enemy))
	return true
func _birth_context_active() -> bool:
	return is_inside_tree() and not is_queued_for_deletion() and state in [State.COMBAT,State.BOSS] and is_instance_valid(player) and player.is_inside_tree() and not player.is_queued_for_deletion() and player.health.current_health>0 and is_instance_valid(enemy_parent) and enemy_parent.is_inside_tree() and not enemy_parent.is_queued_for_deletion()
func _on_combat_owner_departure() -> void:
	if is_inside_tree(): _fail("玩家或敌群所有者离场")
func _on_offspring_prepared(children: Array[CharacterBody2D],parent: Node) -> void:
	var accepted: bool = _birth_context_active() and active_enemies.has(parent) and parent.health.current_health<=0 and not parent.death_resolved and parent.get("death_in_progress")==true
	var capacity := 2
	for child in children:
		if not is_instance_valid(child): continue
		if pending_births.has(child) or active_enemies.has(child): continue # Repeat callbacks must not cancel accepted children.
		if not accepted or capacity==0 or child.is_inside_tree() or child.is_queued_for_deletion() or child.get_script()!=parent.get_script() or child.get("is_fragment")!=true:
			child.queue_free(); continue
		_apply_combat_scaling(child) # Establish max HP before ready/health callbacks.
		pending_births.append(child); capacity -= 1
		child.ready.connect(_on_offspring_ready.bind(child),CONNECT_ONE_SHOT)
		child.birth_cancelled.connect(_on_birth_cancelled)
	_emit_wave_status()
func _on_offspring_ready(child: Node) -> void:
	if not pending_births.has(child): return
	if not _birth_context_active() or child.get_parent()!=enemy_parent or not _register_enemy(child):
		pending_births.erase(child); child.queue_free()
		if state in [State.COMBAT,State.BOSS]: _fail("分裂子体无法归属当前战斗")
		return
	pending_births.erase(child); _emit_wave_status()
func _on_birth_cancelled(child: Node) -> void:
	if not pending_births.has(child): return
	pending_births.erase(child)
	_fail("分裂子体出生取消，不能算作清场")
func _cancel_pending_births() -> void:
	var cancelled := pending_births.duplicate(); pending_births.clear()
	for child in cancelled:
		if not is_instance_valid(child): continue
		if child.has_method("disarm"): child.disarm()
		else: child.queue_free()
