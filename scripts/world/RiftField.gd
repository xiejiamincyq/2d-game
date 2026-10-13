extends Node2D
## Map owns four dormant drivers. Encounter grants authority for two or four.
const Fault = preload("res://scripts/world/RiftFault.gd")
var layout: Node2D
var target: Node2D
var linked_health: Node
var active := false
var sites: Array[Vector2] = []
func _ready() -> void: process_mode = Node.PROCESS_MODE_ALWAYS
func configure(terrain: Node2D,seed_value: int,player: Node2D = null) -> void:
	clear(); layout = terrain
	if not is_instance_valid(layout): return
	layout.tree_exiting.connect(_cancel); sites = layout.get_fault_sites()
	var rng := RandomNumberGenerator.new(); rng.seed = seed_value
	for index in range(sites.size()-1,0,-1):
		var other := rng.randi_range(0,index)
		var swap := sites[index]; sites[index] = sites[other]; sites[other] = swap
	for index in sites.size():
		var fault := Fault.new(); add_child(fault)
		fault.configure(layout,null,sites[index],Vector2.LEFT if rng.randi_range(0,1)==0 else Vector2.RIGHT,Fault.COOLDOWN_TIME+index*0.37)
	bind_player(player)
func get_sites() -> Array[Vector2]: return sites.duplicate()
func bind_player(player: Node2D) -> void:
	set_active(false); _unbind_player(); target = player
	for fault in get_children(): fault.bind_player(player)
	if not is_instance_valid(player): return
	player.tree_exiting.connect(_cancel); linked_health = player.get("health")
	if is_instance_valid(linked_health) and linked_health.has_signal("died"): linked_health.connect("died",_cancel)
func _unbind_player() -> void:
	if is_instance_valid(target) and target.tree_exiting.is_connected(_cancel): target.tree_exiting.disconnect(_cancel)
	if is_instance_valid(linked_health) and linked_health.has_signal("died") and linked_health.is_connected("died",_cancel): linked_health.disconnect("died",_cancel)
	target = null; linked_health = null
func _cancel() -> void: set_active(false)
func set_active(value: bool,count: int = 2) -> void:
	var limit := clampi(count,0,4)
	active = value and limit>0 and is_inside_tree() and not is_queued_for_deletion() and is_instance_valid(layout) and layout.is_inside_tree() and not layout.is_queued_for_deletion() and is_instance_valid(target) and target.is_inside_tree() and not target.is_queued_for_deletion()
	if active: active = is_instance_valid(linked_health) and linked_health.current_health>0
	for index in get_child_count(): get_child(index).set_enabled(active and index<limit)
func clear() -> void:
	set_active(false); _unbind_player()
	if is_instance_valid(layout) and layout.tree_exiting.is_connected(_cancel): layout.tree_exiting.disconnect(_cancel)
	layout = null
	for fault in get_children(): fault.free()
	sites.clear()
func _exit_tree() -> void: _cancel()
