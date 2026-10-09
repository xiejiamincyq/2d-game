extends Node2D

# Newly authored compact visual only; no damage, collision or gameplay clock.
const duration := 0.14
const radius := 14.0
var phase := 0.0

func set_phase(value: float) -> void:
	if not is_finite(value):
		return
	phase = clampf(value, 0, 1)
	queue_redraw()

func _draw() -> void:
	if phase >= 1:
		return
	var reach := lerpf(5, radius, phase)
	var width := lerpf(3, 0.6, phase)
	for index in 5:
		var direction := Vector2.from_angle(index * TAU / 5 + 0.2)
		var normal := direction.orthogonal()
		var tip := direction * reach
		var base := direction * reach * 0.45
		draw_colored_polygon(PackedVector2Array([tip, base + normal * width, direction * 2, base - normal * width]), Color("1c2926"))
		if phase < 0.65:
			draw_line(base, tip - direction, Color("eadcc1"), 1)
	if phase < 0.45:
		draw_circle(Vector2.ZERO, 2, Color("b0784e"))
