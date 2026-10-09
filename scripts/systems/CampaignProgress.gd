extends RefCounted
class_name CampaignProgress

const Catalog = preload("res://scripts/systems/ChapterCatalog.gd")
const VERSION := 1

var _cleared_chapters: Array[int] = []

func is_unlocked(chapter: int) -> bool:
	return chapter >= 1 and chapter <= get_highest_unlocked_chapter()

func has_cleared(chapter: int) -> bool:
	return chapter >= 1 and chapter <= _cleared_chapters.size()

func get_highest_unlocked_chapter() -> int:
	return mini(_cleared_chapters.size() + 1, Catalog.CHAPTER_COUNT)

func is_campaign_complete() -> bool:
	return _cleared_chapters.size() == Catalog.CHAPTER_COUNT

func record_boss_defeat(chapter: int) -> bool:
	# True means a NEW clear; duplicate signals/replays never advance progress.
	if not is_unlocked(chapter) or chapter != _cleared_chapters.size() + 1:
		return false
	_cleared_chapters.append(chapter)
	return true

func to_state() -> Dictionary:
	return {"version": VERSION, "cleared_chapters": _cleared_chapters.duplicate()}

func restore_state(state: Dictionary) -> bool:
	# Reject wave snapshots and unknown versions rather than silently opening gates.
	if state.size() != 2 or not state.has("version") or not state.has("cleared_chapters"):
		return false
	if not _is_integer_number(state["version"]) or float(state["version"]) != VERSION:
		return false
	if not state["cleared_chapters"] is Array:
		return false
	var cleared: Array = state["cleared_chapters"]
	if cleared.size() > Catalog.CHAPTER_COUNT:
		return false
	var validated: Array[int] = []
	for index in range(cleared.size()):
		if not _is_integer_number(cleared[index]) or float(cleared[index]) != index + 1:
			return false
		validated.append(index + 1)
	# Commit only after complete validation; failed imports preserve live progress.
	_cleared_chapters = validated
	return true

func _is_integer_number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == floorf(float(value))
