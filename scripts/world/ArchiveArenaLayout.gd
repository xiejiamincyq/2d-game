extends "res://scripts/world/ArenaLayout.gd"
## Four twin-exit shelf chambers, not recolored reservoirs or pipe lanes.
const Solid = preload("res://scripts/world/ArchiveObstacle.gd")
const PROFILE_ID := &"archive_shelf_chambers"
const PROFILE_VERSION := 1
const BOUNDS := Rect2(-1664,-1024,3328,2048)
const SPAWN_BUFFER := Rect2(-300,-220,600,440)
const BOSS_BUFFER := Rect2(-360,-912,720,480)
const BOSS_CENTER := Vector2(0,-672)
const THICKNESS := 52.0
var chambers: Array[Rect2] = []
var doorways: Array[Rect2] = []
var spore_sites: Array[Vector2] = []
func generate_map(seed_value: int) -> void: super.generate(BOUNDS,seed_value,2)
func get_chambers() -> Array[Rect2]: return chambers.duplicate()
func get_doorways() -> Array[Rect2]: return doorways.duplicate()
func get_spore_sites() -> Array[Vector2]: return spore_sites.duplicate()
func _build_descriptors(seed_value: int) -> Array[Dictionary]:
	var rng := RandomNumberGenerator.new(); rng.seed = seed_value
	chambers.clear(); doorways.clear(); spore_sites.clear()
	var entries: Array[Dictionary] = []
	for side in [-1,1]:
		for row in [-1,1]:
			var center := Vector2(side*1000+rng.randi_range(-32,32),row*568+rng.randi_range(-24,24))
			var size := Vector2(rng.randi_range(640,704),rng.randi_range(480,520))
			var room := Rect2(center-size/2,size); var index := chambers.size()
			chambers.append(room); spore_sites.append(center)
			var transposed := rng.randi_range(0,1)==1
			var frame := Vector2(size.y,size.x) if transposed else size
			var pieces: Array[Rect2] = [Rect2(0,0,frame.x,THICKNESS),Rect2(0,frame.y-THICKNESS,frame.x,THICKNESS)]
			for edge in [0.0,frame.x-THICKNESS]:
				var gap := float(rng.randi_range(224,256))
				var start := frame.y/2+rng.randi_range(-12,12)-gap/2
				pieces.append(Rect2(edge,THICKNESS,THICKNESS,start-THICKNESS))
				pieces.append(Rect2(edge,start+gap,THICKNESS,frame.y-THICKNESS-start-gap))
				doorways.append(_to_room(Rect2(edge,start,THICKNESS,gap),room,transposed))
			for piece in pieces: entries.append({"rect":_to_room(piece,room,transposed),"kind":&"bookcase","chamber":index})
	return entries
func _to_room(local: Rect2,room: Rect2,transposed: bool) -> Rect2:
	return Rect2(room.position+Vector2(local.position.y,local.position.x),Vector2(local.size.y,local.size.x)) if transposed else Rect2(room.position+local.position,local.size)
func _layout_is_acceptable() -> bool:
	if obstacle_descriptors.size()!=24 or chambers.size()!=4 or doorways.size()!=8: return false
	for entry in obstacle_descriptors:
		var rect: Rect2 = entry.rect
		if not world_bounds.grow(-EDGE_MARGIN).encloses(rect) or rect.intersects(SPAWN_BUFFER) or rect.intersects(BOSS_BUFFER): return false
	if not is_reachable(Vector2.ZERO,BOSS_CENTER,56): return false
	for room in chambers:
		if not is_reachable(Vector2.ZERO,room.get_center(),56): return false
	return true
func _spawn_obstacles() -> void:
	for entry in obstacle_descriptors:
		var solid := Solid.new(); solid.setup(entry.rect,entry.kind); add_child(solid)
