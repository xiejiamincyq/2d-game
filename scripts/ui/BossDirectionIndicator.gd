extends Control

var direction := Vector2.UP

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	size = Vector2(96, 36)
	var text := Label.new()
	text.text = "BOSS"
	text.position = Vector2(34, 5)
	text.add_theme_font_size_override("font_size", 16)
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(text)
	hide()

func show_direction(safe_rect: Rect2, target: Vector2) -> void:
	var available := safe_rect.grow_individual(-size.x * 0.5, -size.y * 0.5, -size.x * 0.5, -size.y * 0.5)
	if available.size.x <= 0.0 or available.size.y <= 0.0:
		hide()
		return
	direction = (target - safe_rect.get_center()).normalized()
	if direction.is_zero_approx():
		direction = Vector2.UP
	var half := available.size * 0.5
	var distance := minf(half.x / maxf(absf(direction.x), 0.001), half.y / maxf(absf(direction.y), 0.001))
	position = available.get_center() + direction * distance - size * 0.5
	show()
	queue_redraw()

func _draw() -> void:
	draw_style_box(get_theme_stylebox("panel", "PanelContainer"), Rect2(Vector2.ZERO, size))
	var center := Vector2(18, 18)
	var side := direction.orthogonal()
	var triangle := PackedVector2Array([center + direction * 11, center - direction * 7 + side * 7, center - direction * 7 - side * 7])
	draw_colored_polygon(triangle, Color("f47e65"))
	triangle.append(triangle[0])
	draw_polyline(triangle, Color("254b45"), 2.0, true)
