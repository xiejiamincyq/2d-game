extends "res://scenes/art/technical/NativeMonsterSample.gd"
const SkinBuilder = preload("res://scenes/art/technical/NativePaperSkin.gd")
const Shapes = preload("res://scenes/art/technical/TideShellShapes.gd")
## Non-humanoid original boss, four articulated legs and two independent claws.
func _init() -> void:
	visual_bounds_padding = 16
	var facing := Node2D.new()
	facing.name = "Facing"
	add_child(facing)
	var rig := Skeleton2D.new()
	rig.name = "Skeleton2D"
	facing.add_child(rig)
	var torso := joint(rig,"Torso",Vector2(0,-4),36)
	var tail := joint(torso,"Tail",Vector2(0,19),21)
	marker(tail,"WakeOrigin",Vector2(0,19))
	for leg_name in ["FL","FR","BL","BR"]:
		var sign_x := -1 if leg_name.ends_with("L") else 1
		var front: bool = leg_name.begins_with("F")
		var leg := joint(torso,"Leg"+leg_name,Vector2(sign_x*(34 if front else 30),8 if front else -12),18)
		var shin := joint(leg,"Shin"+leg_name,Vector2(sign_x*(14 if front else 18),7 if front else 9),18)
		joint(shin,"Foot"+leg_name,Vector2(sign_x*(12 if front else 18),11 if front else 14),17)
	for side in ["L","R"]:
		var sign_x := -1 if side=="L" else 1
		var shoulder := joint(torso,"Shoulder"+side,Vector2(sign_x*44,-22),18)
		var arm := joint(shoulder,"Arm"+side,Vector2(sign_x*12,-6),20)
		var pincer := joint(arm,"Pincer"+side,Vector2(sign_x*15,-10),27)
		marker(pincer,"ClawOrigin",Vector2(sign_x*24,-5))
	var carapace := joint(torso,"Carapace",Vector2(0,-5),50)
	marker(carapace,"RippleOrigin",Vector2(0,8))
	var head := joint(torso,"Head",Vector2(0,-24),22)
	joint(head,"EyeStalkL",Vector2(-15,-6),26)
	joint(head,"EyeStalkR",Vector2(15,-6),26)
	joint(head,"Jaw",Vector2(0,10),15)
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
		push_error("TIDE BUILD FAIL: original opaque weighted carapace")
		return
	super._ready()
