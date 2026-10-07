extends RefCounted

const CELL_SIZE := 256.0
const QUERY_RADIUS := 240.0
var cells: Dictionary = {}
var frame_stamp := -1
var population := -1
var dirty := true
var rebuild_count := 0
var last_candidate_count := 0

func invalidate() -> void:
	dirty = true

func refresh(enemies: Array[Node], physics_frame: int) -> void:
	if not dirty and physics_frame == frame_stamp and population == enemies.size():
		return
	cells.clear()
	for enemy in enemies:
		if not _is_live(enemy):
			continue
		var key := _cell(enemy.global_position)
		if not cells.has(key):
			cells[key] = []
		cells[key].append(enemy)
	frame_stamp = physics_frame
	population = enemies.size()
	dirty = false
	rebuild_count += 1

func neighbors(subject: Node2D) -> Array[Node]:
	var result: Array[Node] = []
	last_candidate_count = 0
	# One extra cell conservatively covers peers moving since the frame's first
	# query. Live distance filtering remains exact; ordinary/birth movement is
	# much smaller than 256px per physics frame. Teleports invalidate the index.
	var padding := Vector2.ONE * (QUERY_RADIUS + CELL_SIZE)
	var first := _cell(subject.global_position - padding)
	var last := _cell(subject.global_position + padding)
	for y in range(first.y, last.y + 1):
		for x in range(first.x, last.x + 1):
			for candidate in cells.get(Vector2i(x, y), []):
				last_candidate_count += 1
				if not _is_live(candidate) or candidate == subject:
					continue
				if subject.global_position.distance_squared_to(candidate.global_position) <= QUERY_RADIUS * QUERY_RADIUS:
					result.append(candidate)
	return result

func _cell(position: Vector2) -> Vector2i:
	return Vector2i(floori(position.x / CELL_SIZE), floori(position.y / CELL_SIZE))

func _is_live(candidate: Variant) -> bool:
	return is_instance_valid(candidate) and candidate is Node2D and not candidate.is_queued_for_deletion() and not bool(candidate.get("death_resolved"))
