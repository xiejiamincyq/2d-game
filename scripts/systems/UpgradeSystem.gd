extends Node
class_name UpgradeSystem

signal experience_changed(current: int, required: int, level: int)
signal choices_ready(choices: Array[Dictionary])
signal upgrade_applied(label: String)

var player: Node
var level: int = 1
var experience: int = 0
var required_experience: int = 10

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
	{"id": "mine", "label": "静滞地刺", "description": "首次获得地刺；再次选择提高地刺伤害和持续时间"}
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
		required_experience = int(ceil(float(required_experience) * 1.23 + 2.0))
		_present_choices()
		break
	experience_changed.emit(experience, required_experience, level)

func apply_upgrade(choice: Dictionary) -> void:
	if player == null:
		return
	match String(choice.get("id", "")):
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
	upgrade_applied.emit(String(choice.get("label", "战斗模块")))
	if get_tree().paused:
		get_tree().paused = false
	experience_changed.emit(experience, required_experience, level)

func _present_choices() -> void:
	var shuffled := upgrade_pool.duplicate()
	shuffled.shuffle()
	var choices: Array[Dictionary] = []
	for index in range(mini(3, shuffled.size())):
		choices.append(shuffled[index])
	get_tree().paused = true
	choices_ready.emit(choices)
