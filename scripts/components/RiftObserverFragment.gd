extends "res://scripts/components/RiftObserverCircleFlight.gd"
## One finite paper fragment; fixed profile and small opaque footprint only.
const RADIUS := 4.0
const MAX_DISTANCE := 360.0
const FLIGHT_SECONDS := 0.09
const LIFE_SECONDS := FLIGHT_SECONDS
const DAMAGE := 8.0*3.0
func _get_radius() -> float: return RADIUS
func _get_max_distance() -> float: return MAX_DISTANCE
func _get_flight_seconds() -> float: return FLIGHT_SECONDS
func _get_life_seconds() -> float: return LIFE_SECONDS
func _get_damage() -> float: return DAMAGE
func _get_damage_source() -> StringName: return &"rift_observer_refract"
func draw_visual(canvas: Node2D) -> void:
	if not armed: return
	var heading := origin.direction_to(landing); var side := heading.orthogonal()
	# Filled outer/inner triangles preserve a paper body at 1x; all ink stays <=R+1.
	var ink := PackedVector2Array([canvas.to_local(position+heading*5),canvas.to_local(position-heading*3+side*4),canvas.to_local(position-heading*3-side*4)])
	var paper := PackedVector2Array([canvas.to_local(position+heading*RADIUS),canvas.to_local(position-heading*2+side*2.8),canvas.to_local(position-heading*2-side*2.8)])
	canvas.draw_colored_polygon(ink,Color("292435")); canvas.draw_colored_polygon(paper,Color("d0c5b6"))
	canvas.draw_circle(canvas.to_local(position),1.2,Color("ed8877"))
