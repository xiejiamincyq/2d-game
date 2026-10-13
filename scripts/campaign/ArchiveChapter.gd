extends "res://scripts/campaign/ChapterRun.gd"
func _chapter_number() -> int: return 4
func _bind_region() -> bool:
	return director.bind_spore_field(map.spore_field)
