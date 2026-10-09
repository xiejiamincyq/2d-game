extends RefCounted
class_name CampaignProgressStore

const Progress = preload("res://scripts/systems/CampaignProgress.gd")
const DEFAULT_PATH := "user://five_minute_overdrive_campaign_v1.json"
const MAX_BYTES := 4096
enum LoadResult { MISSING, LOADED, RECOVERED, CORRUPT, IO_ERROR, UNSUPPORTED_VERSION }

var save_path: String

func _init(path: String = DEFAULT_PATH) -> void:
	save_path = path

func load_progress(progress: CampaignProgress) -> LoadResult:
	if progress == null:
		return LoadResult.IO_ERROR
	var primary := _read_path(save_path)
	if primary.status == LoadResult.LOADED:
		progress.restore_state(primary.state)
		return LoadResult.LOADED
	if primary.status not in [LoadResult.MISSING, LoadResult.CORRUPT]:
		return primary.status
	var backup := _read_path(save_path + ".bak")
	if backup.status == LoadResult.LOADED:
		progress.restore_state(backup.state)
		return LoadResult.RECOVERED
	# Loading is read-only; never promote .tmp, erase corruption, or downgrade
	# unknown versions. Callers must surface RECOVERED/errors instead of hiding them.
	return primary.status if backup.status == LoadResult.MISSING else backup.status

func save_progress(progress: CampaignProgress) -> bool:
	if progress == null:
		return false
	var candidate := Progress.new()
	if not candidate.restore_state(progress.to_state()):
		return false
	var state := candidate.to_state()
	var primary := _read_path(save_path)
	var backup := _read_path(save_path + ".bak")
	# Preserve corrupt/future data for explicit recovery rather than overwriting it.
	for existing in [primary, backup]:
		if existing.status not in [LoadResult.MISSING, LoadResult.LOADED]:
			return false
		if existing.status == LoadResult.LOADED and existing.state.cleared_chapters.size() > state.cleared_chapters.size():
			return false
	if primary.status == LoadResult.LOADED and primary.state == state:
		return true
	var temporary_path := save_path + ".tmp"
	if DirAccess.dir_exists_absolute(temporary_path):
		return false
	var file := FileAccess.open(temporary_path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(state))
	file.flush()
	var wrote_ok := file.get_error() == OK
	file.close()
	var prepared := _read_path(temporary_path)
	if not wrote_ok or prepared.status != LoadResult.LOADED or prepared.state != state:
		return false
	var backup_path := save_path + ".bak"
	var moved_primary := false
	if primary.status == LoadResult.LOADED:
		if backup.status == LoadResult.LOADED and DirAccess.remove_absolute(backup_path) != OK:
			return false
		if not _rename_file(save_path, backup_path):
			return false
		moved_primary = true
	if not _rename_file(temporary_path, save_path):
		if moved_primary:
			_rename_file(backup_path, save_path)
		return false
	# Retain the previous committed file for recovery. Single-writer store;
	# load/save do not clear old wave snapshots or contain a reset operation.
	return true

func _read_path(path: String) -> Dictionary:
	if path.is_empty() or DirAccess.dir_exists_absolute(path):
		return {"status": LoadResult.IO_ERROR}
	if not FileAccess.file_exists(path):
		return {"status": LoadResult.MISSING}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"status": LoadResult.IO_ERROR}
	if file.get_length() > MAX_BYTES:
		file.close()
		return {"status": LoadResult.CORRUPT}
	var text := file.get_as_text()
	var read_ok := file.get_error() == OK
	file.close()
	if not read_ok:
		return {"status": LoadResult.IO_ERROR}
	var json := JSON.new()
	if json.parse(text) != OK or not json.data is Dictionary:
		return {"status": LoadResult.CORRUPT}
	var state: Dictionary = json.data
	if state.has("version") and (state.version is int or state.version is float) and state.version != Progress.VERSION:
		return {"status": LoadResult.UNSUPPORTED_VERSION}
	var validated := Progress.new()
	if not validated.restore_state(state):
		return {"status": LoadResult.CORRUPT}
	return {"status": LoadResult.LOADED, "state": validated.to_state()}

func _rename_file(source: String, target: String) -> bool:
	return DirAccess.rename_absolute(source, target) == OK
