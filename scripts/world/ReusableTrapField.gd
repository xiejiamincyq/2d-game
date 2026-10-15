extends Node2D
## Encounter-owned placement/lifecycle, not a six-map runtime migration by itself.
const Trap = preload("res://scripts/world/ReusableStepTrap.gd")
const Player = preload("res://scripts/actors/Player.gd")
const CLEARANCE := 66.0
const SPACING := 170.0
const MAX_TRAPS := 16
var layout: ArenaLayout
var target: Node2D
var linked_health: Node
var sites: Array[Vector2] = []
var active := false
var _configuring := false

func _ready() -> void: process_mode = Node.PROCESS_MODE_ALWAYS

func configure(terrain: ArenaLayout, seed_value: int, player: Node2D = null, count: int = 10) -> bool:
	# Child entry publishes synchronous signals. Nested configuration cancels
	# the in-flight operation rather than authorizing a second partial field.
	if _configuring:
		clear()
		return false
	_configuring = true
	var configured := _configure(terrain,seed_value,player,count)
	_configuring = false
	return configured

func _configure(terrain: ArenaLayout, seed_value: int, player: Node2D, count: int) -> bool:
	clear()
	if not is_inside_tree() or not is_instance_valid(terrain) or not terrain.is_inside_tree() or terrain.is_queued_for_deletion(): return false
	var buffers: Dictionary = terrain.get_script().get_script_constant_map()
	if not buffers.has_all(["SPAWN_BUFFER","BOSS_BUFFER"]): return false
	var limit := clampi(count,0,MAX_TRAPS)
	var chosen := _pick_sites(terrain,seed_value,limit,buffers.SPAWN_BUFFER,buffers.BOSS_BUFFER)
	if chosen.size()!=limit: return false # No partially armed fallback layout.
	layout = terrain; sites = chosen
	layout.tree_exiting.connect(clear)
	for at in chosen:
		var trap := Trap.new()
		trap.position = to_local(layout.to_global(at))
		add_child(trap)
		if layout!=terrain or not is_instance_valid(terrain) or not terrain.is_inside_tree() or terrain.is_queued_for_deletion() or not is_inside_tree() or is_queued_for_deletion() or trap.is_queued_for_deletion() or trap.get_parent()!=self:
			clear()
			return false
	bind_player(player)
	return true

func _pick_sites(terrain: ArenaLayout, seed_value: int, count: int, spawn: Rect2, boss: Rect2) -> Array[Vector2]:
	var rng := RandomNumberGenerator.new(); rng.seed = seed_value
	var candidates: Array[Vector2] = []
	var chosen: Array[Vector2] = []
	var bounds := terrain.world_bounds
	for x in range(int(bounds.position.x)+120,int(bounds.end.x)-120,160):
		for y in range(int(bounds.position.y)+120,int(bounds.end.y)-120,160):
			var at := Vector2(x,y)+Vector2(rng.randf_range(-24,24),rng.randf_range(-24,24))
			if spawn.grow(CLEARANCE).has_point(at) or boss.grow(CLEARANCE).has_point(at): continue
			if terrain.is_position_walkable(at,CLEARANCE): candidates.append(at)
	for i in range(candidates.size()-1,0,-1):
		var j := rng.randi_range(0,i); var swap := candidates[i]
		candidates[i] = candidates[j]; candidates[j] = swap
	for at in candidates:
		if chosen.size()>=count: break
		if chosen.any(func(other: Vector2): return other.distance_to(at)<SPACING): continue
		if terrain.is_reachable(Vector2.ZERO,at,Player.BODY_RADIUS): chosen.append(at)
	return chosen

func get_sites() -> Array[Vector2]: return sites.duplicate()

func get_destructible_targets() -> Array[Node]:
	var targets: Array[Node] = []
	if not is_inside_tree(): return targets
	for trap in get_children():
		if trap is Trap and not trap.is_queued_for_deletion() and trap.is_in_group(&"destructible_terrain") and trap.health.current_health>0:
			targets.append(trap)
	return targets

func bind_player(player: Node2D) -> void:
	_cancel(); _unbind_player(); target = player
	for trap in get_children(): trap.target_player = player
	if not is_instance_valid(player): return
	player.tree_exiting.connect(_cancel)
	linked_health = player.get("health")
	if is_instance_valid(linked_health): linked_health.died.connect(_cancel)

func _unbind_player() -> void:
	if is_instance_valid(target) and target.tree_exiting.is_connected(_cancel): target.tree_exiting.disconnect(_cancel)
	if is_instance_valid(linked_health) and linked_health.died.is_connected(_cancel): linked_health.died.disconnect(_cancel)
	target = null; linked_health = null

func _can_arm() -> bool:
	return is_inside_tree() and not is_queued_for_deletion() and is_instance_valid(layout) and layout.is_inside_tree() and not layout.is_queued_for_deletion() and is_instance_valid(target) and target.is_inside_tree() and not target.is_queued_for_deletion() and is_instance_valid(linked_health) and linked_health.current_health>0

func set_active(value: bool, count: int = MAX_TRAPS) -> void:
	var limit := clampi(count,0,MAX_TRAPS)
	active = value and limit>0 and _can_arm() and not get_destructible_targets().is_empty()
	var index := 0
	for trap in get_children():
		if trap.is_queued_for_deletion(): continue
		trap.set_active(active and index<limit)
		index += 1

func _cancel() -> void: set_active(false)
func _physics_process(_delta: float) -> void:
	if active and not _can_arm(): _cancel()

func clear() -> void:
	_cancel(); _unbind_player()
	if is_instance_valid(layout) and layout.tree_exiting.is_connected(clear): layout.tree_exiting.disconnect(clear)
	layout = null; sites.clear()
	for trap in get_children():
		trap.target_player = null
		remove_child(trap); trap.queue_free()

func _exit_tree() -> void:
	_cancel(); _unbind_player()
	if is_instance_valid(layout) and layout.tree_exiting.is_connected(clear): layout.tree_exiting.disconnect(clear)
	layout = null
	for trap in get_children(): trap.target_player = null
