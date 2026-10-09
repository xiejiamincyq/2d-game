extends Node2D

# Visual-only playback. Combat state owns hit timing, movement and health.
# The editable scene supplies bones, skin and a shared AnimationLibrary.
@onready var skeleton: Skeleton2D = $Facing/Skeleton2D
@onready var player: AnimationPlayer = $AnimationPlayer
var _dead := false
var body_rect := Rect2()

func _ready() -> void:
	var points: PackedVector2Array = $Facing/Skin.polygon
	if not points.is_empty():
		body_rect = Rect2(points[0], Vector2.ZERO)
		for point in points:
			body_rect = body_rect.expand(point)
		body_rect = body_rect.grow(4) # Conservative ordinary gait/action bounds, not collision.
	player.animation_finished.connect(_on_animation_finished)
	play_clip("idle")

func play_clip(clip: String) -> bool:
	if _dead or not player.has_animation(clip):
		return false
	if clip in ["idle", "walk"] and player.current_animation == clip:
		return true
	_restore_pose()
	_dead = clip == "death"
	player.play(clip)
	player.advance(0.0)
	return true

func cancel_action() -> bool:
	if _dead:
		return false
	_restore_pose()
	player.play("idle")
	player.advance(0.0)
	return true

func set_facing_left(left: bool) -> void:
	$Facing.scale = Vector2(-1.0 if left else 1.0, 1.0)

# Authoritative combat sampling, not a second autonomous attack clock.
# The actor draws its own head marker; suppress the resource's laboratory label.
func sample_clip(clip: String, seconds: float) -> bool:
	if not is_finite(seconds) or seconds < 0 or (_dead and clip != "death") or not player.has_animation(clip):
		return false
	player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	if player.current_animation != clip:
		_restore_pose()
		_dead = clip == "death"
		player.play(clip)
	var motion := player.get_animation(clip)
	var at := fposmod(seconds, motion.length) if motion.loop_mode != Animation.LOOP_NONE else minf(seconds, motion.length)
	player.seek(at, true)
	$Warning.visible = false
	return true

func _restore_pose() -> void:
	player.stop()
	player.clear_queue()
	for index in skeleton.get_bone_count():
		skeleton.get_bone(index).apply_rest()
	$Warning.visible = false

func _on_animation_finished(clip: StringName) -> void:
	if clip != &"death" and not _dead:
		play_clip("idle")
