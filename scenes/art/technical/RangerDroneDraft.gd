extends "res://scenes/art/technical/NativeMonsterSample.gd"
const SkinBuilder = preload("res://scenes/art/technical/NativePaperSkin.gd")
const Shapes = preload("res://scenes/art/technical/RangerDroneShapes.gd")
func _init() -> void:
	visual_bounds_padding = 8
	var facing := Node2D.new()
	facing.name = "Facing"
	add_child(facing)
	var rig := Skeleton2D.new()
	rig.name = "Skeleton2D"
	facing.add_child(rig)
	var torso := _joint(rig,"Torso",Vector2.ZERO,8)
	var head := _joint(torso,"Head",Vector2(3,-1),6)
	_joint(head,"Lens",Vector2(2,0),3)
	for side in ["L","R"]:
		var sign_x := -1 if side=="L" else 1
		var wing := _joint(torso,"Wing"+side,Vector2(sign_x*5,-3),7)
		_joint(wing,"Tip"+side,Vector2(sign_x*5,1),6)
	_joint(torso,"Tail",Vector2(-6,4),7)
	var gun := _joint(torso,"Gun",Vector2(1,4),7)
	var nozzle := _joint(gun,"Nozzle",Vector2(4,0),6)
	var muzzle := Marker2D.new()
	muzzle.name = "Muzzle"
	muzzle.position = Vector2(6,0)
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
func _joint(parent: Node,bone_name: String,at: Vector2,length: float) -> Bone2D:
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
		push_error("DRONE BUILD FAIL: opaque weighted companion")
		return
	super._ready()
func _build_clips() -> void:
	var library := AnimationLibrary.new()
	var idle := _new_clip(1.4,true)
	_keys(idle,TORSO+":position",[0,0.7,1.4],[Vector2.ZERO,Vector2(0,-0.5),Vector2.ZERO])
	_rotation_keys(idle,"/WingL",[0,0.7,1.4],[0,4,0])
	_rotation_keys(idle,"/WingR",[0,0.7,1.4],[0,-4,0])
	_rotation_keys(idle,"/Head",[0,0.7,1.4],[0,3,0])
	library.add_animation("idle",idle)
	var walk := _new_clip(0.7,true)
	var flight := [0,0.175,0.35,0.525,0.7]
	_keys(walk,TORSO+":position",flight,[Vector2.ZERO,Vector2(0,-1),Vector2.ZERO,Vector2(0,1),Vector2.ZERO])
	_rotation_keys(walk,"/WingL",flight,[0,-22,0,18,0])
	_rotation_keys(walk,"/WingR",flight,[0,22,0,-18,0])
	_rotation_keys(walk,"/WingL/TipL",flight,[0,14,0,-12,0])
	_rotation_keys(walk,"/WingR/TipR",flight,[0,-14,0,12,0])
	_rotation_keys(walk,"/Tail",flight,[0,8,0,-8,0])
	_rotation_keys(walk,"/Head/Lens",flight,[0,-6,0,6,0])
	library.add_animation("walk",walk)
	var shoot := _new_clip(0.24,true)
	var recoil := [0,0.035,0.12,0.24]
	_keys(shoot,TORSO+"/Gun:position",recoil,[Vector2(1,4),Vector2(0,4),Vector2(0.5,4),Vector2(1,4)])
	_rotation_keys(shoot,"/WingL",recoil,[0,-9,-4,0])
	_rotation_keys(shoot,"/WingR",recoil,[0,9,4,0])
	_rotation_keys(shoot,"/Gun/Nozzle",recoil,[0,-5,-2,0])
	_rotation_keys(shoot,"/Head/Lens",recoil,[0,7,3,0])
	library.add_animation("shoot",shoot)
	var entrance := _new_clip(0.32)
	_keys(entrance,TORSO+":position",[0,0.18,0.32],[Vector2(0,3),Vector2(0,-1),Vector2.ZERO])
	_rotation_keys(entrance,"/WingL",[0,0.18,0.32],[-70,8,0])
	_rotation_keys(entrance,"/WingR",[0,0.18,0.32],[70,-8,0])
	_rotation_keys(entrance,"/WingL/TipL",[0,0.32],[55,0])
	_rotation_keys(entrance,"/WingR/TipR",[0,0.32],[-55,0])
	_rotation_keys(entrance,"/Head",[0,0.32],[-18,0])
	library.add_animation("entrance",entrance)
	var death := _new_clip(0.4)
	_keys(death,TORSO+":position",[0,0.15,0.4],[Vector2.ZERO,Vector2(0,3),Vector2(0,9)])
	_rotation_keys(death,"",[0,0.15,0.4],[0,12,60])
	_rotation_keys(death,"/WingL",[0,0.4],[0,-70])
	_rotation_keys(death,"/WingR",[0,0.4],[0,70])
	_rotation_keys(death,"/Head",[0,0.4],[0,-24])
	_rotation_keys(death,"/Tail",[0,0.4],[0,30])
	library.add_animation("death",death)
	player.add_animation_library("",library)
