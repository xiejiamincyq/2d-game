extends "res://scripts/campaign/ChapterRun.gd"
func _chapter_number() -> int: return 2
func _bind_region() -> bool:
	return director.bind_heat_field(map.heat_field)
