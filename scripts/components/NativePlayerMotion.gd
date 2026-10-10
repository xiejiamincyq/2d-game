extends Node
## Player owns normal visual time. Only terminal death uses paused UI time.
const Actor = preload("res://scenes/actors/native/player_paper_v1.tscn")
var target: Node2D
var view: Node2D
var shot_remaining := 0.0
var death_seconds := -1.0

func setup(player: Node2D) -> Node2D:
	target = player
	process_mode = PROCESS_MODE_ALWAYS
	view = Actor.instantiate()
	view.name = "NativePlayer"
	view.scale = Vector2.ONE * target.PLAYER_SIZE_SCALE
	target.add_child(view)
	target.health.died.connect(_begin_death)
	advance(0)
	return view

func advance(delta: float) -> void:
	# Detached build fixtures may initialize Player before Skeleton2D enters a tree.
	if death_seconds >= 0 or not view.is_inside_tree():
		return
	shot_remaining = maxf(0, shot_remaining - delta)
	sync_attributes()
	view.set_aim(Vector2.RIGHT.rotated(target.gun_angle))
	if target.entrance_active:
		view.sample_clip("entrance", target.entrance_elapsed)
	elif target.dash_active:
		view.sample_clip("dash", target.dash_duration - target.dash_timer)
	elif target.visual_hit_timer > 0.38:
		view.sample_clip("hit", 0.6 - target.visual_hit_timer)
	elif shot_remaining > 0:
		view.sample_moving_shot("walk" if target.velocity.length_squared() > 1 else "idle", target.visual_elapsed, 0.16 - shot_remaining)
	else:
		view.sample_clip("walk" if target.velocity.length_squared() > 1 else "idle", target.visual_elapsed)
	if not (target.get_global_mouse_position() - target.global_position).is_zero_approx():
		view.aim_hand_at(target.get_global_mouse_position())

func sync_attributes() -> void:
	view.position = Vector2(0, target.entrance_visual_offset)
	view.modulate = Color(1, 0.62, 0.62) if target.visual_hit_timer > 0 else Color.WHITE
	view.modulate.a = 0.42 if target.is_stealthed() else 1.0

func prepare_shot(direction: Vector2, aim_point: Vector2 = Vector2.INF) -> Vector2:
	shot_remaining = 0.16
	view.set_aim(direction)
	view.sample_moving_shot("walk" if target.velocity.length_squared() > 1 else "idle", target.visual_elapsed, 0)
	view.aim_hand_at(aim_point)
	return view.get_muzzle_position()

func _begin_death() -> void:
	death_seconds = 0
	sync_attributes()
	view.sample_clip("death", 0)

func _process(delta: float) -> void:
	if death_seconds >= 0 and death_seconds < 0.55:
		death_seconds = minf(0.55, death_seconds + delta)
		view.sample_clip("death", death_seconds)
