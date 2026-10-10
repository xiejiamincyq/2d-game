extends "res://scenes/art/technical/NativeMonsterSample.gd"
## Only lifecycle/key insertion helpers shared; all geometry and motion keys new.
const SkinBuilder = preload("res://scenes/art/technical/NativePaperSkin.gd")
const Shapes = preload("res://scenes/art/technical/CinderRunnerShapes.gd")
func _init() -> void:
	var facing := Node2D.new()
	facing.name = "Facing"
	add_child(facing)
	var rig := Skeleton2D.new()
	rig.name = "Skeleton2D"
	facing.add_child(rig)
	var torso := joint(rig,"Torso",Vector2(0,-5),13)
	joint(torso,"Head",Vector2(4,-13),15)
	joint(torso,"Mantle",Vector2(-7,-8),18)
	for side in ["L","R"]:
		var sign_x := -1 if side == "L" else 1
		var arm := joint(torso,"Arm"+side,Vector2(sign_x*11,-1),8)
		var forearm := joint(arm,"Forearm"+side,Vector2(0,8),6)
		joint(forearm,"Hand"+side,Vector2(1,6),5)
		var leg := joint(torso,"Leg"+side,Vector2(sign_x*5,10),7)
		var shin := joint(leg,"Shin"+side,Vector2(0,7),7)
		joint(shin,"Foot"+side,Vector2(2,7),7)
	var skin := SkinBuilder.new()
	skin.name = "Skin"
	facing.add_child(skin)
	var animator := AnimationPlayer.new()
	animator.name = "AnimationPlayer"
	add_child(animator)
	var warning := Label.new()
	warning.name = "Warning"
	warning.visible = false
	add_child(warning)
func joint(parent: Node, joint_name: String, at: Vector2, length: float) -> Bone2D:
	var bone := Bone2D.new()
	bone.name = joint_name
	bone.position = at
	bone.rest = bone.transform
	bone.set_autocalculate_length_and_angle(false)
	bone.set_length(length)
	parent.add_child(bone)
	return bone
func _ready() -> void:
	if not $Facing/Skin.build(skeleton,Shapes.new().make()):
		push_error("CINDER BUILD FAIL: skin binding")
		return
	super._ready()
func _build_clips() -> void:
	var library := AnimationLibrary.new()
	var idle := _new_clip(1.1,true)
	_rotation_keys(idle,"/Head",[0,0.55,1.1],[0,-2,0])
	_rotation_keys(idle,"/Mantle",[0,0.55,1.1],[0,4,0])
	_keys(idle,TORSO+":position",[0,0.55,1.1],[Vector2(0,-5),Vector2(0,-6),Vector2(0,-5)])
	library.add_animation("idle",idle)
	var walk := _new_clip(0.48,true)
	var stride := [0,0.12,0.24,0.36,0.48]
	_rotation_keys(walk,"",stride,[7,11,7,11,7])
	_keys(walk,TORSO+":position",stride,[Vector2(0,-5),Vector2(0,-7),Vector2(0,-5),Vector2(0,-7),Vector2(0,-5)])
	_rotation_keys(walk,"/LegL",stride,[0,28,0,-28,0])
	_rotation_keys(walk,"/LegR",stride,[0,-28,0,28,0])
	_rotation_keys(walk,"/LegL/ShinL",stride,[0,-18,0,22,0])
	_rotation_keys(walk,"/LegR/ShinR",stride,[0,22,0,-18,0])
	_rotation_keys(walk,"/LegL/ShinL/FootL",stride,[0,-10,0,7,0])
	_rotation_keys(walk,"/LegR/ShinR/FootR",stride,[0,7,0,-10,0])
	_rotation_keys(walk,"/ArmL",stride,[0,-22,0,22,0])
	_rotation_keys(walk,"/ArmR",stride,[0,22,0,-22,0])
	_rotation_keys(walk,"/Mantle",stride,[-3,-12,-3,4,-3])
	library.add_animation("walk",walk)
	var warning := _new_clip(0.18)
	_rotation_keys(warning,"",[0,0.18],[0,-9])
	_rotation_keys(warning,"/Head",[0,0.18],[0,7])
	_rotation_keys(warning,"/ArmR",[0,0.18],[0,-38])
	_rotation_keys(warning,"/ArmR/ForearmR",[0,0.18],[0,-22])
	_rotation_keys(warning,"/LegL/ShinL",[0,0.18],[0,12])
	library.add_animation("warning",warning)
	var attack := _new_clip(0.20)
	var strike := [0,0.03,0.08,0.20]
	_rotation_keys(attack,"",strike,[-9,13,8,0])
	_rotation_keys(attack,"/Head",strike,[7,-7,-3,0])
	_rotation_keys(attack,"/ArmR",strike,[-38,-92,-78,0])
	_rotation_keys(attack,"/ArmR/ForearmR",strike,[-22,-4,8,0])
	_rotation_keys(attack,"/Mantle",strike,[0,-18,-9,0])
	library.add_animation("attack",attack)
	var hit := _new_clip(0.16)
	_rotation_keys(hit,"",[0,0.045,0.16],[0,-13,0])
	_rotation_keys(hit,"/Head",[0,0.045,0.16],[0,9,0])
	_rotation_keys(hit,"/Mantle",[0,0.045,0.16],[0,-18,0])
	library.add_animation("hit",hit)
	var death := _new_clip(0.52)
	_keys(death,TORSO+":position",[0,0.22,0.52],[Vector2(0,-5),Vector2(0,4),Vector2(0,9)])
	_rotation_keys(death,"",[0,0.22,0.52],[0,35,82])
	_rotation_keys(death,"/Head",[0,0.52],[0,-16])
	_rotation_keys(death,"/Mantle",[0,0.52],[0,32])
	_rotation_keys(death,"/LegR/ShinR",[0,0.52],[0,38])
	_rotation_keys(death,"/ArmL",[0,0.52],[0,-35])
	library.add_animation("death",death)
	player.add_animation_library("",library)
