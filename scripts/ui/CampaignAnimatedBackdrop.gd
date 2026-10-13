extends "CampaignBackdrop.gd"
## New original decorative variant. Never moves controls or owns gameplay time.
var _motion_seconds := 0.0

func _ready() -> void:
	super._ready()
	visibility_changed.connect(_sync_motion_processing)
	_sync_motion_processing()

func _sync_motion_processing() -> void:
	set_process(is_visible_in_tree())

func _process(delta: float) -> void:
	if not is_visible_in_tree() or not is_finite(delta) or delta <= 0.0:
		return
	# All three visual periods divide120; wrap continuously and bound long frames.
	_motion_seconds = fposmod(_motion_seconds + minf(delta, 0.1), 120.0)
	queue_redraw()

func _lamp_color() -> Color:
	var breath := (0.5 - 0.5 * cos(TAU * _motion_seconds / 6.0)) * 0.16
	return super._lamp_color().lerp(Color("dfb97e"), breath)

func _mist_offset(index: int) -> Vector2:
	if index < 0 or index >= 6:
		return Vector2.ZERO
	return Vector2(sin(TAU * _motion_seconds / 24.0) * 9.0 * (0.6 + 0.4 * cos(index * 0.7)),
		sin(TAU * _motion_seconds / 30.0) * 1.2 * cos(index * 0.5))
