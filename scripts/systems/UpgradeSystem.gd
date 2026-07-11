extends Node
class_name UpgradeSystem

signal experience_changed(current: int, required: int, level: int)
signal choices_ready(choices: Array[Dictionary])
signal upgrade_applied(label: String)
signal upgrade_queue_completed

const EXPERIENCE_MULTIPLIER := 2

var player: Node
var level: int = 1
var experience: int = 0
var base_required_experience: int = 10
var required_experience: int = base_required_experience * EXPERIENCE_MULTIPLIER
var pending_choices: Array[Dictionary] = []
var pending_upgrade_count: int = 0
var awaiting_choice: bool = false
var choice_generation: int = 0
var upgrade_counts: Dictionary = {}

var upgrade_pool: Array[Dictionary] = [
	{"id": "damage", "label": "超频弹芯", "description": "主武器伤害 +25%"},
	{"id": "fire_rate", "label": "灼热枪管", "description": "射速 +50%"},
	{"id": "gun_lines", "label": "分裂枪线", "description": "主武器枪线 +1"},
	{"id": "wide_lines", "label": "扇形校准", "description": "主武器枪线 +1，伤害 +10%"},
	{"id": "pierce", "label": "轨道穿甲", "description": "子弹穿透 +1"},
	{"id": "bullet_speed", "label": "线圈加速器", "description": "弹速 +50%"},
	{"id": "health", "label": "合成脏器", "description": "最大生命 +50%，并回满血"},
	{"id": "move_speed", "label": "伺服腿甲", "description": "移动速度 +25%"},
	{"id": "pickup", "label": "磁吸网格", "description": "拾取范围 +50%"},
	{"id": "drone", "label": "废铁无人机", "description": "增加无人机，并提高持续激光秒伤"},
	{"id": "arc", "label": "电弧浪涌", "description": "扩大电弧范围并提高伤害"},
	{"id": "mine", "label": "静滞地刺", "description": "首次获得地刺；再次选择提高地刺伤害和持续时间"},
]

func setup(target_player: Node) -> void:
	player = target_player
	experience_changed.emit(experience, required_experience, level)

func add_experience(amount: int) -> void:
	if player == null or amount <= 0:
		return
	experience += amount
	while experience >= required_experience:
		experience -= required_experience
		level += 1
		base_required_experience = int(ceil(float(base_required_experience) * 1.23 + 2.0))
		required_experience = base_required_experience * EXPERIENCE_MULTIPLIER
		pending_upgrade_count += 1
	experience_changed.emit(experience, required_experience, level)
	if pending_upgrade_count > 0 and not awaiting_choice:
		_present_next_choices()

func apply_upgrade(choice: Dictionary) -> bool:
	if player == null or not awaiting_choice:
		return false
	var choice_id := String(choice.get("id", ""))
	var transaction := int(choice.get("_transaction", -1))
	var accepted_choice: Dictionary = {}
	for pending_choice in pending_choices:
		if String(pending_choice.get("id", "")) == choice_id and int(pending_choice.get("_transaction", -2)) == transaction:
			accepted_choice = pending_choice
			break
	if accepted_choice.is_empty() or _is_upgrade_capped(choice_id):
		return false
	awaiting_choice = false
	pending_choices.clear()
	_apply_upgrade_effect(choice_id)
	upgrade_counts[choice_id] = int(upgrade_counts.get(choice_id, 0)) + 1
	pending_upgrade_count = maxi(0, pending_upgrade_count - 1)
	upgrade_applied.emit(String(accepted_choice.get("label", "战斗模块")))
	experience_changed.emit(experience, required_experience, level)
	if pending_upgrade_count > 0:
		_present_next_choices()
	else:
		upgrade_queue_completed.emit()
	return true

func _apply_upgrade_effect(choice_id: String) -> void:
	match choice_id:
		"damage":
			player.weapon_damage *= 1.25
		"fire_rate":
			player.fire_rate *= 1.5
		"gun_lines":
			player.weapon_lines += 1
		"wide_lines":
			player.weapon_lines += 1
			player.weapon_damage *= 1.1
		"pierce":
			player.projectile_pierce += 1
		"bullet_speed":
			player.projectile_speed *= 1.5
		"health":
			player.increase_max_health(player.health.max_health * 0.5)
			player.heal(player.health.max_health)
		"move_speed":
			player.move_speed *= 1.25
		"pickup":
			player.pickup_radius *= 1.5
		"drone":
			player.drone_count += 1
			player.drone_damage *= 1.35
		"arc":
			player.arc_pulse_level += 1
			player.arc_damage *= 1.45
			player.arc_radius += 52.0
		"mine":
			if player.mine_level <= 0:
				player.mine_level = 1
				player._reset_spike_path()
			else:
				player.mine_level += 1
				player.spike_damage *= 1.45
				player.spike_duration += 3.0

func _present_next_choices() -> void:
	var available: Array[Dictionary] = []
	for choice in upgrade_pool:
		if not _is_upgrade_capped(String(choice.get("id", ""))):
			available.append(choice)
	available.shuffle()
	pending_choices.clear()
	choice_generation += 1
	for index in range(mini(3, available.size())):
		var transaction_choice: Dictionary = available[index].duplicate(true)
		transaction_choice["_transaction"] = choice_generation
		pending_choices.append(transaction_choice)
	awaiting_choice = not pending_choices.is_empty()
	if not awaiting_choice:
		pending_upgrade_count = 0
		upgrade_queue_completed.emit()
		return
	choices_ready.emit(pending_choices.duplicate(true))

func _is_upgrade_capped(choice_id: String) -> bool:
	match choice_id:
		"fire_rate":
			return int(upgrade_counts.get(choice_id, 0)) >= 12
		"gun_lines", "wide_lines":
			return _get_player_int(&"weapon_lines") >= 5
		"pierce":
			return _get_player_int(&"projectile_pierce") >= 6
		"drone":
			return _get_player_int(&"drone_count") >= 4
		"arc":
			return _get_player_int(&"arc_pulse_level") >= 8
		"mine":
			return _get_player_int(&"mine_level") >= 8
	return false

func _get_player_int(property: StringName) -> int:
	var value: Variant = player.get(property)
	return int(value) if value != null else 0
