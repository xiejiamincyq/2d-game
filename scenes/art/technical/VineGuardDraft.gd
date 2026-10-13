extends "res://scenes/art/technical/NativeMonsterSample.gd"
const SkinBuilder = preload("res://scenes/art/technical/NativePaperSkin.gd")
const Shapes = preload("res://scenes/art/technical/VineGuardShapes.gd")
## First-chapter original anatomy; five non-attack clips only.
func _init() -> void:
	visual_bounds_padding = 16
	var facing := Node2D.new()
	facing.name = "Facing"
	add_child(facing)
	var rig := Skeleton2D.new()
	rig.name = "Skeleton2D"
	facing.add_child(rig)
	var torso := joint(rig,"Torso",Vector2(0,-14),30)
	for side in ["L","R"]:
		var sign_x := -1 if side=="L" else 1
		var vine := joint(torso,"Vine"+side,Vector2(sign_x*32,2),30)
		joint(vine,"Tip"+side,Vector2(0,28),28)
		var leg := joint(torso,"Leg"+side,Vector2(sign_x*15,24),16)
		var shin := joint(leg,"Shin"+side,Vector2(0,15),16)
		joint(shin,"Foot"+side,Vector2(0,16),17)
		var shoulder := joint(torso,"Shoulder"+side,Vector2(sign_x*36,-15),15)
		var arm := joint(shoulder,"Arm"+side,Vector2(sign_x*5,10),22)
		var forearm := joint(arm,"Forearm"+side,Vector2(0,19),23)
		var hand := joint(forearm,"Hand"+side,Vector2(0,20),20)
		marker(hand,"VineOrigin",Vector2(0,19))
	var head := joint(torso,"Head",Vector2(0,-37),26)
	joint(head,"Mask",Vector2(1,0),22)
	var crown := joint(head,"Crown",Vector2(0,-19),33)
	marker(crown,"SeedOrigin",Vector2(7,-33))
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
	var node := Marker2D.new()
	node.name = marker_name
	node.position = at
	parent.add_child(node)
func _ready() -> void:
	if not $Facing/Skin.build(skeleton,Shapes.new().make()):
		push_error("VINE BUILD FAIL: original weighted skin")
		return
	super._ready()
func _build_clips() -> void:
	var library := AnimationLibrary.new()
	var idle := _new_clip(2.1,true)
	_keys(idle,TORSO+":position",[0,1.05,2.1],[Vector2(0,-14),Vector2(0,-16),Vector2(0,-14)])
	_rotation_keys(idle,"/Head",[0,1.05,2.1],[0,2,0])
	_rotation_keys(idle,"/Head/Crown",[0,0.7,1.4,2.1],[0,-3,2,0])
	_rotation_keys(idle,"/VineL",[0,1.05,2.1],[0,4,0])
	_rotation_keys(idle,"/VineR/TipR",[0,1.05,2.1],[0,-5,0])
	library.add_animation("idle",idle)
	var walk := _new_clip(1.2,true)
	var steps := [0,0.3,0.6,0.9,1.2]
	_keys(walk,TORSO+":position",steps,[Vector2(0,-14),Vector2(2,-17),Vector2(0,-14),Vector2(-2,-17),Vector2(0,-14)])
	_rotation_keys(walk,"",steps,[0,2,0,-2,0])
	_rotation_keys(walk,"/Head",steps,[0,-3,0,3,0])
	_rotation_keys(walk,"/Head/Crown",steps,[0,4,0,-4,0])
	_rotation_keys(walk,"/LegL",steps,[0,-12,0,12,0])
	_rotation_keys(walk,"/LegR",steps,[0,12,0,-12,0])
	_rotation_keys(walk,"/LegL/ShinL",steps,[0,18,0,-8,0])
	_rotation_keys(walk,"/LegR/ShinR",steps,[0,-8,0,18,0])
	_rotation_keys(walk,"/LegL/ShinL/FootL",steps,[0,-9,0,4,0])
	_rotation_keys(walk,"/LegR/ShinR/FootR",steps,[0,4,0,-9,0])
	_rotation_keys(walk,"/ShoulderL",steps,[0,4,0,-4,0])
	_rotation_keys(walk,"/ShoulderR",steps,[0,-4,0,4,0])
	_rotation_keys(walk,"/ShoulderL/ArmL/ForearmL",steps,[0,-3,0,3,0])
	_rotation_keys(walk,"/ShoulderR/ArmR/ForearmR",steps,[0,3,0,-3,0])
	_rotation_keys(walk,"/VineL",steps,[0,-6,0,6,0])
	_rotation_keys(walk,"/VineL/TipL",steps,[0,9,0,-9,0])
	_rotation_keys(walk,"/VineR",steps,[0,6,0,-6,0])
	_rotation_keys(walk,"/VineR/TipR",steps,[0,-9,0,9,0])
	library.add_animation("walk",walk)
	var hit := _new_clip(0.24)
	_rotation_keys(hit,"",[0,0.05,0.24],[0,-4,0])
	_rotation_keys(hit,"/Head/Mask",[0,0.05,0.24],[0,7,0])
	_rotation_keys(hit,"/Head/Crown",[0,0.07,0.24],[0,-7,0])
	_rotation_keys(hit,"/VineL/TipL",[0,0.08,0.24],[0,12,0])
	library.add_animation("hit",hit)
	var entrance := _new_clip(1.4)
	_keys(entrance,TORSO+":position",[0,0.55,1.05,1.4],[Vector2(0,-6),Vector2(0,-11),Vector2(0,-16),Vector2(0,-14)])
	_rotation_keys(entrance,"/Head",[0,0.8,1.4],[12,-2,0])
	_rotation_keys(entrance,"/Head/Crown",[0,0.7,1.4],[-12,3,0])
	_rotation_keys(entrance,"/VineL",[0,0.75,1.4],[12,-3,0])
	_rotation_keys(entrance,"/VineR",[0,0.75,1.4],[-12,3,0])
	_rotation_keys(entrance,"/LegL/ShinL",[0,1.4],[14,0])
	_rotation_keys(entrance,"/LegR/ShinR",[0,1.4],[14,0])
	library.add_animation("entrance",entrance)
	var death := _new_clip(0.9)
	_keys(death,TORSO+":position",[0,0.35,0.9],[Vector2(0,-14),Vector2(0,4),Vector2(0,17)])
	_rotation_keys(death,"",[0,0.35,0.9],[0,24,76])
	_rotation_keys(death,"/Head",[0,0.9],[0,13])
	_rotation_keys(death,"/Head/Mask",[0,0.9],[0,-14])
	_rotation_keys(death,"/Head/Crown",[0,0.9],[0,19])
	_rotation_keys(death,"/ShoulderL",[0,0.9],[0,-17])
	_rotation_keys(death,"/ShoulderR",[0,0.9],[0,18])
	_rotation_keys(death,"/VineL/TipL",[0,0.9],[0,28])
	_rotation_keys(death,"/VineR/TipR",[0,0.9],[0,-22])
	library.add_animation("death",death)
	player.add_animation_library("",library)
