extends "res://scenes/art/technical/NativeMonsterSample.gd"
const SkinBuilder = preload("res://scenes/art/technical/NativePaperSkin.gd")
const Shapes = preload("res://scenes/art/technical/SpaceCutterShapes.gd")
func _init() -> void:
	visual_bounds_padding = 15
	var facing := Node2D.new()
	facing.name = "Facing"
	add_child(facing)
	var rig := Skeleton2D.new()
	rig.name = "Skeleton2D"
	facing.add_child(rig)
	var torso := joint(rig,"Torso",Vector2(0,-7),28)
	var head := joint(torso,"Head",Vector2(-2,-16),22)
	joint(head,"Visor",Vector2(0,1),18)
	var compass := joint(torso,"Compass",Vector2(0,-1),18)
	joint(compass,"Needle",Vector2(0,0),10)
	joint(torso,"TailFin",Vector2(-21,-4),17)
	var arm := joint(torso,"CutArm",Vector2(18,-3),16)
	var gimbal := joint(arm,"Gimbal",Vector2(8,8),13)
	var tine := joint(gimbal,"Tine",Vector2(8,0),24)
	var marker := Marker2D.new()
	marker.name = "Projector"
	marker.position = Vector2(21,2)
	tine.add_child(marker)
	var counter := joint(torso,"CounterArm",Vector2(-19,1),13)
	joint(counter,"Weight",Vector2(-4,9),15)
	for limb in ["BackL","BackR","FrontL","FrontR"]:
		var sx := -1 if limb.ends_with("L") else 1
		var back: bool = limb.begins_with("Back")
		var leg := joint(torso,limb,Vector2(sx*(17 if back else 9),6 if back else 13),13)
		joint(leg,"Foot",Vector2(sx*3,9),13)
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
		push_error("SPACE CUTTER BUILD FAIL: opaque weighted skin")
		return
	super._ready()
func _build_clips() -> void:
	var library := AnimationLibrary.new()
	var idle := _new_clip(1.7,true)
	_keys(idle,TORSO+":position",[0,0.85,1.7],[Vector2(0,-7),Vector2(0,-8),Vector2(0,-7)])
	_rotation_keys(idle,"/Compass/Needle",[0,0.85,1.7],[0,16,0])
	_rotation_keys(idle,"/TailFin",[0,0.85,1.7],[0,-5,0])
	library.add_animation("idle",idle)
	var walk := _new_clip(0.76,true)
	var gait := [0,0.19,0.38,0.57,0.76]
	_keys(walk,TORSO+":position",gait,[Vector2(0,-7),Vector2(-1,-9),Vector2(0,-7),Vector2(1,-9),Vector2(0,-7)])
	for limb in ["BackL","BackR","FrontL","FrontR"]:
		var sx := -1 if limb.ends_with("L") else 1
		var phase := -1 if limb.begins_with("Back") else 1
		_rotation_keys(walk,"/"+limb,gait,[0,sx*phase*19,0,-sx*phase*19,0])
		_rotation_keys(walk,"/"+limb+"/Foot",gait,[0,-sx*phase*10,0,sx*phase*10,0])
	_rotation_keys(walk,"/CounterArm/Weight",gait,[0,13,0,-9,0])
	_rotation_keys(walk,"/TailFin",gait,[0,-8,0,6,0])
	library.add_animation("walk",walk)
	var warning := _new_clip(0.16)
	_keys(warning,TORSO+":position",[0,0.16],[Vector2(0,-7),Vector2(-2,-5)])
	_rotation_keys(warning,"/CutArm",[0,0.16],[0,-20])
	_rotation_keys(warning,"/CutArm/Gimbal",[0,0.16],[0,-35])
	_rotation_keys(warning,"/Compass/Needle",[0,0.16],[0,-45])
	_rotation_keys(warning,"/Head",[0,0.16],[0,-7])
	library.add_animation("warning",warning)
	var attack := _new_clip(0.38)
	var release := [0,0.025,0.14,0.28,0.38]
	_keys(attack,TORSO+":position",release,[Vector2(-2,-5),Vector2(2,-8),Vector2(1,-8),Vector2(0,-7),Vector2(0,-7)])
	_rotation_keys(attack,"/CutArm",release,[-20,15,12,4,0])
	_rotation_keys(attack,"/CutArm/Gimbal",release,[-35,0,4,2,0])
	_rotation_keys(attack,"/CutArm/Gimbal/Tine",release,[0,12,7,2,0])
	_rotation_keys(attack,"/Compass/Needle",release,[-45,50,32,10,0])
	_rotation_keys(attack,"/CounterArm",release,[0,-16,-12,-4,0])
	_rotation_keys(attack,"/Head",release,[-7,5,3,1,0])
	library.add_animation("attack",attack)
	var hit := _new_clip(0.16)
	_rotation_keys(hit,"",[0,0.035,0.16],[0,-9,0])
	_rotation_keys(hit,"/Head",[0,0.035,0.16],[0,-10,0])
	_rotation_keys(hit,"/CounterArm/Weight",[0,0.035,0.16],[0,18,0])
	library.add_animation("hit",hit)
	var death := _new_clip(0.60)
	_keys(death,TORSO+":position",[0,0.22,0.60],[Vector2(0,-7),Vector2(0,0),Vector2(0,7)])
	_rotation_keys(death,"",[0,0.22,0.60],[0,-24,-70])
	_rotation_keys(death,"/CutArm",[0,0.60],[0,-55])
	_rotation_keys(death,"/Head",[0,0.60],[0,-18])
	_rotation_keys(death,"/TailFin",[0,0.60],[0,32])
	_rotation_keys(death,"/FrontR",[0,0.60],[0,25])
	library.add_animation("death",death)
	player.add_animation_library("",library)
