extends Node2D
## Visual-only four-view sampling; Player remains sole combat/input clock.
const DIRECTIONS := ["Front", "Back", "Left", "Right"]
const ANGLES := {"Front": PI / 2, "Back": -PI / 2, "Left": PI, "Right": 0.0}
var facing := "Front"
var clip := "idle"
var aim_offset := 0.0
var _seconds := 0.0
var _dead := false

func _ready() -> void:
	for direction in DIRECTIONS:
		var animator: AnimationPlayer = get_node(direction + "/AnimationPlayer")
		animator.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	sample_clip("idle", 0)

func set_aim(direction: Vector2) -> bool:
	if _dead or not direction.is_finite() or direction.is_zero_approx():
		return false
	# Normalize before a small tie tolerance: angle reconstruction and mouse ray
	# normalization must choose the same body at the diagonal boundary.
	direction = direction.normalized()
	if absf(direction.x) > absf(direction.y) + 0.00001:
		facing = "Right" if direction.x > 0 else "Left"
	else:
		facing = "Front" if direction.y > 0 else "Back"
	aim_offset = clampf(wrapf(direction.angle() - ANGLES[facing], -PI, PI), -PI / 4, PI / 4)
	return sample_clip(clip, _seconds)

func sample_clip(action: String, seconds: float) -> bool:
	if not is_finite(seconds) or seconds < 0 or (_dead and action != "death"):
		return false
	var view: Node2D = get_node(facing)
	var animator: AnimationPlayer = view.get_node("AnimationPlayer")
	if not animator.has_animation(action):
		return false
	clip = action
	_seconds = seconds
	_dead = action == "death"
	for direction in DIRECTIONS:
		get_node(direction).visible = direction == facing
	var rig: Skeleton2D = view.get_node("Skeleton2D")
	animator.stop()
	animator.clear_queue()
	for index in rig.get_bone_count():
		rig.get_bone(index).apply_rest()
	animator.play(action)
	var motion := animator.get_animation(action)
	var at := fposmod(seconds, motion.length) if motion.loop_mode != Animation.LOOP_NONE else minf(seconds, motion.length)
	animator.seek(at, true)
	var weapon: Bone2D = rig.get_node("Torso/ArmR/ForearmR/HandR/Weapon")
	weapon.rotation += aim_offset
	return true

func cancel_action() -> bool:
	return false if _dead else sample_clip("idle", 0)

func sample_moving_shot(locomotion: String, seconds: float, recoil_seconds: float) -> bool:
	if locomotion not in ["idle", "walk"] or not is_finite(recoil_seconds) or recoil_seconds < 0 or not sample_clip(locomotion, seconds):
		return false
	var rig: Skeleton2D = get_node(facing + "/Skeleton2D")
	var gait: Array[Transform2D] = []
	for index in rig.get_bone_count():
		gait.append(rig.get_bone(index).transform)
	sample_clip("shoot", recoil_seconds)
	for index in rig.get_bone_count():
		var bone := rig.get_bone(index)
		bone.transform = gait[index] * bone.rest.affine_inverse() * bone.transform if bone.name in [&"HandR", &"ForearmR", &"Head"] else gait[index]
	return true

func get_muzzle_position() -> Vector2:
	return get_node(facing + "/Skeleton2D/Torso/ArmR/ForearmR/HandR/Weapon/Muzzle").global_position

func aim_hand_at(point: Vector2) -> bool:
	if _dead or not point.is_finite():
		return false
	var weapon: Bone2D = get_node(facing + "/Skeleton2D/Torso/ArmR/ForearmR/HandR/Weapon")
	# Visual parallax only: never select a new body view or rotate the root. The
	# muzzle itself moves with the wrist, so refine a bounded residual three times.
	for iteration in 3:
		var ray := point - get_muzzle_position()
		if ray.is_zero_approx():
			return false
		var correction := wrapf(ray.angle() - weapon.global_rotation, -PI, PI)
		weapon.rotation = clampf(weapon.rotation + correction, weapon.rest.get_rotation() - PI / 4, weapon.rest.get_rotation() + PI / 4)
	return true
