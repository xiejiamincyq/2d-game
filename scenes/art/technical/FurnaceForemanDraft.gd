extends "res://scenes/art/technical/NativeMonsterSample.gd"
const SkinBuilder = preload("res://scenes/art/technical/NativePaperSkin.gd")
const Shapes = preload("res://scenes/art/technical/FurnaceForemanShapes.gd")
## Independent furnace anatomy. No attack/warning resources before all-rig gate.
func _init() -> void:
	visual_bounds_padding = 16
	var facing := Node2D.new()
	facing.name = "Facing"
	add_child(facing)
	var rig := Skeleton2D.new()
	rig.name = "Skeleton2D"
	facing.add_child(rig)
	var torso := joint(rig,"Torso",Vector2(0,-16),32)
	joint(torso,"Bellows",Vector2(-29,-2),25)
	var chimney := joint(torso,"Chimney",Vector2(-23,-28),58)
	marker(chimney,"ExhaustOrigin",Vector2(0,-64))
	for side in ["L","R"]:
		var sign_x := -1 if side=="L" else 1
		var leg := joint(torso,"Leg"+side,Vector2(sign_x*16,26),17)
		var shin := joint(leg,"Shin"+side,Vector2(0,16),18)
		joint(shin,"Foot"+side,Vector2(0,17),18)
		var shoulder := joint(torso,"Shoulder"+side,Vector2(sign_x*36,-19),16)
		var arm := joint(shoulder,"Arm"+side,Vector2(sign_x*5,11),22)
		var forearm := joint(arm,"Forearm"+side,Vector2(0,20),24)
		joint(forearm,"Hand"+side,Vector2(0,22),18)
	var chest := joint(torso,"Chest",Vector2(1,-1),25)
	var door := joint(chest,"Door",Vector2(1,1),22)
	marker(door,"CoreOrigin",Vector2(0,4))
	for side in ["L","R"]:
		var sign_x := -1 if side=="L" else 1
		var vent := joint(chest,"Vent"+side,Vector2(sign_x*29,2),13)
		marker(vent,"VentOrigin",Vector2(sign_x*10,0))
	var head := joint(torso,"Head",Vector2(7,-44),28)
	joint(head,"Visor",Vector2(0,-1),25)
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
		push_error("FURNACE BUILD FAIL: original opaque weighted skin")
		return
	super._ready()
func _build_clips() -> void:
	var library := AnimationLibrary.new()
	var idle := _new_clip(1.9,true)
	_keys(idle,TORSO+":position",[0,0.95,1.9],[Vector2(0,-16),Vector2(0,-17),Vector2(0,-16)])
	_keys(idle,TORSO+"/Bellows:scale",[0,0.95,1.9],[Vector2.ONE,Vector2(0.92,1.03),Vector2.ONE])
	_rotation_keys(idle,"/Chest",[0,0.95,1.9],[0,1.5,0])
	_rotation_keys(idle,"/Head/Visor",[0,0.95,1.9],[0,-1.5,0])
	_rotation_keys(idle,"/Chimney",[0,0.95,1.9],[0,-2,0])
	library.add_animation("idle",idle)
	var walk := _new_clip(1.12,true)
	var gait := [0,0.28,0.56,0.84,1.12]
	_keys(walk,TORSO+":position",gait,[Vector2(0,-16),Vector2(-1,-19),Vector2(0,-16),Vector2(1,-19),Vector2(0,-16)])
	_rotation_keys(walk,"",gait,[0,-2.5,0,2.5,0])
	_rotation_keys(walk,"/LegL",gait,[0,11,0,-11,0])
	_rotation_keys(walk,"/LegR",gait,[0,-11,0,11,0])
	_rotation_keys(walk,"/LegL/ShinL",gait,[0,-8,0,17,0])
	_rotation_keys(walk,"/LegR/ShinR",gait,[0,17,0,-8,0])
	_rotation_keys(walk,"/LegL/ShinL/FootL",gait,[0,4,0,-7,0])
	_rotation_keys(walk,"/LegR/ShinR/FootR",gait,[0,-7,0,4,0])
	_rotation_keys(walk,"/ShoulderL",gait,[0,-5,0,5,0])
	_rotation_keys(walk,"/ShoulderR",gait,[0,5,0,-5,0])
	_rotation_keys(walk,"/ShoulderL/ArmL/ForearmL",gait,[0,3,0,-3,0])
	_rotation_keys(walk,"/ShoulderR/ArmR/ForearmR",gait,[0,-3,0,3,0])
	_rotation_keys(walk,"/Head",gait,[0,3,0,-3,0])
	_rotation_keys(walk,"/Chimney",gait,[0,4.5,0,-4.5,0])
	_rotation_keys(walk,"/Chest/Door",gait,[0,2,0,-2,0])
	library.add_animation("walk",walk)
	var hit := _new_clip(0.22)
	_rotation_keys(hit,"",[0,0.045,0.22],[0,-3.5,0])
	_rotation_keys(hit,"/Head/Visor",[0,0.045,0.22],[0,6,0])
	_rotation_keys(hit,"/Chest/Door",[0,0.065,0.22],[0,5,0])
	_rotation_keys(hit,"/Chimney",[0,0.07,0.22],[0,-6,0])
	library.add_animation("hit",hit)
	var entrance := _new_clip(1.4)
	_keys(entrance,TORSO+":position",[0,0.6,1.1,1.4],[Vector2(0,-8),Vector2(0,-14),Vector2(0,-18),Vector2(0,-16)])
	_rotation_keys(entrance,"/Head",[0,0.9,1.4],[9,-2,0])
	_rotation_keys(entrance,"/Head/Visor",[0,0.7,1.4],[-7,1,0])
	_rotation_keys(entrance,"/Chimney",[0,0.7,1.4],[-7,3,0])
	_keys(entrance,TORSO+"/Bellows:scale",[0,0.7,1.4],[Vector2(0.85,1.05),Vector2(1.04,0.98),Vector2.ONE])
	_rotation_keys(entrance,"/LegL/ShinL",[0,1.4],[11,0])
	_rotation_keys(entrance,"/LegR/ShinR",[0,1.4],[11,0])
	library.add_animation("entrance",entrance)
	var death := _new_clip(0.94)
	_keys(death,TORSO+":position",[0,0.32,0.94],[Vector2(0,-16),Vector2(0,-2),Vector2(0,15)])
	_rotation_keys(death,"",[0,0.32,0.94],[0,-25,-78])
	_rotation_keys(death,"/Head",[0,0.94],[0,-11])
	_rotation_keys(death,"/Head/Visor",[0,0.94],[0,12])
	_rotation_keys(death,"/Chimney",[0,0.94],[0,-18])
	_rotation_keys(death,"/Chest/Door",[0,0.94],[0,14])
	_rotation_keys(death,"/ShoulderL",[0,0.94],[0,-19])
	_rotation_keys(death,"/ShoulderR",[0,0.94],[0,15])
	_keys(death,TORSO+"/Bellows:scale",[0,0.94],[Vector2.ONE,Vector2(0.8,1.02)])
	library.add_animation("death",death)
	player.add_animation_library("",library)
