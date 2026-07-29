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
const FAMILY_STARTER_CARD_IDS: Dictionary = {
	"ballistics": [],
	"mobility": [],
	"automation": ["drone", "arc"],
}
const SETTLEMENT_PRICE_STEP := 0.55
const EVOLUTION_MIN_WAVE := 4
const EVOLUTION_MIN_FAMILY_LEVEL := 5
const LEGACY_CARD_ID_MAP: Dictionary = {
	"recovery_route": "spike_resonance",
	"pickup": "arc_relay",
}

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
	{"id": "damage", "label": "超频弹芯", "description": "子弹伤害 +14%", "family": "ballistics", "kind": "core", "max_rank": 5, "base_cost": 32},
	{"id": "fire_rate", "label": "灼热枪管", "description": "射速 +9%", "family": "ballistics", "kind": "core", "max_rank": 5, "base_cost": 34},
	{"id": "bullet_speed", "label": "线圈加速器", "description": "弹速 +18%，子弹伤害 +4%", "family": "ballistics", "kind": "support", "max_rank": 4, "base_cost": 28},
	{"id": "pierce", "label": "轨道穿甲", "description": "穿透 +1，子弹伤害 +5%", "family": "ballistics", "kind": "support", "max_rank": 4, "base_cost": 40},
	{"id": "gun_lines", "label": "分裂枪膛", "description": "枪线 +1，单发伤害 -12%", "family": "ballistics", "kind": "core", "max_rank": 2, "base_cost": 62},
	{"id": "siege_rounds", "label": "攻城弹头", "description": "子弹伤害 +24%，射速 -7%", "family": "ballistics", "kind": "core", "max_rank": 3, "base_cost": 46},

	# Mobility: six normal cards.
	{"id": "move_speed", "label": "伺服腿甲", "description": "移速 +9%，地刺伤害 +8%", "family": "mobility", "kind": "support", "requires": "mine", "max_rank": 5, "base_cost": 30},
	{"id": "mine", "label": "静滞地刺", "description": "首次解锁；后续伤害 +16%、持续时间 +0.6s、半径 +2", "family": "mobility", "kind": "core", "max_rank": 5, "base_cost": 52},
	{"id": "spike_density", "label": "裂地密度", "description": "地刺间距 -16%，触发间隔 -3%", "family": "mobility", "kind": "core", "requires": "mine", "max_rank": 4, "base_cost": 38},
	{"id": "dash_cooldown", "label": "冲刺冷却", "description": "冲刺冷却 -7%，冲刺伤害 +4%", "family": "mobility", "kind": "support", "max_rank": 4, "base_cost": 38},
	{"id": "dash_impact", "label": "动能撞角", "description": "冲刺距离 +8%，冲刺伤害 +10%", "family": "mobility", "kind": "core", "max_rank": 4, "base_cost": 44},
	{"id": "spike_resonance", "label": "地脉共振", "description": "地刺伤害 +8%、半径 +5、触发间隔 -10%", "family": "mobility", "kind": "support", "requires": "mine", "max_rank": 4, "base_cost": 30},

	# Automation: eight normal cards.
	{"id": "drone_pierce", "label": "穿透棱镜", "description": "无人机激光贯穿沿途敌人", "family": "automation", "kind": "support", "requires": "drone", "max_rank": 1, "base_cost": 48},
	{"id": "drone", "label": "无人机部署", "description": "无人机 +1，单机伤害 +3%", "family": "automation", "kind": "core", "max_rank": 4, "base_cost": 52},
	{"id": "drone_damage", "label": "激光放大器", "description": "无人机激光伤害 +16%", "family": "automation", "kind": "core", "requires": "drone", "max_rank": 5, "base_cost": 34},
	{"id": "arc", "label": "电弧启动器", "description": "首次解锁；后续强化伤害与半径", "family": "automation", "kind": "core", "max_rank": 5, "base_cost": 45},
	{"id": "arc_capacitor", "label": "电弧电容", "description": "电弧伤害 +14%、半径 +18、蓄能 -6%", "family": "automation", "kind": "core", "requires": "arc", "max_rank": 5, "base_cost": 36},
	{"id": "arc_relay", "label": "电弧继电器", "description": "电弧伤害 +8%、半径 +8、蓄能 -16%", "family": "automation", "kind": "support", "requires": "arc", "max_rank": 4, "base_cost": 30},
	{"id": "health", "label": "维修矩阵", "description": "最大生命 +20%，修复部分损伤", "family": "automation", "kind": "support", "max_rank": 3, "base_cost": 40},
	{"id": "shield_capacity", "label": "护盾扩容", "description": "护盾上限 +20，并立即补满护盾", "family": "automation", "kind": "support", "max_rank": 3, "base_cost": 42},

	# Evolutions are guaranteed candidates only after their family qualifies.
	{"id": "orbital_storm", "label": "榴弹协议", "description": "终极进化：射速 -80%、弹速 -75%，榴弹近敌爆炸造成 300% 小范围伤害", "family": "ballistics", "kind": "evolution", "max_rank": 1, "base_cost": 120},
	{"id": "rift_overdrive", "label": "顶级刺客", "description": "终极进化：冲刺后获得 1.2s 隐身与 30% 移速，并留下 4s 减速叠层灼烧紫焰", "family": "mobility", "kind": "evolution", "requires": "mine", "max_rank": 1, "base_cost": 120},
	{"id": "thunder_matrix", "label": "雷网矩阵", "description": "终极进化：电弧覆盖全屏但伤害 -30%，无人机激光变紫且伤害 +80%", "family": "automation", "kind": "evolution", "requires": ["drone", "arc"], "max_rank": 1, "base_cost": 120},
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

