extends "res://scenes/art/technical/NativeMonsterSample.gd"
const SkinBuilder = preload("res://scenes/art/technical/NativePaperSkin.gd")
const Shapes = preload("res://scenes/art/technical/RiftEliteShapes.gd")
func _init() -> void:
	visual_bounds_padding = 16
	var facing := Node2D.new()
	facing.name = "Facing"
	add_child(facing)
	var rig := Skeleton2D.new()
	rig.name = "Skeleton2D"
	facing.add_child(rig)
	var torso := joint(rig,"Torso",Vector2(0,-8),27)
	var head := joint(torso,"Head",Vector2(0,-19),23)
	joint(head,"Mask",Vector2(0,1),16)
	var core := joint(torso,"Core",Vector2(0,-1),12)
	joint(core,"Lens",Vector2(0,1),8)
	var halo := joint(torso,"Halo",Vector2(0,-10),23)
	for side in ["L","R"]:
		var sx := -1 if side=="L" else 1
		joint(halo,"Prism"+side,Vector2(sx*20,-2),16)
		var arm := joint(torso,"Arm"+side,Vector2(sx*17,-8),13)
		var forearm := joint(arm,"Forearm"+side,Vector2(sx*1,10),13)
		var blade := joint(forearm,"Blade"+side,Vector2(sx*1,10),22)
		if side=="R":
			var muzzle := Marker2D.new()
			muzzle.name = "Muzzle"
			muzzle.position = Vector2(18,7)
			blade.add_child(muzzle)
		var leg := joint(torso,"Leg"+side,Vector2(sx*7,13),13)
		var shin := joint(leg,"Shin"+side,Vector2(0,10),13)
		joint(shin,"Foot"+side,Vector2(0,10),13)
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
		push_error("RIFT ELITE BUILD FAIL: opaque weighted skin")
		return
	super._ready()
func _build_clips() -> void:
	var library := AnimationLibrary.new()
	var idle := _new_clip(1.6,true)
	_keys(idle,TORSO+":position",[0,0.8,1.6],[Vector2(0,-8),Vector2(0,-9),Vector2(0,-8)])
	_rotation_keys(idle,"/Halo/PrismL",[0,0.8,1.6],[0,-6,0])
	_rotation_keys(idle,"/Halo/PrismR",[0,0.8,1.6],[0,6,0])
	_rotation_keys(idle,"/Core/Lens",[0,0.8,1.6],[0,8,0])
	library.add_animation("idle",idle)
	var walk := _new_clip(0.72,true)
	var gait := [0,0.18,0.36,0.54,0.72]
	_keys(walk,TORSO+":position",gait,[Vector2(0,-8),Vector2(-1,-10),Vector2(0,-8),Vector2(1,-10),Vector2(0,-8)])
	for side in ["L","R"]:
		var sx := -1 if side=="L" else 1
		_rotation_keys(walk,"/Leg"+side,gait,[0,sx*18,0,-sx*18,0])
		_rotation_keys(walk,"/Leg"+side+"/Shin"+side,gait,[0,-sx*15,0,sx*10,0])
		_rotation_keys(walk,"/Leg"+side+"/Shin"+side+"/Foot"+side,gait,[0,-sx*7,0,sx*6,0])
		_rotation_keys(walk,"/Arm"+side,gait,[0,-sx*9,0,sx*9,0])
		_rotation_keys(walk,"/Halo/Prism"+side,gait,[0,sx*10,0,-sx*5,0])
	library.add_animation("walk",walk)
	var warning := _new_clip(0.18)
	_keys(warning,TORSO+":position",[0,0.18],[Vector2(0,-8),Vector2(-1,-5)])
	for side in ["L","R"]:
		var sx := -1 if side=="L" else 1
		_rotation_keys(warning,"/Arm"+side,[0,0.18],[0,sx*28])
		_rotation_keys(warning,"/Arm"+side+"/Forearm"+side,[0,0.18],[0,sx*18])
		_rotation_keys(warning,"/Halo/Prism"+side,[0,0.18],[0,sx*13])
	library.add_animation("warning",warning)
	var strike := [0,0.025,0.12,0.25,0.40]
	var attack := _new_clip(0.40)
	_keys(attack,TORSO+":position",strike,[Vector2(-1,-5),Vector2(3,-9),Vector2(2,-8),Vector2(1,-8),Vector2(0,-8)])
	_rotation_keys(attack,"/ArmL",strike,[-28,-62,-43,-9,0])
	_rotation_keys(attack,"/ArmR",strike,[28,-48,-34,-9,0])
	_rotation_keys(attack,"/ArmL/ForearmL",strike,[-18,-20,12,4,0])
	_rotation_keys(attack,"/ArmR/ForearmR",strike,[18,27,16,5,0])
	_rotation_keys(attack,"/Head",strike,[0,9,5,1,0])
	library.add_animation("attack",attack)
	var shard := _new_clip(0.36)
	var release := [0,0.025,0.10,0.24,0.36]
	_keys(shard,TORSO+":position",release,[Vector2(-1,-5),Vector2(-3,-8),Vector2(-2,-9),Vector2(-1,-8),Vector2(0,-8)])
	for side in ["L","R"]:
		var sx := -1 if side=="L" else 1
		_rotation_keys(shard,"/Arm"+side,release,[sx*28,-sx*38,-sx*28,-sx*8,0])
		_rotation_keys(shard,"/Arm"+side+"/Forearm"+side,release,[sx*18,-sx*26,-sx*18,-sx*3,0])
		_rotation_keys(shard,"/Arm"+side+"/Forearm"+side+"/Blade"+side,release,[0,-sx*16,-sx*9,-sx*2,0])
		_rotation_keys(shard,"/Halo/Prism"+side,release,[sx*13,sx*28,sx*18,sx*5,0])
	_rotation_keys(shard,"/Core/Lens",release,[0,38,22,7,0])
	library.add_animation("shard_attack",shard)
	var hit := _new_clip(0.16)
	_rotation_keys(hit,"",[0,0.035,0.16],[0,-10,0])
	_rotation_keys(hit,"/Head",[0,0.035,0.16],[0,-12,0])
	_rotation_keys(hit,"/Halo",[0,0.035,0.16],[0,15,0])
	library.add_animation("hit",hit)
	var death := _new_clip(0.62)
	_keys(death,TORSO+":position",[0,0.22,0.62],[Vector2(0,-8),Vector2(0,0),Vector2(0,6)])
	_rotation_keys(death,"",[0,0.22,0.62],[0,25,77])
	_rotation_keys(death,"/Head",[0,0.62],[0,18])
	_rotation_keys(death,"/Halo/PrismL",[0,0.62],[0,-36])
	_rotation_keys(death,"/Halo/PrismR",[0,0.62],[0,42])
	_rotation_keys(death,"/ArmR",[0,0.62],[0,-39])
	library.add_animation("death",death)
	player.add_animation_library("",library)
