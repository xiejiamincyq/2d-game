extends Node
class_name UpgradeSystem

signal progression_state_changed(state: Dictionary)
signal upgrade_applied(label: String)
signal settlement_changed(state: Dictionary)

const FAMILY_IDS: Array[String] = ["ballistics", "mobility", "automation"]
const FAMILY_LABELS: Dictionary = {
	"ballistics": "火力",
	"mobility": "机动",
	"automation": "工程",
}
const SETTLEMENT_PRICE_STEP := 0.55
const EVOLUTION_MIN_WAVE := 4
const EVOLUTION_MIN_FAMILY_LEVEL := 5

var player: Node
var coins: int = 0
var family_levels: Dictionary = {
	"ballistics": 1,
	"mobility": 1,
	"automation": 1,
}
var upgrade_counts: Dictionary = {}
var acquired_evolution_id: String = ""

# The unified settlement is the authoritative Phase 3 progression transaction.
var settlement_wave: int = 0
var settlement_generation: int = 0
var settlement_offers: Array[Dictionary] = []
var settlement_reward_claimed: bool = false
var settlement_closed: bool = true

var upgrade_pool: Array[Dictionary] = [
	# Ballistics: six normal cards.
	{"id": "damage", "label": "超频弹芯", "description": "子弹伤害 +12%", "family": "ballistics", "kind": "core", "max_rank": 5, "base_cost": 32},
	{"id": "fire_rate", "label": "灼热枪管", "description": "射速 +10%", "family": "ballistics", "kind": "core", "max_rank": 5, "base_cost": 34},
	{"id": "bullet_speed", "label": "线圈加速器", "description": "弹速 +20%，子弹伤害 +5%", "family": "ballistics", "kind": "support", "max_rank": 4, "base_cost": 28},
	{"id": "pierce", "label": "轨道穿甲", "description": "穿透 +1，子弹伤害 +4%", "family": "ballistics", "kind": "support", "max_rank": 4, "base_cost": 40},
	{"id": "gun_lines", "label": "分裂枪膛", "description": "枪线 +1，单发伤害 -8%", "family": "ballistics", "kind": "core", "max_rank": 2, "base_cost": 62},
	{"id": "siege_rounds", "label": "攻城弹头", "description": "子弹伤害 +20%，射速 -5%", "family": "ballistics", "kind": "core", "max_rank": 3, "base_cost": 46},

	# Mobility: six normal cards.
	{"id": "move_speed", "label": "伺服腿甲", "description": "移速 +8%，地刺伤害 +6%", "family": "mobility", "kind": "support", "max_rank": 5, "base_cost": 30},
	{"id": "mine", "label": "静滞地刺", "description": "首次解锁；后续强化伤害与持续时间", "family": "mobility", "kind": "core", "max_rank": 5, "base_cost": 52},
	{"id": "spike_density", "label": "裂地密度", "description": "地刺间距 -12%", "family": "mobility", "kind": "core", "requires": "mine", "max_rank": 4, "base_cost": 38},
	{"id": "dash_cooldown", "label": "冲刺冷却", "description": "冲刺冷却 -12%，冲刺伤害 +8%", "family": "mobility", "kind": "support", "max_rank": 4, "base_cost": 38},
	{"id": "dash_impact", "label": "动能撞角", "description": "冲刺距离 +8%，冲刺伤害 +18%", "family": "mobility", "kind": "core", "max_rank": 4, "base_cost": 44},
	{"id": "recovery_route", "label": "回收路线", "description": "拾取范围 +15%，移速 +4%", "family": "mobility", "kind": "support", "max_rank": 4, "base_cost": 26},

	# Automation: six normal cards.
	{"id": "drone", "label": "无人机部署", "description": "无人机 +1，单机伤害 +5%", "family": "automation", "kind": "core", "max_rank": 4, "base_cost": 58},
	{"id": "drone_damage", "label": "激光放大器", "description": "无人机激光伤害 +18%", "family": "automation", "kind": "core", "requires": "drone", "max_rank": 5, "base_cost": 38},
	{"id": "arc", "label": "电弧启动器", "description": "首次解锁；后续强化伤害与半径", "family": "automation", "kind": "core", "max_rank": 5, "base_cost": 50},
	{"id": "arc_capacitor", "label": "电弧电容", "description": "电弧伤害 +15%，半径 +14", "family": "automation", "kind": "core", "requires": "arc", "max_rank": 5, "base_cost": 40},
	{"id": "pickup", "label": "磁吸网格", "description": "拾取范围 +25%，电弧半径 +8", "family": "automation", "kind": "support", "max_rank": 4, "base_cost": 28},
	{"id": "health", "label": "维修矩阵", "description": "最大生命 +20%，修复部分损伤", "family": "automation", "kind": "support", "max_rank": 3, "base_cost": 44},

	# Evolutions are guaranteed candidates only after their family qualifies.
	{"id": "orbital_storm", "label": "轨道风暴", "description": "终极进化：周期性发射环形副弹幕", "family": "ballistics", "kind": "evolution", "max_rank": 1, "base_cost": 120},
	{"id": "rift_overdrive", "label": "裂地超载", "description": "终极进化：冲刺铺设毁灭性地刺走廊", "family": "mobility", "kind": "evolution", "max_rank": 1, "base_cost": 120},
	{"id": "thunder_matrix", "label": "雷网矩阵", "description": "终极进化：无人机与电弧形成高频电网", "family": "automation", "kind": "evolution", "max_rank": 1, "base_cost": 120},
]

