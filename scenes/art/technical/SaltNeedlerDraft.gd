extends "res://scenes/art/technical/NativeMonsterSample.gd"
const SkinBuilder = preload("res://scenes/art/technical/NativePaperSkin.gd")
const Shapes = preload("res://scenes/art/technical/SaltNeedlerShapes.gd")
func _init() -> void:
	var facing := Node2D.new()
	facing.name = "Facing"
	add_child(facing)
	var rig := Skeleton2D.new()
	rig.name = "Skeleton2D"
	facing.add_child(rig)
	var torso := joint(rig,"Torso",Vector2(0,-8),16)
	joint(torso,"Head",Vector2(0,-16),16)
	joint(torso,"Scarf",Vector2(-7,-7),19)
	for side in ["L","R"]:
		var sign_x := -1 if side=="L" else 1
		var arm := joint(torso,"Arm"+side,Vector2(sign_x*10,-1),7)
		var forearm := joint(arm,"Forearm"+side,Vector2(0,7),6)
		var hand := joint(forearm,"Hand"+side,Vector2(1,6),5)
		if side=="R":
			var gun := joint(hand,"NeedleGun",Vector2(1,-2),26)
			var muzzle := Marker2D.new()
			muzzle.name = "Muzzle"
			muzzle.position = Vector2(27,-0.5)
			gun.add_child(muzzle)
		var leg := joint(torso,"Leg"+side,Vector2(sign_x*5,12),7)
		var shin := joint(leg,"Shin"+side,Vector2(0,7),7)
		joint(shin,"Foot"+side,Vector2(1,7),7)
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
func joint(parent: Node,joint_name: String,at: Vector2,length: float) -> Bone2D:
	var bone := Bone2D.new()
	bone.name = joint_name
	bone.position = at
	bone.rest = bone.transform
	bone.set_autocalculate_length_and_angle(false)
	bone.set_length(length)
	parent.add_child(bone)
	return bone
func _ready() -> void:
	if not $Facing/Skin.build(skeleton,_skin_patches()):
		push_error("NEEDLER BUILD FAIL: weighted original skin")
		return
	super._ready()
func _skin_patches() -> Array[Dictionary]:
	return Shapes.new().make()
func _build_clips() -> void:
	var library := AnimationLibrary.new()
	var idle := _new_clip(1.2,true)
	_rotation_keys(idle,"/Head",[0,0.6,1.2],[0,-2,0])
	_rotation_keys(idle,"/Scarf",[0,0.6,1.2],[0,5,0])
	_keys(idle,TORSO+":position",[0,0.6,1.2],[Vector2(0,-8),Vector2(0,-9),Vector2(0,-8)])
	library.add_animation("idle",idle)
	var walk := _new_clip(0.64,true)
	var stride := [0,0.16,0.32,0.48,0.64]
	_keys(walk,TORSO+":position",stride,[Vector2(0,-8),Vector2(0,-10),Vector2(0,-8),Vector2(0,-10),Vector2(0,-8)])
	_rotation_keys(walk,"/LegL",stride,[0,20,0,-20,0])
	_rotation_keys(walk,"/LegR",stride,[0,-20,0,20,0])
	_rotation_keys(walk,"/LegL/ShinL",stride,[0,-12,0,16,0])
	_rotation_keys(walk,"/LegR/ShinR",stride,[0,16,0,-12,0])
	_rotation_keys(walk,"/Scarf",stride,[0,-8,0,6,0])
	_rotation_keys(walk,"/ArmL",stride,[0,-12,0,12,0])
	_rotation_keys(walk,"/ArmR/ForearmR",stride,[0,-5,0,5,0])
	library.add_animation("walk",walk)
	var warning := _new_clip(0.30)
	_rotation_keys(warning,"",[0,0.30],[0,4])
	_rotation_keys(warning,"/Head",[0,0.30],[0,-4])
	_rotation_keys(warning,"/ArmR",[0,0.30],[0,-18])
	_rotation_keys(warning,"/ArmR/ForearmR",[0,0.30],[0,-9])
	_rotation_keys(warning,"/ArmL",[0,0.30],[0,-25])
	_rotation_keys(warning,"/ArmL/ForearmL",[0,0.30],[0,-24])
	library.add_animation("warning",warning)
	var attack := _new_clip(0.24)
	var fire := [0,0.035,0.10,0.24]
	_rotation_keys(attack,"",fire,[4,-7,-3,0])
	_rotation_keys(attack,"/Head",fire,[-4,6,3,0])
	_rotation_keys(attack,"/ArmR",fire,[-18,-28,-21,0])
	_rotation_keys(attack,"/ArmR/ForearmR",fire,[-9,-18,-10,0])
	_rotation_keys(attack,"/ArmL",fire,[-25,-33,-25,0])
	_rotation_keys(attack,"/Scarf",fire,[0,13,5,0])
	library.add_animation("attack",attack)
	var hit := _new_clip(0.16)
	_rotation_keys(hit,"",[0,0.045,0.16],[0,-12,0])
	_rotation_keys(hit,"/Head",[0,0.045,0.16],[0,10,0])
	_rotation_keys(hit,"/Scarf",[0,0.045,0.16],[0,-16,0])
	library.add_animation("hit",hit)
	var death := _new_clip(0.52)
	_keys(death,TORSO+":position",[0,0.23,0.52],[Vector2(0,-8),Vector2(0,3),Vector2(0,9)])
	_rotation_keys(death,"",[0,0.23,0.52],[0,32,78])
	_rotation_keys(death,"/Head",[0,0.52],[0,-17])
	_rotation_keys(death,"/ArmR",[0,0.52],[0,-30])
	_rotation_keys(death,"/LegL/ShinL",[0,0.52],[0,28])
	_rotation_keys(death,"/Scarf",[0,0.52],[0,23])
	library.add_animation("death",death)
	player.add_animation_library("",library)