func _build_clips() -> void:
	var library := AnimationLibrary.new()
	var idle := _new_clip(1.8,true)
	_keys(idle,TORSO+":position",[0,0.9,1.8],[Vector2(0,-4),Vector2(0,-5.5),Vector2(0,-4)])
	_rotation_keys(idle,"/Carapace",[0,0.9,1.8],[0,1.2,0])
	_rotation_keys(idle,"/Head/EyeStalkL",[0,0.9,1.8],[0,-4,0])
	_rotation_keys(idle,"/Head/EyeStalkR",[0,0.6,1.2,1.8],[0,3,-2,0])
	_rotation_keys(idle,"/Head/Jaw",[0,0.9,1.8],[0,2,0])
	_rotation_keys(idle,"/ShoulderL/ArmL/PincerL",[0,0.9,1.8],[0,2,0])
	library.add_animation("idle",idle)
	var walk := _new_clip(0.8,true)
	var steps := [0,0.2,0.4,0.6,0.8]
	_keys(walk,TORSO+":position",steps,[Vector2(0,-4),Vector2(1,-6),Vector2(0,-4),Vector2(-1,-6),Vector2(0,-4)])
	_rotation_keys(walk,"/Carapace",steps,[0,2.5,0,-2.5,0])
	for leg_name in ["FL","FR","BL","BR"]:
		var phase_sign := 1 if leg_name in ["FL","BR"] else -1
		_rotation_keys(walk,"/Leg"+leg_name,steps,[0,phase_sign*10,0,-phase_sign*10,0])
		_rotation_keys(walk,"/Leg"+leg_name+"/Shin"+leg_name,steps,[0,-phase_sign*13,0,phase_sign*13,0])
		_rotation_keys(walk,"/Leg"+leg_name+"/Shin"+leg_name+"/Foot"+leg_name,steps,[0,phase_sign*6,0,-phase_sign*6,0])
	_rotation_keys(walk,"/ShoulderL",steps,[0,-3,0,3,0])
	_rotation_keys(walk,"/ShoulderR",steps,[0,3,0,-3,0])
	_rotation_keys(walk,"/ShoulderL/ArmL/PincerL",steps,[0,3,0,-3,0])
	_rotation_keys(walk,"/ShoulderR/ArmR/PincerR",steps,[0,-3,0,3,0])
	_rotation_keys(walk,"/Head/EyeStalkL",steps,[0,3,0,-3,0])
	_rotation_keys(walk,"/Head/EyeStalkR",steps,[0,-3,0,3,0])
	_rotation_keys(walk,"/Tail",steps,[0,4,0,-4,0])
	library.add_animation("walk",walk)
	var hit := _new_clip(0.2)
	_rotation_keys(hit,"/Carapace",[0,0.04,0.2],[0,-5,0])
	_rotation_keys(hit,"/Head",[0,0.04,0.2],[0,5,0])
	_rotation_keys(hit,"/Head/EyeStalkL",[0,0.05,0.2],[0,-8,0])
	_rotation_keys(hit,"/Head/EyeStalkR",[0,0.05,0.2],[0,8,0])
	_rotation_keys(hit,"/Tail",[0,0.06,0.2],[0,7,0])
	library.add_animation("hit",hit)
	var entrance := _new_clip(1.4)
	_keys(entrance,TORSO+":position",[0,0.5,1.0,1.4],[Vector2(0,3),Vector2(0,-2),Vector2(0,-6),Vector2(0,-4)])
	_rotation_keys(entrance,"/Carapace",[0,0.75,1.4],[-4,2,0])
	_rotation_keys(entrance,"/Head/EyeStalkL",[0,1.4],[15,0])
	_rotation_keys(entrance,"/Head/EyeStalkR",[0,1.4],[-15,0])
	_rotation_keys(entrance,"/ShoulderL",[0,1.4],[5,0])
	_rotation_keys(entrance,"/ShoulderR",[0,1.4],[-5,0])
	for leg_name in ["FL","FR","BL","BR"]:
		var side_sign := -1 if leg_name.ends_with("L") else 1
		_rotation_keys(entrance,"/Leg"+leg_name+"/Shin"+leg_name,[0,1.4],[side_sign*10,0])
	library.add_animation("entrance",entrance)
	var death := _new_clip(0.88)
	_keys(death,TORSO+":position",[0,0.3,0.88],[Vector2(0,-4),Vector2(0,3),Vector2(0,13)])
	_rotation_keys(death,"",[0,0.3,0.88],[0,8,22])
	_rotation_keys(death,"/Carapace",[0,0.88],[0,-15])
	_rotation_keys(death,"/Head/EyeStalkL",[0,0.88],[0,43])
	_rotation_keys(death,"/Head/EyeStalkR",[0,0.88],[0,-43])
	_rotation_keys(death,"/Head/Jaw",[0,0.88],[0,-10])
	_rotation_keys(death,"/Tail",[0,0.88],[0,-14])
	for leg_name in ["FL","FR","BL","BR"]:
		var side_sign := -1 if leg_name.ends_with("L") else 1
		_rotation_keys(death,"/Leg"+leg_name,[0,0.88],[0,side_sign*18])
		_rotation_keys(death,"/Leg"+leg_name+"/Shin"+leg_name,[0,0.88],[0,-side_sign*26])
	_rotation_keys(death,"/ShoulderL/ArmL",[0,0.88],[0,14])
	_rotation_keys(death,"/ShoulderR/ArmR",[0,0.88],[0,-14])
	library.add_animation("death",death)
	player.add_animation_library("",library)