func setup(target_player: Node) -> void:
	player = target_player
	_sync_build_family_levels()
	_emit_progression_changed()

func get_progression_state() -> Dictionary:
	return {
		"coins": coins,
		"family_levels": family_levels.duplicate(true),
	}

func add_coins(amount: int) -> bool:
	if player == null or amount <= 0:
		return false
	coins += amount
	_emit_progression_changed()
	_emit_settlement_changed()
	return true

func spend_coins(amount: int) -> bool:
	if player == null or amount <= 0 or amount > coins:
		return false
	coins -= amount
	_emit_progression_changed()
	_emit_settlement_changed()
	return true

func prepare_settlement(completed_wave: int) -> bool:
	if player == null or completed_wave <= 0 or completed_wave <= settlement_wave:
		return false
	if settlement_wave > 0 and not settlement_closed:
		return false
	var selected_evolution := _select_evolution_candidate(completed_wave)
	var price_multiplier := 1.0 + SETTLEMENT_PRICE_STEP * float(completed_wave - 1)
	var staged_offers: Array[Dictionary] = []
	for family_id in FAMILY_IDS:
		var family_cards: Array[Dictionary] = []
		for card_value in upgrade_pool:
			var card: Dictionary = card_value
			if not _is_card_unlocked(card):
				continue
			if String(card.get("family", "")) != family_id or String(card.get("kind", "")) == "evolution":
				continue
			if not _is_upgrade_capped(String(card.get("id", ""))):
				family_cards.append(card)
		family_cards.shuffle()
		var family_selection: Array[Dictionary] = []
		if not selected_evolution.is_empty() and String(selected_evolution.get("family", "")) == family_id:
			family_selection.append(selected_evolution)
		for card in family_cards:
			if family_selection.size() >= 2:
				break
			family_selection.append(card)
		if family_selection.size() != 2:
			return false
		for card in family_selection:
			var offer := card.duplicate(true)
			offer["cost"] = maxi(1, roundi(float(offer.get("base_cost", 1)) * price_multiplier))
			offer["sold"] = false
			offer["claimed"] = false
			offer["purchased"] = false
			staged_offers.append(offer)
	settlement_wave = completed_wave
	settlement_generation += 1
	settlement_reward_claimed = false
	settlement_closed = false
	settlement_offers.clear()
	for staged_offer in staged_offers:
		staged_offer["transaction"] = settlement_generation
		staged_offer["_settlement_transaction"] = settlement_generation
		settlement_offers.append(staged_offer)
	_emit_settlement_changed()
	return true

