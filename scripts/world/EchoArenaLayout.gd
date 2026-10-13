extends "res://scripts/world/ArenaLayout.gd"
## Two interrupted elliptical pillar rings with opposite, wide radial gateways.
const Solid = preload("res://scripts/world/EchoObstacle.gd")
const PROFILE_ID := &"echo_concentric_columns"
const PROFILE_VERSION := 1
const BOUNDS := Rect2(-1664,-1280,3328,2560)
const SPAWN_BUFFER := Rect2(-300,-220,600,440)
const BOSS_BUFFER := Rect2(-360,-912,720,480)
const BOSS_CENTER := Vector2(0,-672)
const ROUTE_TARGETS := [BOSS_CENTER,Vector2(-1504,0),Vector2(1504,0),Vector2(0,864),Vector2(-1504,864),Vector2(1504,-864)]
const GATE_PROBE_DISTANCE := 352.0 # Outside a closed rectangle + 56px body + grid rounding, including diagonal gates.
var ring_profiles: Array[Dictionary] = []
var gateways: Array[Dictionary] = []
var echo_sites: Array[Vector2] = []
func generate_map(seed_value: int) -> void: super.generate(BOUNDS,seed_value,2)
func get_ring_profiles() -> Array[Dictionary]: return ring_profiles.duplicate(true)
func get_gateways() -> Array[Dictionary]: return gateways.duplicate(true)
func get_echo_sites() -> Array[Vector2]: return echo_sites.duplicate()
func _ellipse(radii: Vector2,angle: float) -> Vector2: return Vector2(cos(angle)*radii.x,sin(angle)*radii.y)
func _build_descriptors(seed_value: int) -> Array[Dictionary]:
	var rng := RandomNumberGenerator.new(); rng.seed = seed_value
	ring_profiles.clear(); gateways.clear(); echo_sites.clear()
	var center := Vector2(rng.randi_range(-16,16),64+rng.randi_range(-16,16))
	var gate_angle := rng.randf_range(0,TAU)
	var radii: Array[Vector2] = [Vector2(rng.randi_range(640,672),rng.randi_range(464,496)),Vector2(rng.randi_range(1136,1168),rng.randi_range(736,752))]
	for i in 4: echo_sites.append(center+_ellipse((radii[0]+radii[1])/2,PI/4+i*PI/2))
	for ring in 2:
		ring_profiles.append({"center":center,"radii":radii[ring],"stations":20 if ring==0 else 24})
		for opposite in 2:
			var angle: float = gate_angle+opposite*PI
			var at := center+_ellipse(radii[ring],angle)
			var radial := (at-center).normalized()
			var extent := Vector2.ONE*rng.randi_range(256,272)
			gateways.append({"rect":Rect2(at-extent/2,extent),"ring":ring,"inside":at-radial*GATE_PROBE_DISTANCE,"outside":at+radial*GATE_PROBE_DISTANCE})
	var entries: Array[Dictionary] = []
	for ring in 2:
		var profile := ring_profiles[ring]
		for station in profile.stations:
			var kind: StringName = &"bell_column" if station%4==0 else &"gravestone"
			var size := Vector2(rng.randi_range(96,104),rng.randi_range(72,84)) if kind==&"bell_column" else Vector2(rng.randi_range(84,92),rng.randi_range(64,80))
			var at := center+_ellipse(radii[ring],gate_angle+station*TAU/profile.stations)
			var rect := Rect2(at-size/2,size)
			if rect.intersects(SPAWN_BUFFER.grow(16)) or rect.intersects(BOSS_BUFFER.grow(16)): continue
			var reserved := false
			for gate in gateways: reserved = reserved or rect.intersects(gate.rect)
			for site in echo_sites: reserved = reserved or rect.intersects(Rect2(site-Vector2.ONE*96,Vector2.ONE*192))
			for target in ROUTE_TARGETS: reserved = reserved or rect.intersects(Rect2(target-Vector2.ONE*112,Vector2.ONE*224))
			for other in entries: reserved = reserved or rect.grow(OBSTACLE_GAP).intersects(other.rect)
			if not reserved: entries.append({"rect":rect,"kind":kind,"ring":ring})
	return entries
func _layout_is_acceptable() -> bool:
	if obstacle_descriptors.size()<20 or gateways.size()!=4 or ring_profiles.size()!=2 or echo_sites.size()!=4: return false
	for entry in obstacle_descriptors:
		if not world_bounds.grow(-EDGE_MARGIN).encloses(entry.rect): return false
	for ring in 2:
		if obstacle_descriptors.filter(func(e): return e.ring==ring).size()<8: return false
	for target in ROUTE_TARGETS:
		if not is_reachable(Vector2.ZERO,target,56): return false
	for site in echo_sites:
		if not is_position_walkable(site,96) or not is_reachable(Vector2.ZERO,site,56): return false
	for gate in gateways:
		if not is_reachable(gate.inside,gate.outside,56): return false
	return true
func _spawn_obstacles() -> void:
	for entry in obstacle_descriptors:
		var solid := Solid.new(); solid.setup(entry.rect,entry.kind); add_child(solid)
