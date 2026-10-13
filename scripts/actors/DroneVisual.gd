extends Node2D
## Pure visual companion. Player alone owns orbit, aim, laser and gameplay time.
const Body = preload("res://scenes/actors/native/ranger_drone_paper_v1.tscn")
var native_visual: Node2D
var visual_seconds := 0.0
func _ready() -> void:
	native_visual = Body.instantiate()
	add_child(native_visual)
	native_visual.sample_clip("entrance",0)
func get_visual_node() -> Node2D:
	return native_visual
func advance_visual(delta: float,firing: bool) -> void:
	if not is_finite(delta) or delta<0 or not is_instance_valid(native_visual): return
	visual_seconds += delta
	if visual_seconds<0.32:
		native_visual.sample_clip("entrance",visual_seconds)
	else:
		native_visual.sample_clip("shoot" if firing else "walk",visual_seconds-0.32)
