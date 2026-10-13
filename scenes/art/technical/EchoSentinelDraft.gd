extends "res://scenes/art/technical/NativeMonsterSample.gd"
const SkinBuilder = preload("res://scenes/art/technical/NativePaperSkin.gd")
const Shapes = preload("res://scenes/art/technical/EchoSentinelShapes.gd")
func _init() -> void:
	visual_bounds_padding = 12
	var facing := Node2D.new()
	facing.name = "Facing"
	add_child(facing)
	var rig := Skeleton2D.new()
	rig.name = "Skeleton2D"
	facing.add_child(rig)
	var torso := joint(rig,"Torso",Vector2(0,-4),27)
	var head := joint(torso,"Head",Vector2(0,-14),20)
	joint(head,"Mask",Vector2(1,0),18)
	joint(torso,"Crown",Vector2(0,-32),18)
	for side in ["L","R"]:
		var sx := -1 if side=="L" else 1
		var ear := joint(torso,"Ear"+side,Vector2(sx*14,-24),11)
		joint(ear,"Fan"+side,Vector2(sx*7,-5),19)
		var leg := joint(torso,"Leg"+side,Vector2(sx*9,17),11)
		var shin := joint(leg,"Shin"+side,Vector2(0,8),10)
		joint(shin,"Foot"+side,Vector2(0,8),13)
		var arm := joint(torso,"Arm"+side,Vector2(sx*21,0),12)
		joint(arm,"Mallet"+side,Vector2(sx*2,9),13)
	var clapper := joint(torso,"Clapper",Vector2(0,9),15)
	var tongue := joint(clapper,"Tongue",Vector2(0,11),14)
	var echo := Marker2D.new()
	echo.name = "Echo"
	echo.position = Vector2(0,5)
	tongue.add_child(echo)
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
		push_error("ECHO SENTINEL BUILD FAIL: opaque weighted skin")
		return
	super._ready()
func _build_clips() -> void:
	var library := AnimationLibrary.new()
	var idle := _new_clip(1.6,true)
	_keys(idle,TORSO+":position",[0,0.8,1.6],[Vector2(0,-4),Vector2(0,-5),Vector2(0,-4)])
	_rotation_keys(idle,"/Clapper",[0,0.8,1.6],[0,4,0])
	_rotation_keys(idle,"/EarL/FanL",[0,0.8,1.6],[0,-3,0])
	library.add_animation("idle",idle)
	var walk := _new_clip(0.8,true)
	var gait := [0,0.2,0.4,0.6,0.8]
	_keys(walk,TORSO+":position",gait,[Vector2(0,-4),Vector2(-1,-6),Vector2(0,-4),Vector2(1,-6),Vector2(0,-4)])
	for side in ["L","R"]:
		var sx := -1 if side=="L" else 1
		_rotation_keys(walk,"/Leg"+side,gait,[0,sx*16,0,-sx*16,0])
		_rotation_keys(walk,"/Leg"+side+"/Shin"+side,gait,[0,-sx*9,0,sx*13,0])
		_rotation_keys(walk,"/Ear"+side,gait,[0,sx*5,0,-sx*5,0])
		_rotation_keys(walk,"/Arm"+side,gait,[0,-sx*10,0,sx*10,0])
	_rotation_keys(walk,"/Clapper",gait,[0,12,0,-12,0])
	_rotation_keys(walk,"/Clapper/Tongue",gait,[0,-6,0,6,0])
	library.add_animation("walk",walk)
	var warning := _new_clip(0.18)
	_keys(warning,TORSO+":position",[0,0.18],[Vector2(0,-4),Vector2(0,-1)])
	_rotation_keys(warning,"/EarL",[0,0.18],[0,14])
	_rotation_keys(warning,"/EarR",[0,0.18],[0,-14])
	_rotation_keys(warning,"/Clapper",[0,0.18],[0,-22])
	_rotation_keys(warning,"/ArmR",[0,0.18],[0,-24])
	library.add_animation("warning",warning)
	var attack := _new_clip(0.7)
	var ring := [0,0.06,0.18,0.32,0.49,0.60,0.70]
	_keys(attack,TORSO+":position",ring,[Vector2(0,-1),Vector2(0,-6),Vector2(1,-4),Vector2(-1,-4),Vector2(0,-4),Vector2(0,-4),Vector2(0,-4)])
	_rotation_keys(attack,"/Clapper",ring,[-22,26,-17,10,-4,1,0])
	_rotation_keys(attack,"/Clapper/Tongue",ring,[0,-14,10,-6,2,0,0])
	_rotation_keys(attack,"/EarL",ring,[14,-12,-7,-3,-1,0,0])
	_rotation_keys(attack,"/EarR",ring,[-14,12,7,3,1,0,0])
	_rotation_keys(attack,"/EarL/FanL",ring,[0,-9,-4,-2,0,0,0])
	_rotation_keys(attack,"/EarR/FanR",ring,[0,9,4,2,0,0,0])
	_rotation_keys(attack,"/ArmR",ring,[-24,16,10,5,1,0,0])
	library.add_animation("attack",attack)
	var hit := _new_clip(0.16)
	_rotation_keys(hit,"",[0,0.04,0.16],[0,-9,0])
	_rotation_keys(hit,"/EarL/FanL",[0,0.04,0.16],[0,15,0])
	_rotation_keys(hit,"/Clapper",[0,0.04,0.16],[0,18,0])
	library.add_animation("hit",hit)
	var death := _new_clip(0.56)
	_keys(death,TORSO+":position",[0,0.22,0.56],[Vector2(0,-4),Vector2(0,1),Vector2(0,7)])
	_rotation_keys(death,"",[0,0.22,0.56],[0,-25,-67])
	_rotation_keys(death,"/EarL",[0,0.56],[0,29])
	_rotation_keys(death,"/EarR",[0,0.56],[0,-31])
	_rotation_keys(death,"/Clapper",[0,0.56],[0,42])
	_rotation_keys(death,"/ArmL",[0,0.56],[0,32])
	library.add_animation("death",death)
	player.add_animation_library("",library)
