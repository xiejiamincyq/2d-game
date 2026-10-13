extends "res://scenes/art/technical/NativeMonsterSample.gd"
const SkinBuilder = preload("res://scenes/art/technical/NativePaperSkin.gd")
const Shapes = preload("res://scenes/art/technical/SplittingMoteShapes.gd")
func _init() -> void:
	visual_bounds_padding = 12
	var facing := Node2D.new()
	facing.name = "Facing"
	add_child(facing)
	var rig := Skeleton2D.new()
	rig.name = "Skeleton2D"
	facing.add_child(rig)
	var torso := joint(rig,"Torso",Vector2(0,-3),26)
	for name in ["TL","TR","BL","BR"]:
		var sx := -1 if name.ends_with("L") else 1
		var top: bool = name.begins_with("T")
		var pod := joint(torso,"Pod"+name,Vector2(sx*18,-13 if top else 9),18)
		joint(pod,"Tip"+name,Vector2(sx*8,-8 if top else 6),12)
	for side in ["L","R"]:
		var sx := -1 if side=="L" else 1
		var leg := joint(torso,"Leg"+side,Vector2(sx*8,21),13)
		joint(leg,"Foot"+side,Vector2(sx*2,11),12)
	joint(torso,"Core",Vector2(0,0),27)
	var head := joint(torso,"Head",Vector2(0,-24),18)
	joint(head,"Eye",Vector2(1,0),13)
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
		push_error("MOTE BUILD FAIL: opaque weighted seed cluster")
		return
	super._ready()
func _build_clips() -> void:
	var library := AnimationLibrary.new()
	var idle := _new_clip(1.5,true)
	_keys(idle,TORSO+":position",[0,0.75,1.5],[Vector2(0,-3),Vector2(0,-4.5),Vector2(0,-3)])
	_keys(idle,TORSO+"/Core:scale",[0,0.75,1.5],[Vector2.ONE,Vector2(1.035,0.98),Vector2.ONE])
	_rotation_keys(idle,"/Head/Eye",[0,0.75,1.5],[0,4,0])
	for name in ["TL","TR","BL","BR"]:
		var sx := -1 if name.ends_with("L") else 1
		_rotation_keys(idle,"/Pod"+name,[0,0.75,1.5],[0,sx*4,0])
	library.add_animation("idle",idle)
	var walk := _new_clip(0.72,true)
	var gait := [0,0.18,0.36,0.54,0.72]
	_keys(walk,TORSO+":position",gait,[Vector2(0,-3),Vector2(1,-6),Vector2(0,-3),Vector2(-1,-6),Vector2(0,-3)])
	_rotation_keys(walk,"/LegL",gait,[0,17,0,-17,0])
	_rotation_keys(walk,"/LegR",gait,[0,-17,0,17,0])
	_rotation_keys(walk,"/LegL/FootL",gait,[0,-10,0,11,0])
	_rotation_keys(walk,"/LegR/FootR",gait,[0,11,0,-10,0])
	_rotation_keys(walk,"/Head",gait,[0,-3,0,3,0])
	for name in ["TL","TR","BL","BR"]:
		var sx := -1 if name.ends_with("L") else 1
		_rotation_keys(walk,"/Pod"+name,gait,[0,sx*9,0,-sx*9,0])
		_rotation_keys(walk,"/Pod"+name+"/Tip"+name,gait,[0,-sx*10,0,sx*10,0])
	library.add_animation("walk",walk)
	var warning := _new_clip(0.16)
	_keys(warning,TORSO+":position",[0,0.16],[Vector2(0,-3),Vector2(0,0)])
	_keys(warning,TORSO+"/Core:scale",[0,0.16],[Vector2.ONE,Vector2(0.9,1.09)])
	for name in ["TL","TR","BL","BR"]:
		var sx := -1 if name.ends_with("L") else 1
		_rotation_keys(warning,"/Pod"+name,[0,0.16],[0,-sx*13])
	library.add_animation("warning",warning)
	var attack := _new_clip(0.32)
	var pulse := [0,0.03,0.12,0.32]
	_keys(attack,TORSO+":position",pulse,[Vector2(0,0),Vector2(0,-6),Vector2(0,-4),Vector2(0,-3)])
	_keys(attack,TORSO+"/Core:scale",pulse,[Vector2(0.9,1.09),Vector2(1.14,0.92),Vector2(1.03,0.99),Vector2.ONE])
	for name in ["TL","TR","BL","BR"]:
		var sx := -1 if name.ends_with("L") else 1
		_rotation_keys(attack,"/Pod"+name,pulse,[-sx*13,sx*17,sx*5,0])
	library.add_animation("attack",attack)
	var hit := _new_clip(0.16)
	_rotation_keys(hit,"",[0,0.04,0.16],[0,9,0])
	_rotation_keys(hit,"/Core",[0,0.04,0.16],[0,-12,0])
	_rotation_keys(hit,"/Head",[0,0.04,0.16],[0,-9,0])
	library.add_animation("hit",hit)
	var death := _new_clip(0.56)
	_keys(death,TORSO+":position",[0,0.2,0.56],[Vector2(0,-3),Vector2(0,3),Vector2(0,9)])
	_rotation_keys(death,"",[0,0.2,0.56],[0,-13,-34])
	_keys(death,TORSO+"/Core:scale",[0,0.12,0.56],[Vector2.ONE,Vector2(1.15,0.86),Vector2(0.82,0.75)])
	for name in ["TL","TR","BL","BR"]:
		var sx := -1 if name.ends_with("L") else 1
		_rotation_keys(death,"/Pod"+name,[0,0.56],[0,sx*30])
		_rotation_keys(death,"/Pod"+name+"/Tip"+name,[0,0.56],[0,-sx*25])
	_rotation_keys(death,"/LegL",[0,0.56],[0,-35])
	_rotation_keys(death,"/LegR",[0,0.56],[0,35])
	library.add_animation("death",death)
	player.add_animation_library("",library)
