extends "res://scripts/world/ArenaLayout.gd"
## Chapter-specific geometry; shares queries, never the old obstacle atlas/layout.

const NurseryObstacle = preload("res://scripts/world/NurseryObstacle.gd")
const PROFILE_ID := &"root_beds"
const PROFILE_VERSION := 1
const BOUNDS := Rect2(-1400, -900, 2800, 1800)
const SPAWN_BUFFER := Rect2(-300, -220, 600, 440)
const BOSS_BUFFER := Rect2(-300, -760, 600, 500)
const BOSS_CENTER := Vector2(0, -500)

func generate_map(seed_value: int) -> void:
	# The inherited query contract uses its v2 connected-grid checks. The chapter
	# save/profile version is separate; do not write this into old wave snapshots.
	super.generate(BOUNDS, seed_value, 2)

func _build_descriptors(seed_value: int) -> Array[Dictionary]:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var descriptors: Array[Dictionary] = []
	for center in [Vector2(-1040, -610), Vector2(1040, 610)]:
		var at: Vector2 = center + Vector2(rng.randf_range(-34, 34), rng.randf_range(-28, 28))
		var size := Vector2(rng.randf_range(208, 238), rng.randf_range(128, 158))
		descriptors.append({"rect": Rect2(at - size * 0.5, size), "kind": &"seed_house"})
	var centers: Array = []
	for y in [-570, -210, 210, 570]:
		for x in [-1100, -760, -420, 420, 760, 1100]:
			centers.append(Vector2(x, y))
	_shuffle_with_rng(centers, rng)
	var desired := 16 + posmod(seed_value, 5)
	for center in centers:
		var kind: StringName = &"root_wall" if descriptors.size() % 3 == 0 else &"plant_bed"
		var size := Vector2(rng.randf_range(86, 116), rng.randf_range(164, 194)) if kind == &"root_wall" else Vector2(rng.randf_range(174, 230), rng.randf_range(92, 126))
		var at: Vector2 = center + Vector2(rng.randf_range(-30, 30), rng.randf_range(-26, 26))
		var rect := Rect2(at - size * 0.5, size)
		if not world_bounds.grow(-EDGE_MARGIN).encloses(rect) or rect.intersects(SPAWN_BUFFER) or rect.intersects(BOSS_BUFFER):
			continue
		var overlaps := false
		for existing in descriptors:
			if rect.grow(64).intersects(existing.rect):
				overlaps = true
				break
		if not overlaps:
			descriptors.append({"rect": rect, "kind": kind})
		if descriptors.size() >= desired:
			break
	return descriptors

func _layout_is_acceptable() -> bool:
	if obstacle_descriptors.size() < 13 or not _required_routes_are_connected():
		return false
	# Large actors also have an actual path to the clear Boss pocket.
	for target in [BOSS_CENTER, Vector2(-1120, 0), Vector2(1120, 0), Vector2(0, 680)]:
		if not is_reachable(Vector2.ZERO, target, 56):
			return false
	return true

func _spawn_obstacles() -> void:
	for descriptor in obstacle_descriptors:
		var obstacle := NurseryObstacle.new()
		obstacle.setup(descriptor.rect, descriptor.kind)
		add_child(obstacle)
