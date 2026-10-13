extends "res://scenes/art/technical/CinderRunnerDraft.gd"
## Original articulated charge revision. Existing original v1 lifecycle preserved;
## no borrowed art, root animation, attack event, or large-enemy animation.
func _build_clips() -> void:
	super._build_clips()
	var library := player.get_animation_library("")
	var crouch := _new_clip(0.18)
	_keys(crouch,TORSO+":position",[0,0.18],[Vector2(0,-5),Vector2(-2,-1)])
	_rotation_keys(crouch,"",[0,0.18],[0,-12])
	_rotation_keys(crouch,"/Head",[0,0.18],[0,12])
	_rotation_keys(crouch,"/Mantle",[0,0.18],[0,10])
	for side in ["L","R"]:
		_rotation_keys(crouch,"/Leg"+side,[0,0.18],[0,-18])
		_rotation_keys(crouch,"/Leg"+side+"/Shin"+side,[0,0.18],[0,30])
		_rotation_keys(crouch,"/Arm"+side,[0,0.18],[0,-28])
	library.add_animation("charge_warning",crouch)
	var charge := _new_clip(0.36)
	var times := [0,0.06,0.12,0.18,0.24,0.30,0.36]
	_keys(charge,TORSO+":position",times,[Vector2(-2,-1),Vector2(3,-5),Vector2(2,-3),Vector2(3,-5),Vector2(2,-3),Vector2(3,-5),Vector2(2,-3)])
	_rotation_keys(charge,"",times,[-12,22,18,22,18,22,18])
	_rotation_keys(charge,"/Head",times,[12,-14,-12,-14,-12,-14,-12])
	_rotation_keys(charge,"/Mantle",times,[10,-26,-20,-26,-20,-26,-20])
	_rotation_keys(charge,"/LegL",times,[-18,28,-25,28,-25,28,-25])
	_rotation_keys(charge,"/LegR",times,[-18,-25,28,-25,28,-25,28])
	_rotation_keys(charge,"/LegL/ShinL",times,[30,-12,28,-12,28,-12,28])
	_rotation_keys(charge,"/LegR/ShinR",times,[30,28,-12,28,-12,28,-12])
	_rotation_keys(charge,"/ArmL",times,[-28,-42,-38,-42,-38,-42,-38])
	_rotation_keys(charge,"/ArmR",times,[-28,-38,-42,-38,-42,-38,-42])
	library.add_animation("charge",charge)
	var recovery := _new_clip(0.24)
	var recover := [0,0.05,0.14,0.24]
	_keys(recovery,TORSO+":position",recover,[Vector2(2,-3),Vector2(0,0),Vector2(0,-3),Vector2(0,-5)])
	_rotation_keys(recovery,"",recover,[18,-9,-3,0])
	_rotation_keys(recovery,"/Head",recover,[-12,8,3,0])
	_rotation_keys(recovery,"/Mantle",recover,[-20,15,6,0])
	for side in ["L","R"]:
		_rotation_keys(recovery,"/Leg"+side,recover,[-10,-18,-8,0])
		_rotation_keys(recovery,"/Leg"+side+"/Shin"+side,recover,[15,26,10,0])
		_rotation_keys(recovery,"/Arm"+side,recover,[-40,15,5,0])
	library.add_animation("charge_recovery",recovery)
