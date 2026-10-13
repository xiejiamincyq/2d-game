extends "res://scripts/world/ArenaLayout.gd"
## Continuous ground around four connected stepped equipment islands.
const Solid = preload("res://scripts/world/RiftObstacle.gd")
const PROFILE_ID := &"rift_stepped_equipment"
const PROFILE_VERSION := 1
const BOUNDS := Rect2(-1664,-1152,3328,2304)
const SPAWN_BUFFER := Rect2(-300,-220,600,440)
const BOSS_BUFFER := Rect2(-384,-1056,768,576)
const BOSS_CENTER := Vector2(0,-768)
const ROUTE_TARGETS := [BOSS_CENTER,Vector2(-1472,0),Vector2(1472,0),Vector2(0,896),Vector2(-1472,896),Vector2(1472,-896)]
var island_profiles: Array[Dictionary] = []
var bypass_routes: Array[Dictionary] = []
var fault_sites: Array[Vector2] = []
func generate_map(seed_value: int) -> void: super.generate(BOUNDS,seed_value,2)
## Returned collections are snapshots; callers cannot change physical/nav authority.
func get_islands() -> Array[Dictionary]: return island_profiles.duplicate(true)
func get_bypass_routes() -> Array[Dictionary]: return bypass_routes.duplicate(true)
func get_fault_sites() -> Array[Vector2]: return fault_sites.duplicate()
func _build_descriptors(seed_value: int) -> Array[Dictionary]:
	var rng := RandomNumberGenerator.new(); rng.seed = seed_value
	island_profiles.clear(); bypass_routes.clear(); fault_sites.clear()
	var entries: Array[Dictionary] = []
	for island in 4:
		var row := -1 if island<2 else 1
		var column := -1 if island%2==0 else 1
		var center := Vector2(column*912+rng.randi_range(-48,48),row*560+rng.randi_range(-32,32))
		var slope := -1 if rng.randi_range(0,1)==0 else 1
		var base := entries.size()
		for step in 4:
			var at := center+Vector2(-189+step*126,slope*(-84+step*56))
			var extent := Vector2(rng.randi_range(156,164),rng.randi_range(108,116))
			entries.append({"rect":Rect2(at-extent/2,extent),"kind":&"scope_bench" if step in [1,2] else &"relay_plinth","island":island,"step":step})
		# Same-island overlap is intentional: one connected stair, not four pillars.
		var footprint: Rect2 = entries[base].rect
		for step in range(1,4): footprint = footprint.merge(entries[base+step].rect)
		var left := Vector2(footprint.position.x-160,footprint.get_center().y)
		var right := Vector2(footprint.end.x+160,footprint.get_center().y)
		island_profiles.append({"id":island,"rect":footprint,"center":center,"slope":slope,"left":left,"right":right})
		var upper := Rect2(Vector2(left.x,footprint.position.y-280),Vector2(right.x-left.x,224))
		var lower := Rect2(Vector2(left.x,footprint.end.y+56),Vector2(right.x-left.x,224))
		bypass_routes.append({"island":island,"side":&"upper","rect":upper})
		bypass_routes.append({"island":island,"side":&"lower","rect":lower})
		fault_sites.append(Vector2(center.x,lower.get_center().y if row<0 else upper.get_center().y))
	return entries
func _layout_is_acceptable() -> bool:
	if obstacle_descriptors.size()!=16 or island_profiles.size()!=4 or bypass_routes.size()!=8 or fault_sites.size()!=4: return false
	for entry in obstacle_descriptors:
		var rect: Rect2 = entry.rect
		if not world_bounds.grow(-EDGE_MARGIN).encloses(rect) or rect.intersects(SPAWN_BUFFER) or rect.intersects(BOSS_BUFFER): return false
	for route in bypass_routes:
		if not world_bounds.encloses(route.rect): return false
		for entry in obstacle_descriptors:
			if route.rect.intersects(entry.rect): return false
	for island in island_profiles:
		if not is_reachable(island.left,island.right,56): return false
	for target in ROUTE_TARGETS:
		if not is_reachable(Vector2.ZERO,target,56): return false
	for site in fault_sites:
		if not is_position_walkable(site,96) or not is_reachable(Vector2.ZERO,site,56): return false
	return true
func _spawn_obstacles() -> void:
	for entry in obstacle_descriptors:
		var solid := Solid.new(); solid.setup(entry.rect,entry.kind); add_child(solid)
