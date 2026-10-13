extends "res://scenes/art/technical/NativeMonsterSample.gd"
const SkinBuilder = preload("res://scenes/art/technical/NativePaperSkin.gd")
const Shapes = preload("res://scenes/art/technical/BellPriestShapes.gd")
## Original skeletal bell anatomy. No large attack/warning keys or events.
func _init() -> void:
	visual_bounds_padding = 16
	var facing := Node2D.new()
	facing.name = "Facing"
	add_child(facing)
	var rig := Skeleton2D.new()
	rig.name = "Skeleton2D"
	facing.add_child(rig)
	var torso := joint(rig,"Torso",Vector2(0,-10),36)
	for side in ["L","R"]:
		var sign_x := -1 if side=="L" else 1
		joint(torso,"Ribs"+side,Vector2(sign_x*22,-26),28)
		var leg := joint(torso,"Leg"+side,Vector2(sign_x*18,25),15)
		var shin := joint(leg,"Shin"+side,Vector2(0,15),15)
		joint(shin,"Foot"+side,Vector2(0,15),18)
		var arm := joint(torso,"Arm"+side,Vector2(sign_x*43,-23),20)
		var forearm := joint(arm,"Forearm"+side,Vector2(sign_x*2,17),20)
		var hand := joint(forearm,"Hand"+side,Vector2(0,18),13)
		var chain := joint(hand,"Chain"+side,Vector2(0,8),26)
		var pendant := joint(chain,"Pendant"+side,Vector2(0,26),20)
		marker(pendant,"PendantOrigin",Vector2(0,7))
	var bell := joint(torso,"Bell",Vector2(0,0),42)
	var clapper := joint(bell,"Clapper",Vector2(0,19),33)
	marker(clapper,"BeatOrigin",Vector2(0,29))
	joint(bell,"LipL",Vector2(0,36),42)
	joint(bell,"LipR",Vector2(0,36),42)
	var head := joint(torso,"Head",Vector2(0,-57),26)
	joint(head,"Mask",Vector2(0,12),17)
	var crown := joint(head,"Crown",Vector2(0,-19),26)
	marker(crown,"RecallOrigin",Vector2(0,-22))
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
		push_error("BELL PRIEST BUILD FAIL: opaque original weighted skin")
		return
	super._ready()