func get_snapshot_state() -> Dictionary:
	return {
		"coins": coins,
		"family_levels": family_levels.duplicate(true),
		"upgrade_counts": upgrade_counts.duplicate(true),
		"evolution": acquired_evolution_id,
		"settlement": {
			"wave": settlement_wave,
			"generation": settlement_generation,
			"offers": settlement_offers.duplicate(true),
			"reward_claimed": settlement_reward_claimed,
			"closed": settlement_closed,
		},
	}

func restore_snapshot_state(state: Dictionary) -> bool:
	if player == null or not _validate_snapshot_state(state):
		return false
	coins = int(state["coins"])
	family_levels = (state["family_levels"] as Dictionary).duplicate(true)
	upgrade_counts.clear()
	var saved_counts := _canonicalize_upgrade_counts(state["upgrade_counts"] as Dictionary)
	for card_value in upgrade_pool:
		var card: Dictionary = card_value
		var card_id := String(card.get("id", ""))
		for rank in range(int(saved_counts.get(card_id, 0))):
			_apply_upgrade_effect(card_id)
		if int(saved_counts.get(card_id, 0)) > 0:
			upgrade_counts[card_id] = int(saved_counts[card_id])
	acquired_evolution_id = String(state["evolution"])
	var settlement: Dictionary = state["settlement"]
	settlement_wave = int(settlement["wave"])
	settlement_generation = int(settlement["generation"])
	settlement_reward_claimed = bool(settlement["reward_claimed"])
	settlement_closed = bool(settlement["closed"])
	settlement_offers.clear()
	for offer_value in settlement["offers"]:
		var restored_offer := (offer_value as Dictionary).duplicate(true)
		var restored_id := _canonical_card_id(String(restored_offer.get("id", "")))
		if restored_id != String(restored_offer.get("id", "")):
			var replacement := _find_catalog_entry(restored_id)
			restored_offer["id"] = restored_id
			for key in ["label", "description", "family", "kind", "max_rank", "requires"]:
				if replacement.has(key):
					restored_offer[key] = replacement[key]
				else:
					restored_offer.erase(key)
		settlement_offers.append(restored_offer)
	_sync_build_family_levels()
	_emit_progression_changed()
	_emit_settlement_changed()
	return true

func _validate_snapshot_state(state: Dictionary) -> bool:
	for key in ["coins", "family_levels", "upgrade_counts", "evolution", "settlement"]:
		if not state.has(key):
			return false
	if int(state["coins"]) < 0 or not state["family_levels"] is Dictionary or not state["upgrade_counts"] is Dictionary:
		return false
	var saved_levels: Dictionary = state["family_levels"]
	if saved_levels.size() != FAMILY_IDS.size():
		return false
	for family_id in FAMILY_IDS:
		if int(saved_levels.get(family_id, 0)) < 1:
			return false
	var saved_counts: Dictionary = state["upgrade_counts"]
	for card_id_value in saved_counts:
		var card_id := _canonical_card_id(String(card_id_value))
		var card := _find_catalog_entry(card_id)
		var count := int(saved_counts[card_id_value])
		if card.is_empty() or count < 1 or count > int(card.get("max_rank", 1)):
			return false
	var canonical_counts := _canonicalize_upgrade_counts(saved_counts)
	for card_id_value in canonical_counts:
		var card := _find_catalog_entry(String(card_id_value))
		if int(canonical_counts[card_id_value]) > int(card.get("max_rank", 1)):
			return false
	var evolution := String(state["evolution"])
	if not evolution.is_empty() and evolution not in ["orbital_storm", "rift_overdrive", "thunder_matrix"]:
		return false
	if not state["settlement"] is Dictionary:
		return false
	var settlement: Dictionary = state["settlement"]
	for key in ["wave", "generation", "offers", "reward_claimed", "closed"]:
		if not settlement.has(key):
			return false
	return settlement["offers"] is Array

