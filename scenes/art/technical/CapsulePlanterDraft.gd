extends "res://scenes/art/technical/NativeMonsterSample.gd"
const SkinBuilder = preload("res://scenes/art/technical/NativePaperSkin.gd")
const Shapes = preload("res://scenes/art/technical/CapsulePlanterShapes.gd")
func _init() -> void:
	visual_bounds_padding = 12
	var facing := Node2D.new()
	facing.name = "Facing"
	add_child(facing)
	var rig := Skeleton2D.new()
	rig.name = "Skeleton2D"
	facing.add_child(rig)
	var torso := joint(rig,"Torso",Vector2(0,-3),24)
	var rack := joint(torso,"Rack",Vector2(-12,-4),28)
	for side in ["L","R"]:
		var sx := -1 if side=="L" else 1
		var bottle := joint(rack,"Bottle"+side,Vector2(-5+sx*7,-5),24)
		joint(bottle,"Cap"+side,Vector2(0,-18),10)
		var leg := joint(torso,"Leg"+side,Vector2(sx*8,15),11)
		var shin := joint(leg,"Shin"+side,Vector2(0,8),11)
		joint(shin,"Foot"+side,Vector2(0,9),13)
	var head := joint(torso,"Head",Vector2(2,-20),22)
	joint(head,"Mask",Vector2(9,3),15)
	var arm_l := joint(torso,"ArmL",Vector2(-14,0),13)
	joint(arm_l,"HandL",Vector2(-1,10),11)
	var arm_r := joint(torso,"ArmR",Vector2(13,-2),14)
	var forearm := joint(arm_r,"ForearmR",Vector2(9,5),13)
	var clamp := joint(forearm,"ClampR",Vector2(10,0),15)
	var payload := joint(clamp,"Payload",Vector2(8,1),13)
	var release := Marker2D.new()
	release.name = "Release"
	release.position = Vector2(9,0)
	payload.add_child(release)
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
		push_error("CAPSULE PLANTER BUILD FAIL: opaque weighted skin")
		return
	super._ready()
func _build_clips() -> void:
	var library := AnimationLibrary.new()
	var idle := _new_clip(1.5,true)
	_keys(idle,TORSO+":position",[0,0.75,1.5],[Vector2(0,-3),Vector2(0,-4),Vector2(0,-3)])
	_rotation_keys(idle,"/Rack/BottleL",[0,0.75,1.5],[0,-3,0])
	_rotation_keys(idle,"/Rack/BottleR/CapR",[0,0.75,1.5],[0,4,0])
	library.add_animation("idle",idle)
	var walk := _new_clip(0.8,true)
	var gait := [0,0.2,0.4,0.6,0.8]
	_keys(walk,TORSO+":position",gait,[Vector2(0,-3),Vector2(-1,-5),Vector2(0,-3),Vector2(1,-5),Vector2(0,-3)])
	for side in ["L","R"]:
		var sign_value := -1 if side=="L" else 1
		_rotation_keys(walk,"/Leg"+side,gait,[0,sign_value*16,0,-sign_value*16,0])
		_rotation_keys(walk,"/Leg"+side+"/Shin"+side,gait,[0,-sign_value*10,0,sign_value*13,0])
		_rotation_keys(walk,"/Rack/Bottle"+side,gait,[0,sign_value*5,0,-sign_value*5,0])
	_rotation_keys(walk,"/Rack",gait,[0,-3,0,3,0])
	_rotation_keys(walk,"/ArmL",gait,[0,10,0,-10,0])
	library.add_animation("walk",walk)
	var warning := _new_clip(0.18)
	_rotation_keys(warning,"",[0,0.09,0.18],[0,3,5])
	_rotation_keys(warning,"/ArmR",[0,0.18],[0,-18])
	_rotation_keys(warning,"/ArmR/ForearmR",[0,0.18],[0,25])
	_rotation_keys(warning,"/Rack/BottleR/CapR",[0,0.18],[0,12])
	library.add_animation("warning",warning)
	var attack := _new_clip(0.32)
	var plant := [0,0.06,0.15,0.24,0.32]
	_rotation_keys(attack,"",plant,[5,9,5,2,0])
	_rotation_keys(attack,"/ArmR",plant,[-18,18,12,5,0])
	_rotation_keys(attack,"/ArmR/ForearmR",plant,[25,-18,-10,-3,0])
	_rotation_keys(attack,"/ArmR/ForearmR/ClampR",plant,[0,15,10,4,0])
	_keys(attack,TORSO+"/ArmR/ForearmR/ClampR/Payload:scale",plant,[Vector2.ONE,Vector2(0.001,0.001),Vector2(0.001,0.001),Vector2(0.001,0.001),Vector2.ONE])
	_rotation_keys(attack,"/Rack/BottleR/CapR",plant,[12,-8,-5,-2,0])
	library.add_animation("attack",attack)
	var hit := _new_clip(0.16)
	_rotation_keys(hit,"",[0,0.04,0.16],[0,-9,0])
	_rotation_keys(hit,"/Rack",[0,0.04,0.16],[0,13,0])
	_rotation_keys(hit,"/Head",[0,0.04,0.16],[0,11,0])
	library.add_animation("hit",hit)
	var death := _new_clip(0.56)
	_keys(death,TORSO+":position",[0,0.22,0.56],[Vector2(0,-3),Vector2(0,2),Vector2(0,8)])
	_rotation_keys(death,"",[0,0.22,0.56],[0,-26,-70])
	_rotation_keys(death,"/Rack",[0,0.56],[0,18])
	_rotation_keys(death,"/Rack/BottleL",[0,0.56],[0,-22])
	_rotation_keys(death,"/Rack/BottleR",[0,0.56],[0,24])
	_rotation_keys(death,"/ArmR/ForearmR",[0,0.56],[0,-31])
	library.add_animation("death",death)
	player.add_animation_library("",library)
