extends "res://scripts/campaign/ChapterRun.gd"
func _chapter_number() -> int: return 5
func _bind_region() -> bool:
	return director.bind_echo_field(map.echo_field)
