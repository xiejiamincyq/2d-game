extends Node2D

# Visual-only playback. Combat state owns hit timing, movement and health.
# The editable scene supplies bones, skin and a shared AnimationLibrary.
@onready var skeleton: Skeleton2D = $Facing/Skeleton2D
@onready var player: AnimationPlayer = $AnimationPlayer
var _dead := false

func _ready() -> void:
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

func _restore_pose() -> void:
	player.stop()
	player.clear_queue()
	for index in skeleton.get_bone_count():
		skeleton.get_bone(index).apply_rest()
	$Warning.visible = false

func _on_animation_finished(clip: StringName) -> void:
	if clip != &"death" and not _dead:
		play_clip("idle")
