extends "res://scripts/campaign/ChapterRun.gd"
func _chapter_number() -> int: return 6
func _bind_region() -> bool:
	return director.bind_rift_field(map.rift_field)
