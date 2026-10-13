extends "res://scenes/art/technical/VineGuardDraft.gd"
## Original articulated nine-action extension, after the all-rig resource gate.
func _init() -> void:
	super._init()
	visual_bounds_padding = 48
func _build_clips() -> void:
	super._build_clips()
	var library: AnimationLibrary = player.get_animation_library("")
	_add_action(library,"lash",[0.30,0.14,0.55],-17,-11,{
		"/ShoulderR":[-28,-60],"/ShoulderR/ArmR":[-12,-18],
		"/ShoulderR/ArmR/ForearmR":[-25,16],"/VineR":[-24,-62],
		"/VineR/TipR":[-20,38],"/Head/Mask":[-5,8],"/Head/Crown":[-3,5]})
	_add_action(library,"roots",[0.40,0.18,0.50],-19,-7,{
		"/ShoulderL":[24,-12],"/ShoulderR":[-24,12],
		"/ShoulderL/ArmL/ForearmL":[18,-12],"/ShoulderR/ArmR/ForearmR":[-18,12],
		"/VineL":[18,-14],"/VineR":[-18,14],"/VineL/TipL":[15,24],
		"/VineR/TipR":[-15,-24],"/Head/Mask":[-5,8]})
	_add_action(library,"seeds",[0.35,0.12,0.65],-18,-10,{
		"/Head/Crown":[-14,14],"/Head":[-4,8],"/ShoulderL":[16,24],
		"/ShoulderR":[-16,-24],"/VineL":[6,12],"/VineR":[-6,-12]})
func _add_action(library: AnimationLibrary,prefix: String,durations: Array,prepare_y: float,impact_y: float,joints: Dictionary) -> void:
	var warning := _new_clip(durations[0])
	var attack := _new_clip(durations[1])
	var recovery := _new_clip(durations[2])
	_keys(warning,TORSO+":position",[0,durations[0]*0.65,durations[0]],[Vector2(0,-14),Vector2(0,prepare_y),Vector2(0,impact_y)])
	_keys(attack,TORSO+":position",[0,durations[1]*0.35,durations[1]],[Vector2(0,impact_y),Vector2(0,impact_y+2),Vector2(0,impact_y)])
	_keys(recovery,TORSO+":position",[0,durations[2]*0.45,durations[2]],[Vector2(0,impact_y),Vector2(0,-16),Vector2(0,-14)])
	for joint in joints:
		var prepare: float = joints[joint][0]
		var impact: float = joints[joint][1]
		_rotation_keys(warning,joint,[0,durations[0]*0.65,durations[0]],[0,prepare,impact])
		_rotation_keys(attack,joint,[0,durations[1]*0.35,durations[1]],[impact,impact*1.10,impact])
		_rotation_keys(recovery,joint,[0,durations[2]*0.45,durations[2]],[impact,prepare*0.15,0])
	library.add_animation(prefix+"_warning",warning)
	library.add_animation(prefix+"_attack",attack)
	library.add_animation(prefix+"_recovery",recovery)
