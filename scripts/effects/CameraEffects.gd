extends Node
class_name CameraEffects

var max_offset: float = 12.0
var max_rotation: float = 0.025
var trauma_decay: float = 3.2

var target_camera: Camera2D
var trauma: float = 0.0
var impact_direction: Vector2 = Vector2.ZERO
var elapsed: float = 0.0

func setup(camera: Camera2D) -> void:
	target_camera = camera
	clear_all()

func request_impact(intensity: float, direction: Vector2 = Vector2.ZERO) -> void:
	trauma = maxf(trauma, clampf(intensity, 0.0, 1.0))
	if direction != Vector2.ZERO:
		impact_direction = (impact_direction + direction.normalized()).normalized()

func _process(delta: float) -> void:
	if not is_instance_valid(target_camera):
		trauma = 0.0
		impact_direction = Vector2.ZERO
		return
	if trauma <= 0.0:
		_reset_camera_transform()
		return
	elapsed += delta
	trauma = maxf(0.0, trauma - trauma_decay * delta)
	var strength := trauma * trauma
	var noise := Vector2(sin(elapsed * 91.0), cos(elapsed * 73.0))
	var directional_bias := impact_direction * max_offset * 0.35
	target_camera.offset = (noise * max_offset * strength + directional_bias * strength).limit_length(max_offset)
	target_camera.rotation = clampf(sin(elapsed * 61.0) * max_rotation * strength, -max_rotation, max_rotation)
	if trauma <= 0.0:
		_reset_camera_transform()

func clear_all() -> void:
	trauma = 0.0
	impact_direction = Vector2.ZERO
	elapsed = 0.0
	_reset_camera_transform()

func _reset_camera_transform() -> void:
	if is_instance_valid(target_camera):
		target_camera.offset = Vector2.ZERO
		target_camera.rotation = 0.0

func _exit_tree() -> void:
	clear_all()
