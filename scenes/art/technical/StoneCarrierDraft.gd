extends "res://scenes/art/technical/NativeMonsterSample.gd"
const SkinBuilder = preload("res://scenes/art/technical/NativePaperSkin.gd")
const Shapes = preload("res://scenes/art/technical/StoneCarrierShapes.gd")
## Large rig: no warning/attack keys until every character skeleton is complete.
func _init() -> void:
	visual_bounds_padding = 10.0 # Entrance knee bend +6px settling, not hitbox.
	var facing := Node2D.new()
	facing.name = "Facing"
	add_child(facing)
	var rig := Skeleton2D.new()
	rig.name = "Skeleton2D"
	facing.add_child(rig)
	var torso := joint(rig,"Torso",Vector2(0,-8),22)
	joint(torso,"Head",Vector2(0,-25),20)
	joint(torso,"Backstone",Vector2(-12,-6),26)
	for side in ["L","R"]:
		var sign_x := -1 if side=="L" else 1
		var shoulder := joint(torso,"Shoulder"+side,Vector2(sign_x*22,-10),8)
		var arm := joint(shoulder,"Arm"+side,Vector2(sign_x*3,6),12)
		var forearm := joint(arm,"Forearm"+side,Vector2(0,12),12)
		var hand := joint(forearm,"Hand"+side,Vector2(0,13),14)
		var mount := Marker2D.new()
		mount.name = "SlamOrigin"
		mount.position = Vector2(0,13)
		hand.add_child(mount)
		var leg := joint(torso,"Leg"+side,Vector2(sign_x*9,17),9)
		var shin := joint(leg,"Shin"+side,Vector2(0,8),10)
		joint(shin,"Foot"+side,Vector2(0,9),11)
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
	if not $Facing/Skin.build(skeleton,Shapes.new().make()):
		push_error("STONE BUILD FAIL: weighted original skin")
		return
	super._ready()
func _build_clips() -> void:
	var library := AnimationLibrary.new()
	var idle := _new_clip(1.6,true)
	_keys(idle,TORSO+":position",[0,0.8,1.6],[Vector2(0,-8),Vector2(0,-9),Vector2(0,-8)])
	_rotation_keys(idle,"/Head",[0,0.8,1.6],[0,-1.5,0])
	_rotation_keys(idle,"/Backstone",[0,0.8,1.6],[0,2,0])
	_rotation_keys(idle,"/ShoulderL",[0,0.8,1.6],[0,-2,0])
	_rotation_keys(idle,"/ShoulderR",[0,0.8,1.6],[0,2,0])
	library.add_animation("idle",idle)
	var walk := _new_clip(1.0,true)
	var steps := [0,0.25,0.5,0.75,1.0]
	_keys(walk,TORSO+":position",steps,[Vector2(0,-8),Vector2(-1,-10),Vector2(0,-8),Vector2(1,-10),Vector2(0,-8)])
	_rotation_keys(walk,"",steps,[0,-3,0,3,0])
	_rotation_keys(walk,"/Backstone",steps,[0,5,0,-5,0])
	_rotation_keys(walk,"/LegL",steps,[0,16,0,-16,0])
	_rotation_keys(walk,"/LegR",steps,[0,-16,0,16,0])
	_rotation_keys(walk,"/LegL/ShinL",steps,[0,-15,0,22,0])
	_rotation_keys(walk,"/LegR/ShinR",steps,[0,22,0,-15,0])
	_rotation_keys(walk,"/ShoulderL",steps,[0,-6,0,6,0])
	_rotation_keys(walk,"/ShoulderR",steps,[0,6,0,-6,0])
	_rotation_keys(walk,"/ShoulderL/ArmL/ForearmL",steps,[0,4,0,-4,0])
	_rotation_keys(walk,"/ShoulderR/ArmR/ForearmR",steps,[0,-4,0,4,0])
	library.add_animation("walk",walk)
	var hit := _new_clip(0.18)
	_rotation_keys(hit,"",[0,0.04,0.18],[0,-7,0])
	_rotation_keys(hit,"/Head",[0,0.04,0.18],[0,9,0])
	_rotation_keys(hit,"/Backstone",[0,0.04,0.18],[0,-9,0])
	_rotation_keys(hit,"/ShoulderR",[0,0.04,0.18],[0,10,0])
	library.add_animation("hit",hit)
	var entrance := _new_clip(0.65)
	_keys(entrance,TORSO+":position",[0,0.2,0.45,0.65],[Vector2(0,-2),Vector2(0,-6),Vector2(0,-10),Vector2(0,-8)])
	_rotation_keys(entrance,"/Head",[0,0.65],[16,0])
	_rotation_keys(entrance,"/Backstone",[0,0.2,0.65],[-10,6,0])
	_rotation_keys(entrance,"/LegL/ShinL",[0,0.65],[25,0])
	_rotation_keys(entrance,"/LegR/ShinR",[0,0.65],[25,0])
	library.add_animation("entrance",entrance)
	var death := _new_clip(0.70)
	_keys(death,TORSO+":position",[0,0.25,0.70],[Vector2(0,-8),Vector2(0,3),Vector2(0,11)])
	_rotation_keys(death,"",[0,0.25,0.70],[0,28,82])
	_rotation_keys(death,"/Head",[0,0.70],[0,-18])
	_rotation_keys(death,"/Backstone",[0,0.70],[0,25])
	_rotation_keys(death,"/ShoulderL",[0,0.70],[0,-20])
	_rotation_keys(death,"/ShoulderR",[0,0.70],[0,18])
	_rotation_keys(death,"/LegR/ShinR",[0,0.70],[0,34])
	library.add_animation("death",death)
	player.add_animation_library("",library)
