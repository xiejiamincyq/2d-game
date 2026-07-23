extends Node
class_name RunSnapshotStore

const VERSION := 1
const DEFAULT_PATH := "user://five_minute_overdrive_run_v1.json"
const MAX_STAGE := 5
const MAX_ELAPSED_SECONDS := 86400.0
const BOUNDARIES: Array[String] = ["wave_intro", "settlement"]
const FAMILY_IDS: Array[String] = ["ballistics", "mobility", "automation"]
const EVOLUTION_IDS: Array[String] = ["", "orbital_storm", "rift_overdrive", "thunder_matrix"]
const FORBIDDEN_RUNTIME_KEYS: Array[String] = [
	"enemies", "projectiles", "portals", "pickups", "vfx", "audio_loops", "camera_offset",
]
const CARD_LIMITS: Dictionary = {
	"damage": [5, "ballistics"], "fire_rate": [5, "ballistics"], "bullet_speed": [4, "ballistics"],
	"pierce": [4, "ballistics"], "gun_lines": [2, "ballistics"], "siege_rounds": [3, "ballistics"],
	"move_speed": [5, "mobility"], "mine": [5, "mobility"], "spike_density": [4, "mobility"],
	"dash_cooldown": [4, "mobility"], "dash_impact": [4, "mobility"], "recovery_route": [4, "mobility"],
	"drone": [4, "automation"], "drone_damage": [5, "automation"], "arc": [5, "automation"],
	"arc_capacitor": [5, "automation"], "pickup": [4, "automation"], "health": [3, "automation"],
	"orbital_storm": [1, "ballistics"], "rift_overdrive": [1, "mobility"], "thunder_matrix": [1, "automation"],
}

var save_path := DEFAULT_PATH

func save_snapshot(snapshot: Dictionary) -> bool:
	if not validate_snapshot(snapshot):
		return false
	var temporary_path := save_path + ".tmp"
	var backup_path := save_path + ".bak"
	_remove_file(temporary_path)
	var file := FileAccess.open(temporary_path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(snapshot))
	file.flush()
	file.close()
	if not validate_snapshot(_read_snapshot(temporary_path)):
		_remove_file(temporary_path)
		return false
	_remove_file(backup_path)
	if FileAccess.file_exists(save_path):
		if not _rename_file(save_path, backup_path):
			_remove_file(temporary_path)
			return false
	if not _rename_file(temporary_path, save_path):
		if FileAccess.file_exists(backup_path):
			_rename_file(backup_path, save_path)
		return false
	_remove_file(backup_path)
	return true

func load_snapshot() -> Dictionary:
	var snapshot := _read_snapshot(save_path)
	return snapshot if validate_snapshot(snapshot) else {}

func has_valid_snapshot() -> bool:
	return not load_snapshot().is_empty()

func clear_snapshot() -> void:
	_remove_file(save_path)
	_remove_file(save_path + ".tmp")
	_remove_file(save_path + ".bak")

func validate_snapshot(snapshot: Dictionary) -> bool:
	if snapshot.is_empty():
		return false
	for key in FORBIDDEN_RUNTIME_KEYS:
		if snapshot.has(key):
			return false
	var required := [
		"version", "boundary", "pending_stage", "coins", "family_levels", "upgrade_counts",
		"evolution", "settlement", "player", "kills", "elapsed_seconds",
	]
	for key in required:
		if not snapshot.has(key):
			return false
	if int(snapshot["version"]) != VERSION or not _is_integer_value(snapshot["version"]):
		return false
	if String(snapshot["boundary"]) not in BOUNDARIES:
		return false
	if not _is_int_in_range(snapshot["pending_stage"], 1, MAX_STAGE):
		return false
	if not _is_int_in_range(snapshot["coins"], 0, 999999999):
		return false
	if not _validate_family_levels(snapshot["family_levels"]):
		return false
	if not _validate_upgrade_counts(snapshot["upgrade_counts"]):
		return false
	if String(snapshot["evolution"]) not in EVOLUTION_IDS:
		return false
	if not _validate_settlement(snapshot["settlement"], int(snapshot["pending_stage"]), String(snapshot["boundary"])):
		return false
	if not _validate_player(snapshot["player"]):
		return false
	if not _is_int_in_range(snapshot["kills"], 0, 999999999):
		return false
	if not _is_number_in_range(snapshot["elapsed_seconds"], 0.0, MAX_ELAPSED_SECONDS):
		return false
	return true

