extends "res://scenes/art/technical/NativeMonsterSample.gd"
const SkinBuilder = preload("res://scenes/art/technical/NativePaperSkin.gd")
const Shapes = preload("res://scenes/art/technical/EmberSparkShapes.gd")
func _init() -> void:
	visual_bounds_padding = 10
	var facing := Node2D.new()
	facing.name = "Facing"
	add_child(facing)
	var rig := Skeleton2D.new()
	rig.name = "Skeleton2D"
	facing.add_child(rig)
	var torso := joint(rig,"Torso",Vector2(0,-5),22)
	joint(torso,"Bellows",Vector2(-19,0),24)
	joint(torso,"Valve",Vector2(-12,7),12)
	joint(torso,"Chimney",Vector2(-6,-21),23)
	var head := joint(torso,"Head",Vector2(0,-19),18)
	joint(head,"Visor",Vector2(0,1),16)
	for side in ["L","R"]:
		var sx := -1 if side=="L" else 1
		var leg := joint(torso,"Leg"+side,Vector2(sx*8,16),10)
		var shin := joint(leg,"Shin"+side,Vector2(0,8),12)
		joint(shin,"Foot"+side,Vector2(0,10),13)
	var arm_l := joint(torso,"ArmL",Vector2(-16,2),12)
	joint(arm_l,"HandL",Vector2(0,9),10)
	var arm_r := joint(torso,"ArmR",Vector2(13,-4),14)
	var nozzle := joint(arm_r,"Nozzle",Vector2(10,3),23)
	var muzzle := Marker2D.new()
	muzzle.name = "Muzzle"
	muzzle.position = Vector2(23,0)
	nozzle.add_child(muzzle)
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
		push_error("EMBER SPARK BUILD FAIL: opaque weighted skin")
		return
	super._ready()
func _build_clips() -> void:
	var library := AnimationLibrary.new()
	var idle := _new_clip(1.6,true)
	_keys(idle,TORSO+":position",[0,0.8,1.6],[Vector2(0,-5),Vector2(0,-6),Vector2(0,-5)])
	_keys(idle,TORSO+"/Bellows:scale",[0,0.8,1.6],[Vector2.ONE,Vector2(1.035,0.98),Vector2.ONE])
	_rotation_keys(idle,"/Valve",[0,0.8,1.6],[0,5,0])
	library.add_animation("idle",idle)
	var walk := _new_clip(0.8,true)
	var gait := [0,0.2,0.4,0.6,0.8]
	_keys(walk,TORSO+":position",gait,[Vector2(0,-5),Vector2(-1,-7),Vector2(0,-5),Vector2(1,-7),Vector2(0,-5)])
	_rotation_keys(walk,"/LegL",gait,[0,16,0,-16,0])
	_rotation_keys(walk,"/LegR",gait,[0,-16,0,16,0])
	_rotation_keys(walk,"/LegL/ShinL",gait,[0,-8,0,14,0])
	_rotation_keys(walk,"/LegR/ShinR",gait,[0,14,0,-8,0])
	_rotation_keys(walk,"/LegL/ShinL/FootL",gait,[0,5,0,-7,0])
	_rotation_keys(walk,"/LegR/ShinR/FootR",gait,[0,-7,0,5,0])
	_rotation_keys(walk,"/Head",gait,[0,2,0,-2,0])
	_rotation_keys(walk,"/Bellows",gait,[0,-4,0,4,0])
	_rotation_keys(walk,"/Chimney",gait,[0,3,0,-3,0])
	_rotation_keys(walk,"/ArmL",gait,[0,-9,0,9,0])
	library.add_animation("walk",walk)
	var warning := _new_clip(0.18)
	_rotation_keys(warning,"",[0,0.09,0.18],[0,-3,-6])
	_keys(warning,TORSO+"/Bellows:scale",[0,0.18],[Vector2.ONE,Vector2(1.12,1.06)])
	_rotation_keys(warning,"/Valve",[0,0.18],[0,-16])
	_rotation_keys(warning,"/Head/Visor",[0,0.18],[0,-7])
	library.add_animation("warning",warning)
	var attack := _new_clip(0.24)
	var puff := [0,0.025,0.09,0.16,0.24]
	_rotation_keys(attack,"",puff,[-6,6,3,1,0])
	_keys(attack,TORSO+"/Bellows:scale",puff,[Vector2(1.12,1.06),Vector2(0.86,0.98),Vector2(0.96,1),Vector2.ONE,Vector2.ONE])
	_rotation_keys(attack,"/Valve",puff,[-16,12,7,2,0])
	_rotation_keys(attack,"/Head/Visor",puff,[-7,5,3,1,0])
	_rotation_keys(attack,"/Chimney",puff,[0,-8,-4,-1,0])
	library.add_animation("attack",attack)
	var hit := _new_clip(0.16)
	_rotation_keys(hit,"",[0,0.04,0.16],[0,-9,0])
	_rotation_keys(hit,"/Head",[0,0.04,0.16],[0,11,0])
	_rotation_keys(hit,"/Bellows",[0,0.04,0.16],[0,-13,0])
	library.add_animation("hit",hit)
	var death := _new_clip(0.56)
	_keys(death,TORSO+":position",[0,0.22,0.56],[Vector2(0,-5),Vector2(0,2),Vector2(0,9)])
	_rotation_keys(death,"",[0,0.22,0.56],[0,-27,-72])
	_rotation_keys(death,"/Chimney",[0,0.56],[0,20])
	_rotation_keys(death,"/Head/Visor",[0,0.56],[0,28])
	_rotation_keys(death,"/Bellows",[0,0.56],[0,24])
	_rotation_keys(death,"/ArmL",[0,0.56],[0,40])
	library.add_animation("death",death)
	player.add_animation_library("",library)
