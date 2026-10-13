extends Node2D
## Encounter-owned switch; generation never enables hazards by itself.
const Vent = preload("res://scripts/world/FoundryHeatVent.gd")
var layout: Node2D
var target: Node2D
var linked_health: Node
var active := false
var sites: Array[Vector2] = []
func _ready() -> void: process_mode = Node.PROCESS_MODE_ALWAYS
func configure(terrain: Node2D,seed_value: int,player: Node2D = null,count: int = 6) -> void:
	clear(); layout = terrain
	var candidates: Array[Vector2] = []
	for x in [-1180.0,-900.0,-660.0,-420.0,420.0,660.0,900.0,1180.0]:
		for y in [-820.0,-620.0,-200.0,180.0,620.0,820.0]:
			var at := Vector2(x,y)
			# 46px heat + two normal Player radii + margin: a whole body can exit.
			if terrain.is_position_walkable(at,83) and not terrain.SPAWN_BUFFER.grow(83).has_point(at) and not terrain.BOSS_BUFFER.grow(83).has_point(at):
				candidates.append(at)
	var rng := RandomNumberGenerator.new(); rng.seed = seed_value
	for i in range(candidates.size()-1,0,-1):
		var j := rng.randi_range(0,i)
		var temp := candidates[i]; candidates[i] = candidates[j]; candidates[j] = temp
	for at in candidates:
		if sites.size()>=clampi(count,6,16): break
		if sites.any(func(other: Vector2): return other.distance_to(at)<170): continue
		if not terrain.is_reachable(Vector2.ZERO,at,13): continue
		sites.append(at)
		var vent := Vent.new(); add_child(vent)
		vent.configure(terrain,null,to_local(terrain.to_global(at)),1.5+(sites.size()-1)*0.18)
	bind_player(player)
func get_sites() -> Array[Vector2]: return sites.duplicate()
func bind_player(player: Node2D) -> void:
	set_active(false); _unbind_player(); target = player
	for vent in get_children(): vent.bind_player(player)
	if not is_instance_valid(player): return
	player.tree_exiting.connect(_cancel)
	linked_health = player.get("health")
	if is_instance_valid(linked_health) and linked_health.has_signal("died"): linked_health.connect("died",_cancel)
func _unbind_player() -> void:
	if is_instance_valid(target) and target.tree_exiting.is_connected(_cancel): target.tree_exiting.disconnect(_cancel)
	if is_instance_valid(linked_health) and linked_health.has_signal("died") and linked_health.is_connected("died",_cancel): linked_health.disconnect("died",_cancel)
	target = null; linked_health = null
func _cancel() -> void: set_active(false)
func set_active(value: bool,count: int = 10) -> void:
	active = value and is_instance_valid(target) and target.is_inside_tree() and not target.is_queued_for_deletion()
	if active:
		var health = target.get("health")
		active = is_instance_valid(health) and health.current_health>0
	for index in get_child_count(): get_child(index).set_enabled(active and index<clampi(count,0,16))
func _physics_process(_delta: float) -> void:
	if not active: return
	if not is_instance_valid(target) or target.is_queued_for_deletion(): set_active(false); return
	var health = target.get("health")
	if is_instance_valid(health) and health.current_health<=0: set_active(false)
func clear() -> void:
	active = false
	_unbind_player()
	for vent in get_children():
		vent.set_enabled(false); vent.free()
	sites.clear()
func _exit_tree() -> void: set_active(false)
