extends "res://scripts/world/ArenaLayout.gd"
## Split reservoirs leave four changing dry causeways plus two outer loops.
const Solid = preload("res://scripts/world/SaltObstacle.gd")
const PROFILE_ID := &"salt_causeways"
const PROFILE_VERSION := 2
const BOUNDS := Rect2(-1664,-1024,3328,2048)
const SPAWN_BUFFER := Rect2(-300,-220,600,440)
const BOSS_BUFFER := Rect2(-360,-912,720,480)
const BOSS_CENTER := Vector2(0,-672)
var causeways: Array[Rect2] = []
func generate_map(seed_value: int) -> void:
	super.generate(BOUNDS,seed_value,2)
func get_causeways() -> Array[Rect2]:
	return causeways.duplicate()
func _build_descriptors(seed_value: int) -> Array[Dictionary]:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	causeways.clear()
	var entries: Array[Dictionary] = []
	for side in [-1,1]:
		for row in [-1,1]:
			# Integer/half-pixel boundaries share exact endpoints with dry gaps.
			var center := Vector2(side*990+rng.randi_range(-40,40),row*560+rng.randi_range(-32,32))
			var size := Vector2(rng.randi_range(720,800),rng.randi_range(480,520))
			var pool := Rect2(center-size/2,size)
			var axis := rng.randi_range(0,1)
			var gap := float(rng.randi_range(220,280))
			var offset := float(rng.randi_range(-38,38))
			var start: float = center[axis]+offset-gap/2
			var finish: float = start+gap
			var first := pool
			first.size[axis] = start-pool.position[axis]
			var last := pool
			last.position[axis] = finish
			last.size[axis] = pool.end[axis]-finish
			entries.append({"rect":first,"kind":&"reservoir"})
			entries.append({"rect":last,"kind":&"reservoir"})
			var passage := pool
			passage.position[axis] = start
			passage.size[axis] = gap
			causeways.append(passage)
	for side in [-1,1]:
		var size := Vector2(72,112)
		var center := Vector2(side*430+rng.randi_range(-12,12),rng.randi_range(-36,36))
		entries.append({"rect":Rect2(center-size/2,size),"kind":&"sluice_wall"})
	# Narrow raised sluices flank the central dry cross without shrinking any
	# existing reservoir gap or placing solids in the spawn/Boss pockets.
	for side in [-1,1]:
		for y in [-850,-300,300,850]:
			var size:=Vector2(96,rng.randi_range(148,168))
			var center:=Vector2(side*416+rng.randi_range(-3,3),y+rng.randi_range(-6,6))
			entries.append({"rect":Rect2(center-size/2,size),"kind":&"sluice_wall"})
		for x in [800,1200]:
			var size:=Vector2(96,rng.randi_range(148,168))
			var center:=Vector2(side*x+rng.randi_range(-6,6),rng.randi_range(-6,6))
			entries.append({"rect":Rect2(center-size/2,size),"kind":&"sluice_wall"})
	return entries
func _layout_is_acceptable() -> bool:
	if obstacle_descriptors.size()!=22 or causeways.size()!=4: return false
	for i in obstacle_descriptors.size():
		var rect: Rect2 = obstacle_descriptors[i].rect
		if not world_bounds.grow(-EDGE_MARGIN).encloses(rect) or rect.intersects(SPAWN_BUFFER) or rect.intersects(BOSS_BUFFER): return false
		for other in obstacle_descriptors.slice(i+1):
			if rect.grow(64).intersects(other.rect): return false
	for target in [BOSS_CENTER,Vector2(-1472,0),Vector2(1472,0),Vector2(0,832),Vector2(-1504,896),Vector2(1504,-896)]:
		if not is_reachable(Vector2.ZERO,target,56): return false
	for passage in causeways:
		if not is_reachable(Vector2.ZERO,passage.get_center(),56): return false
		var axis:=Vector2.DOWN if passage.size.x<passage.size.y else Vector2.RIGHT
		var extent: float=maxf(passage.size.x,passage.size.y)/2+88
		var start:=passage.get_center()-axis*extent; var end:=passage.get_center()+axis*extent
		if not is_reachable(start,end,56): return false
		# Keep a wide outer loop even if a dry crossing is temporarily occupied.
		obstacle_descriptors.append({"rect":passage,"kind":&"probe_closed"})
		var bypass:=is_reachable(start,end,56)
		obstacle_descriptors.pop_back()
		if not bypass: return false
	return true
func _spawn_obstacles() -> void:
	for entry in obstacle_descriptors:
		var solid := Solid.new()
		solid.setup(entry.rect,entry.kind)
		add_child(solid)
