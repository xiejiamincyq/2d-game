extends RefCounted
## Content readiness and permanent progress remain distinct gates.
const Definitions = preload("res://scripts/campaign/ChapterRunDefinitions.gd")
const READY_CHAPTERS: Array[int] = [1, 2, 3, 4, 5, 6]
static func instantiate_chapter(chapter: int) -> Node:
	var definition := Definitions.get_definition(chapter)
	if definition.is_empty(): return null
	# Lazy load prevents a scene/coordinator/registry preload cycle.
	var packed: PackedScene = load(definition.scene_path)
	return packed.instantiate() if packed != null else null