func get_settlement_state() -> Dictionary:
	var grouped_families: Array[Dictionary] = []
	for family_id in FAMILY_IDS:
		var visible_offers: Array[Dictionary] = []
		for offer_value in settlement_offers:
			var offer: Dictionary = offer_value
			if String(offer.get("family", "")) != family_id:
				continue
			var visible_offer := offer.duplicate(true)
			var sold := bool(visible_offer.get("sold", false))
			var capped := _is_upgrade_capped(String(visible_offer.get("id", "")))
			visible_offer["rank"] = int(upgrade_counts.get(String(visible_offer.get("id", "")), 0))
			visible_offer["capped"] = capped
			visible_offer["free_available"] = not settlement_reward_claimed and not sold and not capped and not settlement_closed
			visible_offer["affordable"] = settlement_reward_claimed and not sold and not capped and not settlement_closed and coins >= int(visible_offer.get("cost", 0))
			visible_offers.append(visible_offer)
		grouped_families.append({
			"id": family_id,
			"label": String(FAMILY_LABELS.get(family_id, family_id)),
			"offers": visible_offers,
		})
	return {
		"wave": settlement_wave,
		"coins": coins,
		"transaction": settlement_generation,
		"reward_claimed": settlement_reward_claimed,
		"can_close": settlement_reward_claimed and not settlement_closed,
		"closed": settlement_closed,
		"family_levels": family_levels.duplicate(true),
		"families": grouped_families,
	}

func claim_free_offer(request: Dictionary) -> bool:
	if player == null or settlement_closed or settlement_reward_claimed:
		return false
	var offer_index := _find_settlement_offer_index(request)
	if offer_index < 0:
		return false
	var offer: Dictionary = settlement_offers[offer_index]
	var card_id := String(offer.get("id", ""))
	if bool(offer.get("sold", false)) or _is_upgrade_capped(card_id):
		return false
	settlement_reward_claimed = true
	offer["sold"] = true
	offer["claimed"] = true
	settlement_offers[offer_index] = offer
	_apply_card(card_id)
	var family_id := String(offer.get("family", ""))
	family_levels[family_id] = int(family_levels.get(family_id, 1)) + 1
	_record_evolution_if_needed(offer)
	_sync_build_family_levels()
	upgrade_applied.emit(String(offer.get("label", "战斗模块")))
	_emit_progression_changed()
	_emit_settlement_changed()
	return true

func purchase_settlement_offer(request: Dictionary) -> bool:
	if player == null or settlement_closed or not settlement_reward_claimed:
		return false
	var offer_index := _find_settlement_offer_index(request)
	if offer_index < 0:
		return false
	var offer: Dictionary = settlement_offers[offer_index]
	var card_id := String(offer.get("id", ""))
	var cost := int(offer.get("cost", 0))
	if bool(offer.get("sold", false)) or _is_upgrade_capped(card_id) or cost <= 0 or cost > coins:
		return false
	coins -= cost
	offer["sold"] = true
	offer["purchased"] = true
	settlement_offers[offer_index] = offer
	_apply_card(card_id)
	_record_evolution_if_needed(offer)
	upgrade_applied.emit(String(offer.get("label", "战斗模块")))
	_emit_progression_changed()
	_emit_settlement_changed()
	return true

func complete_settlement(request: Dictionary) -> bool:
	if player == null or settlement_closed or not settlement_reward_claimed:
		return false
	if _get_request_transaction(request) != settlement_generation:
		return false
	settlement_closed = true
	_emit_settlement_changed()
	return true

func _find_settlement_offer_index(request: Dictionary) -> int:
	var request_id := String(request.get("id", ""))
	if request_id.is_empty() or _get_request_transaction(request) != settlement_generation:
		return -1
	for index in range(settlement_offers.size()):
		var offer: Dictionary = settlement_offers[index]
		if String(offer.get("id", "")) == request_id and int(offer.get("transaction", -1)) == settlement_generation:
			return index
	return -1

func _get_request_transaction(request: Dictionary) -> int:
	return int(request.get("transaction", request.get("_settlement_transaction", -1)))

func _select_evolution_candidate(completed_wave: int) -> Dictionary:
	if completed_wave < EVOLUTION_MIN_WAVE or not acquired_evolution_id.is_empty():
		return {}
	var selected_family := ""
	var selected_level := -1
	for family_id in FAMILY_IDS:
		var family_level := int(family_levels.get(family_id, 1))
		if family_level >= EVOLUTION_MIN_FAMILY_LEVEL and family_level > selected_level:
			selected_family = family_id
			selected_level = family_level
	if selected_family.is_empty():
		return {}
	for card_value in upgrade_pool:
		var card: Dictionary = card_value
		if String(card.get("kind", "")) == "evolution" and String(card.get("family", "")) == selected_family and not _is_upgrade_capped(String(card.get("id", ""))):
			return card
	return {}

