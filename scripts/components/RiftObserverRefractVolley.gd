extends RefCounted
## Observer-local three-batch policy. The unique Director supplies every age.
const Fragment = preload("res://scripts/components/RiftObserverFragment.gd")
const RELEASES := [0.108,0.288,0.468]
const ANGLES := [[-0.32,-0.16,0.16],[-0.16,0.16,0.32],[-0.32,0.0,0.32]]
var fragments: Array[RefCounted] = []
var released := [false,false,false]
var births := [0.0,0.0,0.0]
var origins := PackedVector2Array([Vector2.INF,Vector2.INF,Vector2.INF])
var direction := Vector2.RIGHT
var path_length := 0.0
var attempt := {"attempted":false}
func _init() -> void:
	for _index in range(9): fragments.append(Fragment.new())
func begin(heading: Vector2,distance: float) -> bool:
	cancel()
	if not heading.is_finite() or heading.is_zero_approx() or not is_finite(distance) or distance<=0.001 or distance>Fragment.MAX_DISTANCE: return false
	direction = heading.normalized(); path_length = distance
	released = [false,false,false]; births = [0.0,0.0,0.0]
	origins = PackedVector2Array([Vector2.INF,Vector2.INF,Vector2.INF]); attempt = {"attempted":false}
	return true
func advance(director: Node,before: float,after: float,from_player: Vector2,to_player: Vector2,serial: int) -> void:
	for batch in range(3):
		if released[batch]:
			for offset in range(3):
				fragments[batch*3+offset].resolve_hit(maxf(0,before-births[batch]),maxf(0,after-births[batch]),from_player,to_player)
				if director.action_serial!=serial: return
		elif after>=RELEASES[batch]:
			# Consume even blocked births; never substitute centre or backdate damage.
			released[batch] = true; births[batch] = after
			origins[batch] = director.boss.get_action_origin(&"refract",Fragment.RADIUS,true)
			if origins[batch].distance_to(director.preview_paths[batch*6])>8: director.cancel_action(); director.attack_gap = 1.1; return
			for offset in range(3):
				var landing := origins[batch]+direction.rotated(ANGLES[batch][offset])*path_length
				fragments[batch*3+offset].arm(director.boss,director.target_player,origins[batch],landing,attempt)
func cancel() -> void:
	for fragment in fragments: fragment.cancel()
func draw_visual(canvas: Node2D) -> void:
	for fragment in fragments: fragment.draw_visual(canvas)
