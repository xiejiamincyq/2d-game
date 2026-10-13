extends "res://scenes/art/technical/NativeMonsterSample.gd"
const SkinBuilder = preload("res://scenes/art/technical/NativePaperSkin.gd")
const Shapes = preload("res://scenes/art/technical/CirclingShadeShapes.gd")
func _init() -> void:
	visual_bounds_padding = 13
	var facing := Node2D.new()
	facing.name = "Facing"
	add_child(facing)
	var rig := Skeleton2D.new()
	rig.name = "Skeleton2D"
	facing.add_child(rig)
	var torso := joint(rig,"Torso",Vector2(0,-7),26)
	var head := joint(torso,"Head",Vector2(0,-20),25)
	joint(head,"Mask",Vector2(0,1),18)
	joint(torso,"Collar",Vector2(0,-13),20)
	for side in ["L","R"]:
		var sx := -1 if side=="L" else 1
		var cape := joint(torso,"Cape"+side,Vector2(sx*11,-6),18)
		joint(cape,"Fold"+side,Vector2(sx*3,15),20)
		var leg := joint(torso,"Leg"+side,Vector2(sx*7,14),15)
		joint(leg,"Foot"+side,Vector2(0,12),13)
		var arm := joint(torso,"Arm"+side,Vector2(sx*17,-5),13)
		var hook := joint(arm,"Hook"+side,Vector2(sx*1,11),20)
		if side=="R":
			var strike := Marker2D.new()
			strike.name = "Strike"
			strike.position = Vector2(12,5)
			hook.add_child(strike)
	var charm := joint(torso,"Charm",Vector2(1,-3),12)
	joint(charm,"Pendant",Vector2(0,7),14)
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
		push_error("CIRCLING SHADE BUILD FAIL: opaque weighted skin")
		return
	super._ready()
func _build_clips() -> void:
	var library := AnimationLibrary.new()
	var idle := _new_clip(1.8,true)
	_keys(idle,TORSO+":position",[0,0.9,1.8],[Vector2(0,-7),Vector2(0,-8),Vector2(0,-7)])
	_rotation_keys(idle,"/Charm",[0,0.9,1.8],[0,-4,0])
	_rotation_keys(idle,"/CapeL/FoldL",[0,0.9,1.8],[0,3,0])
	library.add_animation("idle",idle)
	var walk := _new_clip(0.64,true)
	var gait := [0,0.16,0.32,0.48,0.64]
	_keys(walk,TORSO+":position",gait,[Vector2(0,-7),Vector2(-1,-9),Vector2(0,-7),Vector2(1,-9),Vector2(0,-7)])
	for side in ["L","R"]:
		var sx := -1 if side=="L" else 1
		_rotation_keys(walk,"/Leg"+side,gait,[0,sx*18,0,-sx*18,0])
		_rotation_keys(walk,"/Leg"+side+"/Foot"+side,gait,[0,-sx*10,0,sx*10,0])
		_rotation_keys(walk,"/Cape"+side,gait,[0,-sx*8,0,sx*8,0])
		_rotation_keys(walk,"/Cape"+side+"/Fold"+side,gait,[0,sx*14,0,-sx*10,0])
		_rotation_keys(walk,"/Arm"+side,gait,[0,-sx*11,0,sx*11,0])
	_rotation_keys(walk,"/Charm/Pendant",gait,[0,7,0,-7,0])
	library.add_animation("walk",walk)
	var warning := _new_clip(0.18)
	_keys(warning,TORSO+":position",[0,0.18],[Vector2(0,-7),Vector2(-2,-4)])
	_rotation_keys(warning,"/Head",[0,0.18],[0,-8])
	_rotation_keys(warning,"/ArmR",[0,0.18],[0,-42])
	_rotation_keys(warning,"/ArmR/HookR",[0,0.18],[0,-23])
	_rotation_keys(warning,"/CapeL",[0,0.18],[0,-13])
	library.add_animation("warning",warning)
	var attack := _new_clip(0.44)
	var strike := [0,0.035,0.14,0.30,0.44]
	_keys(attack,TORSO+":position",strike,[Vector2(-2,-4),Vector2(3,-8),Vector2(2,-7),Vector2(1,-7),Vector2(0,-7)])
	_rotation_keys(attack,"/ArmR",strike,[-42,-75,-44,-13,0])
	_rotation_keys(attack,"/ArmR/HookR",strike,[-23,28,14,5,0])
	_rotation_keys(attack,"/Head",strike,[-8,7,3,1,0])
	_rotation_keys(attack,"/CapeL",strike,[-13,-25,-17,-4,0])
	_rotation_keys(attack,"/CapeR/FoldR",strike,[0,28,15,5,0])
	_rotation_keys(attack,"/LegL",strike,[0,22,15,3,0])
	library.add_animation("attack",attack)
	var hit := _new_clip(0.16)
	_rotation_keys(hit,"",[0,0.035,0.16],[0,-11,0])
	_rotation_keys(hit,"/Head",[0,0.035,0.16],[0,-13,0])
	_rotation_keys(hit,"/Charm/Pendant",[0,0.035,0.16],[0,21,0])
	library.add_animation("hit",hit)
	var death := _new_clip(0.60)
	_keys(death,TORSO+":position",[0,0.24,0.60],[Vector2(0,-7),Vector2(0,0),Vector2(0,7)])
	_rotation_keys(death,"",[0,0.24,0.60],[0,-22,-72])
	_rotation_keys(death,"/CapeL",[0,0.60],[0,-31])
	_rotation_keys(death,"/CapeR",[0,0.60],[0,25])
	_rotation_keys(death,"/Head",[0,0.60],[0,-17])
	_rotation_keys(death,"/ArmR",[0,0.60],[0,-46])
	library.add_animation("death",death)
	player.add_animation_library("",library)