func _record_evolution_if_needed(offer: Dictionary) -> void:
	if String(offer.get("kind", "")) == "evolution" and acquired_evolution_id.is_empty():
		acquired_evolution_id = String(offer.get("id", ""))

func _apply_card(card_id: String) -> void:
	_apply_upgrade_effect(card_id)
	upgrade_counts[card_id] = int(upgrade_counts.get(card_id, 0)) + 1

func _apply_upgrade_effect(card_id: String) -> void:
	match card_id:
		"damage":
			player.weapon_damage *= 1.12
		"fire_rate":
			player.fire_rate *= 1.10
		"bullet_speed":
			player.projectile_speed *= 1.20
			player.weapon_damage *= 1.05
		"pierce":
			player.projectile_pierce += 1
			player.weapon_damage *= 1.04
		"gun_lines":
			player.weapon_lines += 1
			player.weapon_damage *= 0.92
		"siege_rounds":
			player.weapon_damage *= 1.20
			player.fire_rate *= 0.95
		"move_speed":
			player.move_speed *= 1.08
			player.spike_damage *= 1.06
		"mine":
			if player.mine_level <= 0:
				player.mine_level = 1
				player._reset_spike_path()
			else:
				player.mine_level += 1
				player.spike_damage *= 1.15
				player.spike_duration += 0.5
		"spike_density":
			player.spike_spacing = maxf(28.0, player.spike_spacing * 0.88)
		"dash_cooldown":
			player.dash_cooldown = maxf(1.0, player.dash_cooldown * 0.88)
			player.dash_melee_damage *= 1.08
		"dash_impact":
			player.dash_distance *= 1.08
			player.dash_melee_damage *= 1.18
		"recovery_route":
			player.pickup_radius *= 1.15
			player.move_speed *= 1.04
		"drone":
			player.drone_count += 1
			player.drone_damage *= 1.05
		"drone_damage":
			player.drone_damage *= 1.18
		"arc":
			if player.arc_pulse_level <= 0:
				player.arc_pulse_level = 1
			else:
				player.arc_pulse_level += 1
				player.arc_damage *= 1.12
				player.arc_radius += 10.0
		"arc_capacitor":
			player.arc_damage *= 1.15
			player.arc_radius += 14.0
		"pickup":
			player.pickup_radius *= 1.25
			player.arc_radius += 8.0
		"health":
			var previous_max: float = player.health.max_health
			var missing_health: float = maxf(0.0, previous_max - player.health.current_health)
			var added_health := previous_max * 0.20
			player.increase_max_health(added_health)
			player.heal(added_health + missing_health * 0.20)
		"orbital_storm", "rift_overdrive", "thunder_matrix":
			if player.has_method("activate_build_evolution"):
				player.call("activate_build_evolution", card_id)

func _is_upgrade_capped(card_id: String) -> bool:
	var card := _find_catalog_entry(card_id)
	if card.is_empty():
		return true
	return int(upgrade_counts.get(card_id, 0)) >= int(card.get("max_rank", 1))

func _is_card_unlocked(card: Dictionary) -> bool:
	var prerequisite := String(card.get("requires", ""))
	return prerequisite.is_empty() or int(upgrade_counts.get(prerequisite, 0)) > 0

func _find_catalog_entry(card_id: String) -> Dictionary:
	for card_value in upgrade_pool:
		var card: Dictionary = card_value
		if String(card.get("id", "")) == card_id:
			return card
	return {}

func _sync_build_family_levels() -> void:
	if player != null and player.has_method("set_build_family_levels"):
		player.call("set_build_family_levels", family_levels.duplicate(true))

func _emit_progression_changed() -> void:
	progression_state_changed.emit(get_progression_state())

func _emit_settlement_changed() -> void:
	if settlement_wave > 0:
		settlement_changed.emit(get_settlement_state())
