extends RefCounted
## Load-before-save journal with optimistic concurrency and no silent recovery.
const Journey = preload("res://scripts/systems/CampaignJourney.gd")
const DEFAULT_PATH := "user://five_minute_overdrive_journey_v1.json"
const MAX_BYTES := 4096
enum LoadResult { MISSING, LOADED, RECOVERED, CORRUPT, IO_ERROR, UNSUPPORTED_VERSION }
var save_path: String
var _loaded := false
var _baseline: Dictionary = {}
var _owned_temporary_sha := ""

func _init(path := DEFAULT_PATH) -> void:
	save_path = path

func load_journey(journey: Journey) -> LoadResult:
	_loaded = false
	if journey == null:
		return LoadResult.IO_ERROR
	var primary := _read(save_path)
	if primary.status == LoadResult.LOADED:
		journey.restore_state(primary.state)
		_baseline = primary.state.duplicate(true)
		_loaded = true
		return LoadResult.LOADED
	if primary.status not in [LoadResult.MISSING, LoadResult.CORRUPT]:
		return primary.status
	var backup := _read(save_path + ".bak")
	if backup.status == LoadResult.LOADED:
		journey.restore_state(backup.state)
		_baseline = {}
		_loaded = primary.status == LoadResult.MISSING
		return LoadResult.RECOVERED
	if primary.status == LoadResult.MISSING and backup.status == LoadResult.MISSING:
		_baseline = {}
		_loaded = true
	return primary.status if backup.status == LoadResult.MISSING else backup.status

func save_journey(journey: Journey) -> bool:
	if journey == null or not _loaded:
		return false
	var state := journey.to_state()
	var validated := Journey.new()
	if not validated.restore_state(state):
		return false
	var primary := _read(save_path)
	var backup := _read(save_path + ".bak")
	for file_state in [primary, backup]:
		if file_state.status not in [LoadResult.MISSING, LoadResult.LOADED]:
			return false
		if file_state.status == LoadResult.LOADED and int(file_state.state.cleared_stage) > int(state.cleared_stage):
			return false
	if primary.get("state", {}) != _baseline:
		return false
	if primary.get("state", {}) == state:
		return true
	var temporary := save_path + ".tmp"
	if DirAccess.dir_exists_absolute(temporary):
		return false
	if FileAccess.file_exists(temporary) and (_owned_temporary_sha.is_empty() or FileAccess.get_sha256(temporary) != _owned_temporary_sha):
		return false
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(state))
	file.flush()
	var wrote_ok := file.get_error() == OK
	file.close()
	# Retain ownership only for exactly the bytes this instance prepared. Retry
	# may rewrite its own interrupted candidate, never an unknown/replaced temp.
	_owned_temporary_sha = FileAccess.get_sha256(temporary)
	var prepared := _read(temporary)
	if not wrote_ok or prepared.status != LoadResult.LOADED or prepared.state != state:
		return false
	if primary.status == LoadResult.LOADED:
		if backup.status == LoadResult.LOADED and DirAccess.remove_absolute(save_path + ".bak") != OK:
			return false
		if DirAccess.rename_absolute(save_path, save_path + ".bak") != OK:
			return false
	if DirAccess.rename_absolute(temporary, save_path) != OK:
		if primary.status == LoadResult.LOADED:
			DirAccess.rename_absolute(save_path + ".bak", save_path)
		return false
	_baseline = state.duplicate(true)
	_owned_temporary_sha = ""
	return true

func _read(path: String) -> Dictionary:
	if path.is_empty() or DirAccess.dir_exists_absolute(path):
		return {"status": LoadResult.IO_ERROR}
	if not FileAccess.file_exists(path):
		return {"status": LoadResult.MISSING}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"status": LoadResult.IO_ERROR}
	if file.get_length() > MAX_BYTES:
		return {"status": LoadResult.CORRUPT}
	var content := file.get_as_text()
	if file.get_error() != OK:
		return {"status": LoadResult.IO_ERROR}
	var json := JSON.new()
	if json.parse(content) != OK or not json.data is Dictionary:
		return {"status": LoadResult.CORRUPT}
	var state: Dictionary = json.data
	if state.has("version") and (state.version is int or state.version is float) and state.version != Journey.VERSION:
		return {"status": LoadResult.UNSUPPORTED_VERSION}
	var validated := Journey.new()
	if not validated.restore_state(state):
		return {"status": LoadResult.CORRUPT}
	return {"status": LoadResult.LOADED, "state": validated.to_state()}