func _canonical_card_id(card_id: String) -> String:
	return String(LEGACY_CARD_ID_MAP.get(card_id, card_id))

func _canonicalize_upgrade_counts(saved_counts: Dictionary) -> Dictionary:
	var canonical_counts: Dictionary = {}
	for saved_id_value in saved_counts:
		var canonical_id := _canonical_card_id(String(saved_id_value))
		canonical_counts[canonical_id] = int(canonical_counts.get(canonical_id, 0)) + int(saved_counts[saved_id_value])
	return canonical_counts

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
		var family_selection: Array[Dictionary] = []
		if not selected_evolution.is_empty() and String(selected_evolution.get("family", "")) == family_id:
			family_selection.append(selected_evolution)
		for starter_id_value in FAMILY_STARTER_CARD_IDS.get(family_id, []):
			if family_selection.size() >= 2 or int(upgrade_counts.get(String(starter_id_value), 0)) > 0:
				continue
			for card_index in range(family_cards.size()):
				if String(family_cards[card_index].get("id", "")) == String(starter_id_value):
					family_selection.append(family_cards[card_index])
					family_cards.remove_at(card_index)
					break
		family_cards.shuffle()
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
		if String(card.get("kind", "")) == "evolution" and String(card.get("family", "")) == selected_family and _is_card_unlocked(card) and not _is_upgrade_capped(String(card.get("id", ""))):
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
			player.weapon_damage *= 1.14
		"fire_rate":
			player.fire_rate *= 1.09
		"bullet_speed":
			player.projectile_speed *= 1.18
			player.weapon_damage *= 1.04
		"pierce":
			player.projectile_pierce += 1
			player.weapon_damage *= 1.05
		"gun_lines":
			player.weapon_lines += 1
			player.weapon_damage *= 0.88
		"siege_rounds":
			player.weapon_damage *= 1.24
			player.fire_rate *= 0.93
		"move_speed":
			player.move_speed *= 1.09
			player.spike_damage *= 1.08
		"mine":
			if player.mine_level <= 0:
				player.mine_level = 1
				player._reset_spike_path()
			else:
				player.mine_level += 1
				player.spike_damage *= 1.16
				player.spike_duration += 0.6
				player.spike_radius += 2.0
		"spike_density":
			player.spike_spacing = maxf(24.0, player.spike_spacing * 0.84)
			player.spike_tick_interval = maxf(0.22, player.spike_tick_interval * 0.97)
		"dash_cooldown":
			player.dash_cooldown = maxf(1.0, player.dash_cooldown * 0.93)
			player.dash_melee_damage *= 1.04
		"dash_impact":
			player.dash_distance *= 1.08
			player.dash_melee_damage *= 1.10
		"spike_resonance":
			player.spike_damage *= 1.08
			player.spike_radius += 5.0
			player.spike_tick_interval = maxf(0.22, player.spike_tick_interval * 0.90)
		"drone":
			player.drone_count += 1
			player.drone_damage *= 1.03
		"drone_damage":
			player.drone_damage *= 1.16
		"drone_pierce":
			player.drone_laser_piercing = true
		"arc":
			if player.arc_pulse_level <= 0:
				player.arc_pulse_level = 1
			else:
				player.arc_pulse_level += 1
				player.arc_damage *= 1.16
				player.arc_radius += 14.0
		"arc_capacitor":
			player.arc_damage *= 1.14
			player.arc_radius += 18.0
			player.arc_base_interval = maxf(1.15, player.arc_base_interval * 0.94)
		"arc_relay":
			player.arc_damage *= 1.08
			player.arc_radius += 8.0
			player.arc_base_interval = maxf(1.15, player.arc_base_interval * 0.84)
		"health":
			var previous_max: float = player.health.max_health
			var missing_health: float = maxf(0.0, previous_max - player.health.current_health)
			var added_health := previous_max * 0.20
			player.increase_max_health(added_health)
			player.heal(added_health + missing_health * 0.20)
		"shield_capacity":
			player.increase_max_shield(20.0, true)
		"orbital_storm", "rift_overdrive", "thunder_matrix":
			if player.has_method("activate_build_evolution"):
				player.call("activate_build_evolution", card_id)

func _is_upgrade_capped(card_id: String) -> bool:
	var card := _find_catalog_entry(card_id)
	if card.is_empty():
		return true
	return int(upgrade_counts.get(card_id, 0)) >= int(card.get("max_rank", 1))

func _is_card_unlocked(card: Dictionary) -> bool:
	var prerequisites: Variant = card.get("requires", "")
	if prerequisites is Array:
		for prerequisite_value in prerequisites:
			if int(upgrade_counts.get(String(prerequisite_value), 0)) <= 0:
				return false
		return true
	var prerequisite := String(prerequisites)
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
