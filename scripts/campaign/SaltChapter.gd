extends "res://scripts/campaign/ChapterRun.gd"
func _chapter_number() -> int: return 3
func _bind_region() -> bool:
	return director.bind_tidal_field(map.tidal_field)
