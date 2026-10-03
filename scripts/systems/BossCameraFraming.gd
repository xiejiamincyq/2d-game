extends Node

const CombatView = preload("res://scripts/systems/CombatView.gd")
const MIN_ZOOM := 0.80
const PLAYER_VISUAL_RADIUS := 54.0
const SCREEN_INSET := 16.0
const EFFECT_RESERVE := 16.0 # Existing CameraEffects: up to 12px offset.
const FOLLOW_SPEED := 8.0

var active := false
var both_fit := false
var safe_screen_rect := Rect2()
var camera: Camera2D
var player: Node2D
var ui: GameUI
var boss: OverseerBoss
var world_bounds: Rect2
var reference: CombatView.Reference
var reference_center := Vector2.ZERO
var presentation_center := Vector2.ZERO
var original_limits: Array[int] = []
var combat_playing := false
var combat_paused := false

func setup(target: Camera2D, actor: Node2D, interface: GameUI, bounds: Rect2) -> void:
	camera = target
	player = actor
	ui = interface
	world_bounds = bounds
	original_limits = [camera.limit_left, camera.limit_top, camera.limit_right, camera.limit_bottom]
	process_mode = Node.PROCESS_MODE_PAUSABLE
	process_priority = 100000 # Apply after CameraEffects without taking its ownership.

func track_boss(actor: OverseerBoss) -> void:
	boss = actor

func set_combat_state(playing: bool, paused_state: bool) -> void:
	combat_playing = playing
	combat_paused = paused_state
	if paused_state:
		ui.boss_direction_indicator.hide()
	elif not playing:
		reset_framing()

func _process(delta: float) -> void:
	step_framing(delta)

func step_framing(delta: float) -> void:
	if combat_paused:
		return
	if not combat_playing or not is_instance_valid(boss) or boss.is_queued_for_deletion() or not boss.visible or not boss.entrance_resolved or boss.health.current_health <= 0.0:
		reset_framing()
		return
	var viewport_size := camera.get_viewport().get_visible_rect().size
	if not active:
		active = true
		reference = CombatView.Reference.new()
		reference_center = _clamp_reference(player.global_position, viewport_size)
		presentation_center = camera.get_screen_center_position()
		camera.position_smoothing_enabled = false
		CombatView.attach(camera, reference)
	reference_center = _clamp_reference(reference_center.lerp(player.global_position, minf(1.0, FOLLOW_SPEED * delta)), viewport_size)
	reference.visible_rect = Rect2(reference_center - viewport_size * 0.5, viewport_size)
	safe_screen_rect = _safe_band(viewport_size)
	var solve_rect := safe_screen_rect.grow(-EFFECT_RESERVE)
	if solve_rect.size.x <= 0.0 or solve_rect.size.y <= 0.0:
		# Unsupported tiny surfaces cannot promise full-body framing.
		both_fit = false
		ui.boss_direction_indicator.hide()
		return
	var player_rect := Rect2(player.global_position - Vector2.ONE * PLAYER_VISUAL_RADIUS, Vector2.ONE * PLAYER_VISUAL_RADIUS * 2.0)
	var boss_rect: Rect2 = boss.boss_visual.global_transform * boss.boss_visual.get_rect()
	var union := player_rect.merge(boss_rect)
	var required_zoom := minf(1.0, minf(solve_rect.size.x / union.size.x, solve_rect.size.y / union.size.y))
	var feasible := required_zoom >= MIN_ZOOM
	var desired_zoom := clampf(required_zoom, MIN_ZOOM, 1.0)
	var anchor := union.get_center() if feasible else player_rect.get_center()
	var desired_center := anchor + (viewport_size * 0.5 - solve_rect.get_center()) / desired_zoom
	var zoom_value := lerpf(camera.zoom.x, desired_zoom, minf(1.0, 6.0 * delta))
	camera.zoom = Vector2.ONE * zoom_value
	presentation_center = presentation_center.lerp(desired_center, minf(1.0, FOLLOW_SPEED * delta))
	# Keep the player usable even during smoothing or impossible Boss separations.
	var minimum := player_rect.end - (solve_rect.end - viewport_size * 0.5) / zoom_value
	var maximum := player_rect.position - (solve_rect.position - viewport_size * 0.5) / zoom_value
	presentation_center = presentation_center.clamp(minimum, maximum)
	var overscan := viewport_size * 0.5 / MIN_ZOOM
	camera.limit_left = int(world_bounds.position.x - overscan.x)
	camera.limit_top = int(world_bounds.position.y - overscan.y)
	camera.limit_right = int(world_bounds.end.x + overscan.x)
	camera.limit_bottom = int(world_bounds.end.y + overscan.y)
	camera.global_position = presentation_center
	camera.force_update_scroll()
	var projected_player: Rect2 = camera.get_viewport().canvas_transform * player_rect
	var projected_boss: Rect2 = boss.boss_visual.get_global_transform_with_canvas() * boss.boss_visual.get_rect()
	both_fit = safe_screen_rect.encloses(projected_player) and safe_screen_rect.encloses(projected_boss)
	if both_fit:
		ui.boss_direction_indicator.hide()
	else:
		ui.boss_direction_indicator.show_direction(safe_screen_rect, projected_boss.get_center())

func _safe_band(viewport_size: Vector2) -> Rect2:
	var top := 0.0
	var bottom := viewport_size.y
	for rect in ui.get_combat_occluder_rects():
		if rect.get_center().y < viewport_size.y * 0.5:
			top = maxf(top, rect.end.y)
		else:
			bottom = minf(bottom, rect.position.y)
	return Rect2(Vector2(0, top), Vector2(viewport_size.x, maxf(0.0, bottom - top))).grow(-SCREEN_INSET)

func _clamp_reference(center: Vector2, viewport_size: Vector2) -> Vector2:
	var half := viewport_size * 0.5
	var minimum := world_bounds.position + half
	var maximum := world_bounds.end - half
	for axis in range(2):
		if minimum[axis] > maximum[axis]:
			minimum[axis] = world_bounds.get_center()[axis]
			maximum[axis] = minimum[axis]
	return center.clamp(minimum, maximum)

func reset_framing() -> void:
	if is_instance_valid(ui):
		ui.boss_direction_indicator.hide()
	if not active or not is_instance_valid(camera):
		return
	CombatView.detach(camera)
	active = false
	both_fit = false
	reference = null
	camera.position = Vector2.ZERO
	camera.zoom = Vector2.ONE
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = FOLLOW_SPEED
	camera.limit_left = original_limits[0]
	camera.limit_top = original_limits[1]
	camera.limit_right = original_limits[2]
	camera.limit_bottom = original_limits[3]
	camera.reset_smoothing()
	camera.force_update_scroll()

func _exit_tree() -> void:
	reset_framing()
