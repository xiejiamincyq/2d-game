extends Node2D

# Technical CC0 cutout sample, not approved final art or a gameplay actor.
# All keys target native bones. Combat controllers remain authoritative.
const TORSO := "Facing/Skeleton2D/Torso"
const CLIPS := ["idle", "walk", "warning", "attack", "hit", "death"]
@onready var skeleton: Skeleton2D = $Facing/Skeleton2D
@onready var player: AnimationPlayer = $AnimationPlayer
var _dead := false

func _ready() -> void:
	_build_clips()
	player.animation_finished.connect(_on_animation_finished)
	play_clip("idle")

func play_clip(clip: String) -> bool:
	if _dead or clip not in CLIPS:
		return false
	if clip in ["idle", "walk"] and player.current_animation == clip:
		return true # Do not restart gait on every movement update.
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

func reset_sample() -> void:
	# Explicit laboratory-only reset; no implicit resurrection after death.
	_dead = false
	cancel_action()

func _restore_pose() -> void:
	player.stop()
	player.clear_queue()
	for index in skeleton.get_bone_count():
		skeleton.get_bone(index).apply_rest()
	$Warning.visible = false

func _on_animation_finished(clip: StringName) -> void:
	if clip != &"death" and not _dead:
		play_clip("idle")

func _new_clip(length: float, loop := false) -> Animation:
	var animation := Animation.new()
	animation.length = length
	animation.loop_mode = Animation.LOOP_LINEAR if loop else Animation.LOOP_NONE
	return animation

func _keys(animation: Animation, path: String, times: Array, values: Array) -> void:
	var track := animation.add_track(Animation.TYPE_VALUE)
	animation.track_set_path(track, NodePath(path))
	for index in times.size():
		animation.track_insert_key(track, times[index], values[index])

func _rotation_keys(animation: Animation, suffix: String, times: Array, degrees: Array) -> void:
	var radians: Array = []
	for degrees_value in degrees:
		radians.append(deg_to_rad(degrees_value))
	_keys(animation, TORSO + suffix + ":rotation", times, radians)

func _build_clips() -> void:
	var library := AnimationLibrary.new()
	var idle := _new_clip(1.2, true)
	_keys(idle, TORSO + ":position", [0.0, 0.6, 1.2], [Vector2(0, -10), Vector2(0, -11), Vector2(0, -10)])
	_rotation_keys(idle, "/Head", [0.0, 0.6, 1.2], [0.0, -2.0, 0.0])
	library.add_animation("idle", idle)
	var walk := _new_clip(0.64, true)
	var gait := [0.0, 0.16, 0.32, 0.48, 0.64]
	_keys(walk, TORSO + ":position", gait, [Vector2(0, -10), Vector2(0, -11.5), Vector2(0, -10), Vector2(0, -11.5), Vector2(0, -10)])
	_rotation_keys(walk, "/Head", gait, [0.0, 3.0, 0.0, -3.0, 0.0])
	_rotation_keys(walk, "/ArmL", gait, [0.0, -18.0, 0.0, 18.0, 0.0])
	_rotation_keys(walk, "/ArmR", gait, [0.0, 18.0, 0.0, -18.0, 0.0])
	_rotation_keys(walk, "/ArmL/ForearmL", gait, [0.0, 8.0, 0.0, -8.0, 0.0])
	_rotation_keys(walk, "/ArmR/ForearmR", gait, [0.0, -8.0, 0.0, 8.0, 0.0])
	_rotation_keys(walk, "/LegL", gait, [0.0, 22.0, 0.0, -22.0, 0.0])
	_rotation_keys(walk, "/LegR", gait, [0.0, -22.0, 0.0, 22.0, 0.0])
	_rotation_keys(walk, "/LegL/FootL", gait, [0.0, -12.0, 0.0, 12.0, 0.0])
	_rotation_keys(walk, "/LegR/FootR", gait, [0.0, 12.0, 0.0, -12.0, 0.0])
	library.add_animation("walk", walk)
	var warning := _new_clip(0.18)
	_keys(warning, "Warning:visible", [0.0, 0.18], [true, false])
	warning.value_track_set_update_mode(0, Animation.UPDATE_DISCRETE)
	_rotation_keys(warning, "/Head", [0.0, 0.06, 0.18], [0.0, -6.0, -3.0])
	_rotation_keys(warning, "/ArmR", [0.0, 0.18], [0.0, -20.0])
	library.add_animation("warning", warning)
	var attack := _new_clip(0.36)
	var strike := [0.0, 0.06, 0.12, 0.18, 0.36]
	_rotation_keys(attack, "", strike, [0.0, -6.0, 9.0, 3.0, 0.0])
	_rotation_keys(attack, "/ArmR", strike, [-20.0, -40.0, -105.0, -78.0, 0.0])
	_rotation_keys(attack, "/ArmR/ForearmR", strike, [30.0, 50.0, 10.0, 30.0, 0.0])
	_rotation_keys(attack, "/ArmR/ForearmR/HandR", strike, [-5.0, -15.0, 12.0, 6.0, 0.0])
	_rotation_keys(attack, "/Head", strike, [0.0, -4.0, 7.0, 2.0, 0.0])
	library.add_animation("attack", attack)
	var hit := _new_clip(0.16)
	_rotation_keys(hit, "", [0.0, 0.04, 0.16], [0.0, -11.0, 0.0])
	_rotation_keys(hit, "/Head", [0.0, 0.04, 0.16], [0.0, 12.0, 0.0])
	_rotation_keys(hit, "/ArmL", [0.0, 0.04, 0.16], [0.0, 15.0, 0.0])
	library.add_animation("hit", hit)
	var death := _new_clip(0.42)
	_keys(death, TORSO + ":position", [0.0, 0.16, 0.42], [Vector2(0, -10), Vector2(0, -3), Vector2(0, 6)])
	_rotation_keys(death, "", [0.0, 0.16, 0.42], [0.0, 25.0, 74.0])
	_rotation_keys(death, "/Head", [0.0, 0.16, 0.42], [0.0, 12.0, 25.0])
	_rotation_keys(death, "/ArmL", [0.0, 0.42], [0.0, 55.0])
	_rotation_keys(death, "/ArmR", [0.0, 0.42], [0.0, -40.0])
	library.add_animation("death", death)
	player.add_animation_library("", library)
