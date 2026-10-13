extends Node2D
## Map owns four pads; encounter owns activation, never map generation or animation.
const Beat = preload("res://scripts/world/EchoBeat.gd")
var layout: Node2D
var target: Node2D
var linked_health: Node
var active := false
var sites: Array[Vector2] = []
func _ready() -> void: process_mode = Node.PROCESS_MODE_ALWAYS
func configure(terrain: Node2D,seed_value: int,player: Node2D = null) -> void:
	clear(); layout = terrain
	if not is_instance_valid(layout): return
	layout.tree_exiting.connect(_cancel); sites = layout.get_echo_sites()
	var rng := RandomNumberGenerator.new(); rng.seed = seed_value
	for i in range(sites.size()-1,0,-1):
		var j := rng.randi_range(0,i); var swap := sites[i]; sites[i] = sites[j]; sites[j] = swap
	var center: Vector2 = layout.get_ring_profiles()[0].center
	for i in sites.size():
		var beat := Beat.new(); add_child(beat)
		beat.configure(layout,null,sites[i],(sites[i]-center).orthogonal(),Beat.COOLDOWN_TIME+i*0.37)
	bind_player(player)
func get_sites() -> Array[Vector2]: return sites.duplicate()
func bind_player(player: Node2D) -> void:
	set_active(false); _unbind_player(); target = player
	for beat in get_children(): beat.bind_player(player)
	if not is_instance_valid(player): return
	player.tree_exiting.connect(_cancel); linked_health = player.get("health")
	if is_instance_valid(linked_health) and linked_health.has_signal("died"): linked_health.connect("died",_cancel)
func _unbind_player() -> void:
	if is_instance_valid(target) and target.tree_exiting.is_connected(_cancel): target.tree_exiting.disconnect(_cancel)
	if is_instance_valid(linked_health) and linked_health.has_signal("died") and linked_health.is_connected("died",_cancel): linked_health.disconnect("died",_cancel)
	target = null; linked_health = null
func _cancel() -> void: set_active(false)
func set_active(value: bool,count: int = 2) -> void:
	active = value and is_inside_tree() and not is_queued_for_deletion() and is_instance_valid(layout) and layout.is_inside_tree() and not layout.is_queued_for_deletion() and is_instance_valid(target) and target.is_inside_tree() and not target.is_queued_for_deletion()
	if active: active = is_instance_valid(linked_health) and linked_health.current_health>0
	for i in get_child_count(): get_child(i).set_enabled(active and i<clampi(count,0,4))
func clear() -> void:
	set_active(false); _unbind_player()
	if is_instance_valid(layout) and layout.tree_exiting.is_connected(_cancel): layout.tree_exiting.disconnect(_cancel)
	layout = null
	for beat in get_children(): beat.free()
	sites.clear()
func _exit_tree() -> void: _cancel()
