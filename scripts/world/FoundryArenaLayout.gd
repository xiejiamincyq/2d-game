extends "res://scripts/world/ArenaLayout.gd"
## Broken pipe bands/workstations, not the nursery placement algorithm.
const Solid = preload("res://scripts/world/FoundryObstacle.gd")
const PROFILE_ID := &"furnace_lanes"
const PROFILE_VERSION := 2
const BOUNDS := Rect2(-1600,-1000,3200,2000)
const SPAWN_BUFFER := Rect2(-300,-220,600,440)
const BOSS_BUFFER := Rect2(-340,-920,680,480)
const BOSS_CENTER := Vector2(0,-660)
const ROUTE_TARGETS := [BOSS_CENTER,Vector2(-1360,0),Vector2(1360,0),Vector2(0,800),Vector2(-760,700),Vector2(760,-700)]
func generate_map(seed_value: int) -> void:
	super.generate(BOUNDS,seed_value,2)
func _build_descriptors(seed_value: int) -> Array[Dictionary]:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var entries: Array[Dictionary] = []
	for side in [-1,1]:
		for row in [-1,1]:
			var gap := rng.randf_range(240,340)
			var split := rng.randf_range(740,1020)
			var y: float = row*390+rng.randf_range(-70,70)
			var height := rng.randf_range(70,88)
			var end := rng.randf_range(1350,1410)
			# Two separate solid segments, with a real randomly placed gap.
			for span in [Vector2(400,split-gap/2),Vector2(split+gap/2,end)]:
				var x: float = side*(span.x+span.y)/2
				entries.append({"rect":Rect2(Vector2(x-(span.y-span.x)/2,y-height/2),Vector2(span.y-span.x,height)),"kind":&"pipe_bank"})
	for side in [-1,1]:
		for row in [-1,1]:
			var size := Vector2(rng.randf_range(172,202),rng.randf_range(142,174))
			var center := Vector2(side*1260+rng.randf_range(-60,60),row*760+rng.randf_range(-60,60))
			entries.append({"rect":Rect2(center-size/2,size),"kind":&"furnace"})
	var candidates: Array[Vector2] = []
	for side in [-1,1]:
		candidates.append_array([Vector2(side*560,-100),Vector2(side*1060,100),Vector2(side*560,740),Vector2(side*560,-740),Vector2(side*1420,0)])
	_shuffle_with_rng(candidates,rng)
	var desired := 16+posmod(seed_value,5)
	for center in candidates:
		var size := Vector2(rng.randf_range(132,164),rng.randf_range(102,126))
		var point: Vector2 = center+Vector2(rng.randf_range(-24,24),rng.randf_range(-22,22))
		var rect := Rect2(point-size/2,size)
		var clear := world_bounds.grow(-EDGE_MARGIN).encloses(rect) and not rect.intersects(SPAWN_BUFFER) and not rect.intersects(BOSS_BUFFER)
		# Validate the same grid endpoints used by navigation, not only raw points.
		# Edge slag could block every retry (seed 30), leaving no solid terrain.
		for target in ROUTE_TARGETS:
			if rect.grow(56).has_point(_cell_to_world(_world_to_cell(target))): clear = false; break
		for entry in entries:
			if rect.grow(64).intersects(entry.rect): clear = false; break
		if clear: entries.append({"rect":rect,"kind":&"slag_stack"})
		if entries.size()>=desired: break
	return entries
func _layout_is_acceptable() -> bool:
	if obstacle_descriptors.size()<16: return false
	for i in obstacle_descriptors.size():
		var rect: Rect2 = obstacle_descriptors[i].rect
		if not world_bounds.grow(-EDGE_MARGIN).encloses(rect) or rect.intersects(SPAWN_BUFFER) or rect.intersects(BOSS_BUFFER): return false
		for other in obstacle_descriptors.slice(i+1):
			if rect.grow(64).intersects(other.rect): return false
	for radius in [26.0,56.0]:
		for target in ROUTE_TARGETS:
			if not is_reachable(Vector2.ZERO,target,radius): return false
	return true
func _spawn_obstacles() -> void:
	for entry in obstacle_descriptors:
		var solid := Solid.new()
		solid.setup(entry.rect,entry.kind)
		add_child(solid)
