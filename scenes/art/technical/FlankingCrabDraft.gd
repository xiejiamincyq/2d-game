extends "res://scenes/art/technical/NativeMonsterSample.gd"
const SkinBuilder = preload("res://scenes/art/technical/NativePaperSkin.gd")
const Shapes = preload("res://scenes/art/technical/FlankingCrabShapes.gd")
func _init() -> void:
	visual_bounds_padding = 14
	var facing := Node2D.new()
	facing.name = "Facing"
	add_child(facing)
	var rig := Skeleton2D.new()
	rig.name = "Skeleton2D"
	facing.add_child(rig)
	var torso := joint(rig,"Torso",Vector2(0,1),23)
	for leg_name in ["FL","FR","BL","BR"]:
		var sx := -1 if leg_name.ends_with("L") else 1
		var front: bool = leg_name.begins_with("F")
		var leg := joint(torso,"Leg"+leg_name,Vector2(sx*21,10 if front else -4),15)
		joint(leg,"Shin"+leg_name,Vector2(sx*12,4),14)
	for side in ["L","R"]:
		var sx := -1 if side=="L" else 1
		var arm := joint(torso,"Arm"+side,Vector2(sx*22,-8),15)
		var claw := joint(arm,"Claw"+side,Vector2(sx*13,-3),20)
		var jaw := joint(claw,"Jaw"+side,Vector2(sx*7,3),19)
		var tip := Marker2D.new()
		tip.name = "Tip"
		tip.position = Vector2(sx*20,5)
		jaw.add_child(tip)
	joint(torso,"Shell",Vector2(0,-1),30)
	var head := joint(torso,"Head",Vector2(0,-18),18)
	joint(head,"EyeL",Vector2(-7,-4),17)
	joint(head,"EyeR",Vector2(9,-5),18)
	joint(head,"Mandible",Vector2(0,5),11)
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
func joint(parent: Node,bone_name: String,at: Vector2,length: float) -> Bone2D:
	var bone := Bone2D.new()
	bone.name = bone_name
	bone.position = at
	bone.rest = bone.transform
	bone.set_autocalculate_length_and_angle(false)
	bone.set_length(length)
	parent.add_child(bone)
	return bone
func _ready() -> void:
	if not $Facing/Skin.build(skeleton,Shapes.new().make()):
		push_error("FLANKING CRAB BUILD FAIL: opaque articulated cutout")
		return
	super._ready()
func _build_clips() -> void:
	var library := AnimationLibrary.new()
	var idle := _new_clip(1.4,true)
	_keys(idle,TORSO+":position",[0,0.7,1.4],[Vector2(0,1),Vector2(0,0),Vector2(0,1)])
	_rotation_keys(idle,"/Head/EyeL",[0,0.7,1.4],[0,-5,0])
	_rotation_keys(idle,"/Head/EyeR",[0,0.7,1.4],[0,4,0])
	_rotation_keys(idle,"/ArmR/ClawR/JawR",[0,0.7,1.4],[0,4,0])
	library.add_animation("idle",idle)
	var walk := _new_clip(0.64,true)
	var gait := [0,0.16,0.32,0.48,0.64]
	_keys(walk,TORSO+":position",gait,[Vector2(0,1),Vector2(1,-1),Vector2(0,1),Vector2(-1,-1),Vector2(0,1)])
	_rotation_keys(walk,"/Shell",gait,[0,3,0,-3,0])
	for leg_name in ["FL","FR","BL","BR"]:
		var phase := 1 if leg_name in ["FL","BR"] else -1
		_rotation_keys(walk,"/Leg"+leg_name,gait,[0,phase*15,0,-phase*15,0])
		_rotation_keys(walk,"/Leg"+leg_name+"/Shin"+leg_name,gait,[0,-phase*19,0,phase*19,0])
	_rotation_keys(walk,"/ArmL",gait,[0,-4,0,4,0])
	_rotation_keys(walk,"/ArmR",gait,[0,4,0,-4,0])
	library.add_animation("walk",walk)
	var warning := _new_clip(0.18)
	_keys(warning,TORSO+":position",[0,0.18],[Vector2(0,1),Vector2(0,3)])
	_rotation_keys(warning,"/ArmL",[0,0.18],[0,12])
	_rotation_keys(warning,"/ArmR",[0,0.18],[0,-12])
	_rotation_keys(warning,"/ArmL/ClawL/JawL",[0,0.18],[0,24])
	_rotation_keys(warning,"/ArmR/ClawR/JawR",[0,0.18],[0,-24])
	library.add_animation("warning",warning)
	var attack := _new_clip(0.32)
	var snap := [0,0.04,0.12,0.32]
	_keys(attack,TORSO+":position",snap,[Vector2(0,3),Vector2(0,-1),Vector2(0,0),Vector2(0,1)])
	_rotation_keys(attack,"/ArmL",snap,[12,-10,-5,0])
	_rotation_keys(attack,"/ArmR",snap,[-12,10,5,0])
	_rotation_keys(attack,"/ArmL/ClawL/JawL",snap,[24,-10,-4,0])
	_rotation_keys(attack,"/ArmR/ClawR/JawR",snap,[-24,10,4,0])
	_rotation_keys(attack,"/Head/Mandible",snap,[0,9,3,0])
	library.add_animation("attack",attack)
	var hit := _new_clip(0.16)
	_rotation_keys(hit,"",[0,0.04,0.16],[0,-8,0])
	_rotation_keys(hit,"/Shell",[0,0.04,0.16],[0,11,0])
	_rotation_keys(hit,"/Head/EyeR",[0,0.04,0.16],[0,-13,0])
	library.add_animation("hit",hit)
	var death := _new_clip(0.56)
	_keys(death,TORSO+":position",[0,0.2,0.56],[Vector2(0,1),Vector2(0,5),Vector2(0,10)])
	_rotation_keys(death,"",[0,0.2,0.56],[0,15,40])
	_rotation_keys(death,"/Shell",[0,0.56],[0,-17])
	for leg_name in ["FL","FR","BL","BR"]:
		var sx := -1 if leg_name.ends_with("L") else 1
		_rotation_keys(death,"/Leg"+leg_name,[0,0.56],[0,sx*28])
	_rotation_keys(death,"/ArmL",[0,0.56],[0,23])
	_rotation_keys(death,"/ArmR",[0,0.56],[0,-23])
	_rotation_keys(death,"/Head/EyeL",[0,0.56],[0,32])
	_rotation_keys(death,"/Head/EyeR",[0,0.56],[0,-32])
	library.add_animation("death",death)
	player.add_animation_library("",library)