func _validate_family_levels(value: Variant) -> bool:
	if not value is Dictionary:
		return false
	var levels: Dictionary = value
	if levels.size() != FAMILY_IDS.size():
		return false
	for family_id in FAMILY_IDS:
		if not levels.has(family_id) or not _is_int_in_range(levels[family_id], 1, 99):
			return false
	return true

func _validate_upgrade_counts(value: Variant) -> bool:
	if not value is Dictionary:
		return false
	var counts: Dictionary = value
	for card_id_value in counts.keys():
		var card_id := String(card_id_value)
		if not CARD_LIMITS.has(card_id):
			return false
		if not _is_int_in_range(counts[card_id_value], 1, int(CARD_LIMITS[card_id][0])):
			return false
	return true

func _validate_settlement(value: Variant, pending_stage: int, boundary: String) -> bool:
	if not value is Dictionary:
		return false
	var settlement: Dictionary = value
	for key in ["wave", "generation", "offers", "reward_claimed", "closed"]:
		if not settlement.has(key):
			return false
	if not _is_int_in_range(settlement["wave"], 0, MAX_STAGE - 1):
		return false
	if not _is_int_in_range(settlement["generation"], 0, MAX_STAGE):
		return false
	if not settlement["offers"] is Array or (settlement["offers"] as Array).size() > 6:
		return false
	if not settlement["reward_claimed"] is bool or not settlement["closed"] is bool:
		return false
	if boundary == "settlement" and (int(settlement["wave"]) != pending_stage - 1 or bool(settlement["closed"])):
		return false
	if boundary == "settlement" and pending_stage <= 1:
		return false
	for offer_value in settlement["offers"]:
		if not _validate_offer(offer_value, int(settlement["generation"])):
			return false
	return true

func _validate_offer(value: Variant, generation: int) -> bool:
	if not value is Dictionary:
		return false
	var offer: Dictionary = value
	for key in ["id", "family", "cost", "sold", "claimed", "purchased", "transaction"]:
		if not offer.has(key):
			return false
	var card_id := String(offer["id"])
	if not CARD_LIMITS.has(card_id) or String(offer["family"]) != String(CARD_LIMITS[card_id][1]):
		return false
	if not _is_int_in_range(offer["cost"], 1, 999999) or int(offer["transaction"]) != generation:
		return false
	return offer["sold"] is bool and offer["claimed"] is bool and offer["purchased"] is bool

func _validate_player(value: Variant) -> bool:
	if not value is Dictionary:
		return false
	var player_state: Dictionary = value
	for key in ["position", "health", "max_health", "shield", "max_shield"]:
		if not player_state.has(key):
			return false
	if not player_state["position"] is Array or (player_state["position"] as Array).size() != 2:
		return false
	var position: Array = player_state["position"]
	if not _is_number_in_range(position[0], -100000.0, 100000.0) or not _is_number_in_range(position[1], -100000.0, 100000.0):
		return false
	var max_health := float(player_state["max_health"])
	var max_shield := float(player_state["max_shield"])
	return (
		_is_number_in_range(max_health, 1.0, 100000.0)
		and _is_number_in_range(player_state["health"], 0.0, max_health)
		and _is_number_in_range(max_shield, 0.0, 100000.0)
		and _is_number_in_range(player_state["shield"], 0.0, max_shield)
	)

func _read_snapshot(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parser := JSON.new()
	if parser.parse(FileAccess.get_file_as_string(path)) != OK:
		return {}
	var parsed: Variant = parser.data
	return parsed if parsed is Dictionary else {}

func _rename_file(from_path: String, to_path: String) -> bool:
	return DirAccess.rename_absolute(ProjectSettings.globalize_path(from_path), ProjectSettings.globalize_path(to_path)) == OK

func _remove_file(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func _is_integer_value(value: Variant) -> bool:
	return (value is int) or (value is float and is_finite(value) and is_equal_approx(value, roundf(value)))

func _is_int_in_range(value: Variant, minimum: int, maximum: int) -> bool:
	return _is_integer_value(value) and int(value) >= minimum and int(value) <= maximum

func _is_number_in_range(value: Variant, minimum: float, maximum: float) -> bool:
	if not value is int and not value is float:
		return false
	var number := float(value)
	return is_finite(number) and number >= minimum and number <= maximum
