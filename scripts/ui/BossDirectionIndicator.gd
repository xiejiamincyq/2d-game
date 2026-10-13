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

## All geometry is viewport pixels. Optional actor reserve preserves two-arg use.
func show_direction(safe_rect: Rect2, target: Vector2, actor_rect: Rect2 = Rect2()) -> void:
	var available := safe_rect.grow_individual(-size.x * 0.5, -size.y * 0.5, -size.x * 0.5, -size.y * 0.5)
	if available.size.x <= 0.0 or available.size.y <= 0.0:
		hide()
		return
	direction = (target - safe_rect.get_center()).normalized()
	if direction.is_zero_approx():
		direction = Vector2.UP
	var half := available.size * 0.5
	var distance := minf(half.x / maxf(absf(direction.x), 0.001), half.y / maxf(absf(direction.y), 0.001))
	var preferred := available.get_center()+direction*distance
	var center := _clear_edge_center(available,preferred,actor_rect)
	if not center.is_finite():
		hide() # No edge slot: do not cover an already visible, screen-filling body.
		return
	position = center-size*0.5
	direction = (target-center).normalized()
	if direction.is_zero_approx(): direction = Vector2.UP
	show()
	queue_redraw()

func _clear_edge_center(available: Rect2, preferred: Vector2, actor_rect: Rect2) -> Vector2:
	# A partly visible Boss can fail full framing. Keep the cue on the safe
	# screen edge, but never paint the 96px plate over its visible bones.
	if actor_rect.size==Vector2.ZERO: return preferred
	var reserve := actor_rect.grow(8)
	var candidates: Array[Vector2] = [preferred]
	for x in [preferred.x,available.position.x,available.end.x,reserve.position.x-size.x*0.5,reserve.end.x+size.x*0.5]:
		for y in [available.position.y,available.end.y]: candidates.append(Vector2(clampf(x,available.position.x,available.end.x),y))
	for y in [preferred.y,available.position.y,available.end.y,reserve.position.y-size.y*0.5,reserve.end.y+size.y*0.5]:
		for x in [available.position.x,available.end.x]: candidates.append(Vector2(x,clampf(y,available.position.y,available.end.y)))
	var best := Vector2(INF,INF); var best_score := INF
	for candidate in candidates: # Fixed 21 candidates, no search over the world.
		if Rect2(candidate-size*0.5,size).intersects(reserve): continue
		var score := candidate.distance_squared_to(preferred)
		if score<best_score: best = candidate; best_score = score
	return best

func _draw() -> void:
	draw_style_box(get_theme_stylebox("panel", "PanelContainer"), Rect2(Vector2.ZERO, size))
	var center := Vector2(18, 18)
	var side := direction.orthogonal()
	var triangle := PackedVector2Array([center + direction * 11, center - direction * 7 + side * 7, center - direction * 7 - side * 7])
	draw_colored_polygon(triangle, Color("f47e65"))
	triangle.append(triangle[0])
	draw_polyline(triangle, Color("254b45"), 2.0, true)
