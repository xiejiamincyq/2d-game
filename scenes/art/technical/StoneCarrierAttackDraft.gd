extends "res://scenes/art/technical/StoneCarrierDraft.gd"
## Original post-checkpoint slam. v1 reviewed geometry/rest/base clips retained;
## these new tracks never address gameplay, collision or damage events.
func _init() -> void:
	super._init()
	visual_bounds_padding = 28.0 # Raised fists and crouch, not collision radius.
func _build_clips() -> void:
	super._build_clips()
	var library: AnimationLibrary = player.get_animation_library("")
	var warning := _new_clip(0.5)
	var times := [0,0.24,0.42,0.5]
	_keys(warning,TORSO+":position",times,[Vector2(0,-8),Vector2(0,-11),Vector2(0,-12),Vector2(0,-3)])
	_rotation_keys(warning,"/Head",times,[0,-8,-10,8])
	_rotation_keys(warning,"/Backstone",times,[0,-5,-8,8])
	for side in ["L","R"]:
		var sign_x := 1 if side=="L" else -1
		_rotation_keys(warning,"/Shoulder"+side,times,[0,sign_x*138,sign_x*145,sign_x*18])
		_rotation_keys(warning,"/Shoulder"+side+"/Arm"+side+"/Forearm"+side,times,[0,sign_x*12,sign_x*16,sign_x*8])
		_rotation_keys(warning,"/Leg"+side+"/Shin"+side,times,[0,12,16,23])
	library.add_animation("slam_warning",warning)
	var impact := _new_clip(0.12)
	_keys(impact,TORSO+":position",[0,0.04,0.12],[Vector2(0,-3),Vector2(0,-1),Vector2(0,-3)])
	_rotation_keys(impact,"/Head",[0,0.04,0.12],[8,12,8])
	_rotation_keys(impact,"/Backstone",[0,0.04,0.12],[8,13,8])
	for side in ["L","R"]:
		var sign_x := 1 if side=="L" else -1
		_rotation_keys(impact,"/Shoulder"+side,[0,0.04,0.12],[sign_x*18,sign_x*8,sign_x*18])
		_rotation_keys(impact,"/Shoulder"+side+"/Arm"+side+"/Forearm"+side,[0,0.12],[sign_x*8,sign_x*8])
		_rotation_keys(impact,"/Leg"+side+"/Shin"+side,[0,0.04,0.12],[23,29,23])
	library.add_animation("slam_attack",impact)
	var recovery := _new_clip(0.63)
	_keys(recovery,TORSO+":position",[0,0.18,0.63],[Vector2(0,-3),Vector2(0,-6),Vector2(0,-8)])
	_rotation_keys(recovery,"/Head",[0,0.18,0.63],[8,-4,0])
	_rotation_keys(recovery,"/Backstone",[0,0.18,0.63],[8,-5,0])
	for side in ["L","R"]:
		var sign_x := 1 if side=="L" else -1
		_rotation_keys(recovery,"/Shoulder"+side,[0,0.18,0.63],[sign_x*18,sign_x*30,0])
		_rotation_keys(recovery,"/Shoulder"+side+"/Arm"+side+"/Forearm"+side,[0,0.63],[sign_x*8,0])
		_rotation_keys(recovery,"/Leg"+side+"/Shin"+side,[0,0.18,0.63],[23,12,0])
	library.add_animation("slam_recovery",recovery)
