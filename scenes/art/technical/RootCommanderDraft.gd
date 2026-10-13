extends "res://scenes/art/technical/NativeMonsterSample.gd"
const SkinBuilder = preload("res://scenes/art/technical/NativePaperSkin.gd")
const Shapes = preload("res://scenes/art/technical/RootCommanderShapes.gd")
func _init() -> void:
	visual_bounds_padding = 16
	var facing := Node2D.new()
	facing.name = "Facing"
	add_child(facing)
	var rig := Skeleton2D.new()
	rig.name = "Skeleton2D"
	facing.add_child(rig)
	var torso := joint(rig,"Torso",Vector2(0,-7),34)
	var pack := joint(torso,"SeedPack",Vector2(-26,2),32)
	marker(pack,"ReinforcementOrigin",Vector2(0,8))
	for side in ["L","R"]:
		var sign_x := -1 if side=="L" else 1
		joint(torso,"Mantle"+side,Vector2(sign_x*22,-4),30)
		var leg := joint(torso,"Leg"+side,Vector2(sign_x*15,24),16)
		var shin := joint(leg,"Shin"+side,Vector2(0,14),18)
		joint(shin,"Foot"+side,Vector2(0,15),18)
		var arm := joint(torso,"Arm"+side,Vector2(sign_x*36,-11),22)
		var forearm := joint(arm,"Forearm"+side,Vector2(sign_x*2,18),22)
		var hand := joint(forearm,"Hand"+side,Vector2(-sign_x*2,16),13)
		if side=="R":
			var staff := joint(hand,"Staff",Vector2(7,-5),64)
			marker(staff,"StaffOrigin",Vector2(1,-47))
	var core := joint(torso,"Core",Vector2(0,0),18)
	marker(core,"CommandOrigin",Vector2.ZERO)
	var head := joint(torso,"Head",Vector2(0,-35),25)
	joint(head,"Hood",Vector2(0,-2),30)
	joint(head,"Mask",Vector2(0,10),18)
	joint(head,"HornL",Vector2(-22,-12),23)
	joint(head,"HornR",Vector2(22,-12),23)
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
func marker(parent: Node,marker_name: String,at: Vector2) -> void:
	var locator := Marker2D.new()
	locator.name = marker_name
	locator.position = at
	parent.add_child(locator)
func _ready() -> void:
	if not $Facing/Skin.build(skeleton,Shapes.new().make()):
		push_error("COMMANDER BUILD FAIL: original opaque weighted skin")
		return
	super._ready()
func _build_clips() -> void:
	var library := AnimationLibrary.new()
	var idle := _new_clip(1.8,true)
	_keys(idle,TORSO+":position",[0,0.9,1.8],[Vector2(0,-7),Vector2(0,-8),Vector2(0,-7)])
	_rotation_keys(idle,"/Head/HornL",[0,0.9,1.8],[0,-2.5,0])
	_rotation_keys(idle,"/Head/HornR",[0,0.9,1.8],[0,2.5,0])
	_rotation_keys(idle,"/Core",[0,0.9,1.8],[0,2,0])
	_rotation_keys(idle,"/SeedPack",[0,0.9,1.8],[0,-2,0])
	_rotation_keys(idle,"/ArmR/ForearmR/HandR/Staff",[0,0.9,1.8],[0,1.5,0])
	library.add_animation("idle",idle)
	var walk := _new_clip(1.04,true)
	var gait := [0,0.26,0.52,0.78,1.04]
	_keys(walk,TORSO+":position",gait,[Vector2(0,-7),Vector2(-1,-9),Vector2(0,-7),Vector2(1,-9),Vector2(0,-7)])
	_rotation_keys(walk,"",gait,[0,-2,0,2,0])
	_rotation_keys(walk,"/LegL",gait,[0,12,0,-12,0])
	_rotation_keys(walk,"/LegR",gait,[0,-12,0,12,0])
	_rotation_keys(walk,"/LegL/ShinL",gait,[0,-8,0,16,0])
	_rotation_keys(walk,"/LegR/ShinR",gait,[0,16,0,-8,0])
	_rotation_keys(walk,"/LegL/ShinL/FootL",gait,[0,4,0,-6,0])
	_rotation_keys(walk,"/LegR/ShinR/FootR",gait,[0,-6,0,4,0])
	_rotation_keys(walk,"/MantleL",gait,[0,-4,0,4,0])
	_rotation_keys(walk,"/MantleR",gait,[0,4,0,-4,0])
	_rotation_keys(walk,"/ArmL",gait,[0,5,0,-5,0])
	_rotation_keys(walk,"/ArmR",gait,[0,-2,0,2,0])
	_rotation_keys(walk,"/ArmR/ForearmR/HandR/Staff",gait,[0,3,0,-3,0])
	_rotation_keys(walk,"/Head/Hood",gait,[0,2.5,0,-2.5,0])
	_rotation_keys(walk,"/SeedPack",gait,[0,4,0,-4,0])
	library.add_animation("walk",walk)
	var hit := _new_clip(0.22)
	_rotation_keys(hit,"",[0,0.05,0.22],[0,-3,0])
	_rotation_keys(hit,"/Head/Mask",[0,0.05,0.22],[0,7,0])
	_rotation_keys(hit,"/SeedPack",[0,0.06,0.22],[0,-5,0])
	_rotation_keys(hit,"/Core",[0,0.05,0.22],[0,5,0])
	library.add_animation("hit",hit)
	var entrance := _new_clip(1.4)
	_keys(entrance,TORSO+":position",[0,0.6,1.1,1.4],[Vector2(0,1),Vector2(0,-5),Vector2(0,-9),Vector2(0,-7)])
	_rotation_keys(entrance,"/Head/Hood",[0,0.9,1.4],[-5,2,0])
	_rotation_keys(entrance,"/MantleL",[0,0.9,1.4],[6,-2,0])
	_rotation_keys(entrance,"/MantleR",[0,0.9,1.4],[-6,2,0])
	_rotation_keys(entrance,"/ArmR/ForearmR/HandR/Staff",[0,0.9,1.4],[-4,1,0])
	library.add_animation("entrance",entrance)
	var death := _new_clip(0.88)
	_keys(death,TORSO+":position",[0,0.3,0.88],[Vector2(0,-7),Vector2(0,3),Vector2(0,14)])
	_rotation_keys(death,"",[0,0.3,0.88],[0,-14,-33])
	_rotation_keys(death,"/Head/Hood",[0,0.88],[0,-13])
	_rotation_keys(death,"/Head/Mask",[0,0.88],[0,15])
	_rotation_keys(death,"/SeedPack",[0,0.88],[0,14])
	_rotation_keys(death,"/LegL/ShinL",[0,0.88],[0,18])
	_rotation_keys(death,"/LegR/ShinR",[0,0.88],[0,-14])
	_rotation_keys(death,"/ArmR/ForearmR/HandR/Staff",[0,0.88],[0,-12])
	library.add_animation("death",death)
	player.add_animation_library("",library)
