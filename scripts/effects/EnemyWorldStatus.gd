extends Node2D
## Actor-local world hints, above bodies/projectiles but below CanvasLayer HUD.
## Never lift the physical actor or its native skin out of body Y sorting.
const Palette = preload("res://scripts/effects/HostileEffectPalette.gd")
const Drawing = preload("res://scripts/effects/HostileAttackDrawing.gd")
const STATUS_Z_INDEX := 23 # Player silhouette 21; world projectiles 22.
var _has_health := false
var _last_state: Array = []
var warning: Node2D
func _ready() -> void:
	name = "WorldStatus"
	# Read-only invalidation must observe controllers that cancel during pause.
	# This never advances combat, animation, damage, or the paused physics server.
	process_mode = Node.PROCESS_MODE_ALWAYS
	z_as_relative = false
	z_index = STATUS_Z_INDEX
	warning = Node2D.new()
	warning.name = "AttackWarning"
	warning.z_as_relative = false
	warning.z_index = STATUS_Z_INDEX+1 # A neighbour's bar must not erase a warning.
	warning.draw.connect(_draw_warning)
	add_child(warning)
	_has_health = get_parent().has_method("should_show_health_bar")
	refresh()
func _process(_delta: float) -> void:
	# State can also change through health signals and regional Boss controllers,
	# not only Enemy._queue_visual_redraw. Redraw only on actual hint changes.
	refresh()
func refresh() -> void:
	var actor := get_parent()
	var bar: bool = _has_health and actor.should_show_health_bar()
	var marker: bool = actor.should_show_attack_marker()
	var state := [bar, actor.get_health_bar_rect() if bar else Rect2(), actor.get_health_ratio() if bar else 0.0, marker, actor.get_attack_marker_top() if marker else 0.0]
	if state!=_last_state:
		_last_state = state
		queue_redraw()
		warning.queue_redraw()
func _draw() -> void:
	var actor := get_parent()
	if actor.is_queued_for_deletion(): return
	if _has_health and actor.should_show_health_bar():
		var bar: Rect2 = actor.get_health_bar_rect()
		draw_rect(bar,Palette.OUTLINE)
		draw_rect(Rect2(bar.position+Vector2.ONE,Vector2((bar.size.x-2.0)*actor.get_health_ratio(),4.0)),Palette.CORAL)

func _draw_warning() -> void:
	var actor := get_parent()
	if not actor.is_queued_for_deletion() and actor.should_show_attack_marker():
		Drawing.draw_head_warning(warning,actor.get_attack_marker_top())