func _build_clips() -> void:
	var library := AnimationLibrary.new()
	var idle := _new_clip(1.8,true)
	_keys(idle,TORSO+":position",[0,0.9,1.8],[Vector2(0,-10),Vector2(0,-11),Vector2(0,-10)])
	_rotation_keys(idle,"/RibsL",[0,0.9,1.8],[0,-2,0])
	_rotation_keys(idle,"/RibsR",[0,0.9,1.8],[0,2,0])
	_rotation_keys(idle,"/Bell/Clapper",[0,0.9,1.8],[0,2.5,0])
	_rotation_keys(idle,"/Head/Mask",[0,0.9,1.8],[0,1.5,0])
	_rotation_keys(idle,"/ArmL/ForearmL/HandL/ChainL",[0,0.9,1.8],[0,2,0])
	_rotation_keys(idle,"/ArmR/ForearmR/HandR/ChainR",[0,0.9,1.8],[0,-2,0])
	library.add_animation("idle",idle)
	var walk := _new_clip(1.2,true)
	var gait := [0,0.3,0.6,0.9,1.2]
	_keys(walk,TORSO+":position",gait,[Vector2(0,-10),Vector2(-1,-12),Vector2(0,-10),Vector2(1,-12),Vector2(0,-10)])
	_rotation_keys(walk,"",gait,[0,-2,0,2,0])
	_rotation_keys(walk,"/LegL",gait,[0,10,0,-10,0])
	_rotation_keys(walk,"/LegR",gait,[0,-10,0,10,0])
	_rotation_keys(walk,"/LegL/ShinL",gait,[0,-7,0,15,0])
	_rotation_keys(walk,"/LegR/ShinR",gait,[0,15,0,-7,0])
	_rotation_keys(walk,"/LegL/ShinL/FootL",gait,[0,4,0,-6,0])
	_rotation_keys(walk,"/LegR/ShinR/FootR",gait,[0,-6,0,4,0])
	_rotation_keys(walk,"/ArmL",gait,[0,-4,0,4,0])
	_rotation_keys(walk,"/ArmR",gait,[0,4,0,-4,0])
	_rotation_keys(walk,"/ArmL/ForearmL",gait,[0,3,0,-3,0])
	_rotation_keys(walk,"/ArmR/ForearmR",gait,[0,-3,0,3,0])
	_rotation_keys(walk,"/ArmL/ForearmL/HandL/ChainL",gait,[0,9,0,-9,0])
	_rotation_keys(walk,"/ArmR/ForearmR/HandR/ChainR",gait,[0,-9,0,9,0])
	_rotation_keys(walk,"/ArmL/ForearmL/HandL/ChainL/PendantL",gait,[0,-11,0,11,0])
	_rotation_keys(walk,"/ArmR/ForearmR/HandR/ChainR/PendantR",gait,[0,11,0,-11,0])
	_rotation_keys(walk,"/Bell",gait,[0,1.8,0,-1.8,0])
	_rotation_keys(walk,"/Bell/Clapper",gait,[0,-4,0,4,0])
	_rotation_keys(walk,"/Bell/LipL",gait,[0,1.5,0,-1.5,0])
	_rotation_keys(walk,"/Bell/LipR",gait,[0,-1.5,0,1.5,0])
	_rotation_keys(walk,"/Head",gait,[0,2,0,-2,0])
	_rotation_keys(walk,"/Head/Crown",gait,[0,-3,0,3,0])
	library.add_animation("walk",walk)
	var hit := _new_clip(0.24)
	_rotation_keys(hit,"",[0,0.05,0.24],[0,-3,0])
	_rotation_keys(hit,"/Head/Mask",[0,0.06,0.24],[0,7,0])
	_rotation_keys(hit,"/Bell/Clapper",[0,0.07,0.24],[0,-8,0])
	_rotation_keys(hit,"/Bell/LipL",[0,0.05,0.24],[0,-3,0])
	_rotation_keys(hit,"/Bell/LipR",[0,0.05,0.24],[0,3,0])
	_rotation_keys(hit,"/ArmL/ForearmL/HandL/ChainL/PendantL",[0,0.08,0.24],[0,9,0])
	library.add_animation("hit",hit)
	var entrance := _new_clip(1.4)
	_keys(entrance,TORSO+":position",[0,0.6,1.1,1.4],[Vector2(0,-2),Vector2(0,-8),Vector2(0,-12),Vector2(0,-10)])
	_rotation_keys(entrance,"/Head",[0,0.9,1.4],[8,-2,0])
	_rotation_keys(entrance,"/Head/Crown",[0,0.8,1.4],[-6,2,0])
	_rotation_keys(entrance,"/Bell/Clapper",[0,0.8,1.4],[5,-2,0])
	_rotation_keys(entrance,"/ArmL/ForearmL/HandL/ChainL",[0,0.9,1.4],[-7,2,0])
	_rotation_keys(entrance,"/ArmR/ForearmR/HandR/ChainR",[0,0.9,1.4],[7,-2,0])
	library.add_animation("entrance",entrance)
	var death := _new_clip(0.98)
	_keys(death,TORSO+":position",[0,0.35,0.98],[Vector2(0,-10),Vector2(0,2),Vector2(0,16)])
	_rotation_keys(death,"",[0,0.35,0.98],[0,-19,-55])
	_rotation_keys(death,"/Head",[0,0.98],[0,14])
	_rotation_keys(death,"/Head/Crown",[0,0.98],[0,-18])
	_rotation_keys(death,"/Head/Mask",[0,0.98],[0,14])
	_rotation_keys(death,"/Bell",[0,0.98],[0,9])
	_rotation_keys(death,"/Bell/Clapper",[0,0.98],[0,24])
	_rotation_keys(death,"/LegL/ShinL",[0,0.98],[0,20])
	_rotation_keys(death,"/LegR/ShinR",[0,0.98],[0,-12])
	_rotation_keys(death,"/ArmL/ForearmL/HandL/ChainL",[0,0.98],[0,21])
	_rotation_keys(death,"/ArmR/ForearmR/HandR/ChainR",[0,0.98],[0,-17])
	library.add_animation("death",death)
	player.add_animation_library("",library)
