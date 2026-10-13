extends "res://scripts/components/RiftObserverCircleFlight.gd"
## One outward sensor and fixed landing; visual and fixed profile only.
const RADIUS := 6.0
const MAX_DISTANCE := 360.0
const FLIGHT_SECONDS := 0.12
const HOLD_SECONDS := 0.08
const LIFE_SECONDS := FLIGHT_SECONDS+HOLD_SECONDS
const DAMAGE := 9.0*3.0
func _get_radius() -> float: return RADIUS
func _get_max_distance() -> float: return MAX_DISTANCE
func _get_flight_seconds() -> float: return FLIGHT_SECONDS
func _get_life_seconds() -> float: return LIFE_SECONDS
func _get_damage() -> float: return DAMAGE
func _get_damage_source() -> StringName: return &"rift_observer_probe"
func draw_visual(canvas: Node2D) -> void:
	if not armed: return
	var at := canvas.to_local(position)
	var heading := origin.direction_to(landing)
	var tail := canvas.to_local(position-heading*minf(12,origin.distance_to(position)))
	if age<FLIGHT_SECONDS:
		canvas.draw_line(tail,at,Color("292435"),3)
		canvas.draw_line(tail,at,Color("b79361"),1)
	canvas.draw_circle(at,RADIUS+1,Color("292435")); canvas.draw_circle(at,RADIUS,Color("d0c5b6"))
	canvas.draw_colored_polygon(PackedVector2Array([at+Vector2(-4,0),at+Vector2(0,-4),at+Vector2(4,0),at+Vector2(0,4)]),Color("ed8877"))
