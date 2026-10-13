extends "res://scenes/art/technical/NativeMonsterSample.gd"
const SkinBuilder = preload("res://scenes/art/technical/NativePaperSkin.gd")
const Shapes = preload("res://scenes/art/technical/SporeArchivistShapes.gd")
## Independent book/umbrella-cloak anatomy, only non-attack clips.
func _init() -> void:
	visual_bounds_padding = 16
	var facing := Node2D.new()
	facing.name = "Facing"
	add_child(facing)
	var rig := Skeleton2D.new()
	rig.name = "Skeleton2D"
	facing.add_child(rig)
	var torso := joint(rig,"Torso",Vector2(0,-18),32)
	for side in ["L","R"]:
		var sign_x := -1 if side=="L" else 1
		var cloak := joint(torso,"Cloak"+side,Vector2(sign_x*28,2),32)
		joint(cloak,"Hem"+side,Vector2(0,30),17)
		var leg := joint(torso,"Leg"+side,Vector2(sign_x*15,23),15)
		var shin := joint(leg,"Shin"+side,Vector2(0,15),15)
		joint(shin,"Foot"+side,Vector2(0,15),18)
		var arm := joint(torso,"Arm"+side,Vector2(sign_x*34,-5),20)
		var forearm := joint(arm,"Forearm"+side,Vector2(sign_x*4,14),22)
		joint(forearm,"Hand"+side,Vector2(-sign_x*2,18),13)
	joint(torso,"SporeSatchel",Vector2(-40,14),30)
	marker(torso.get_node("SporeSatchel"),"ColonyOrigin",Vector2(0,11))
	var head := joint(torso,"Head",Vector2(0,-34),28)
	var cap := joint(head,"Cap",Vector2(-3,-18),60)
	marker(cap,"SporeOrigin",Vector2(0,-24))
	joint(head,"GillL",Vector2(-15,8),17)
	joint(head,"GillR",Vector2(15,8),17)
	joint(head,"Lens",Vector2(11,-1),14)
	var book := joint(torso,"Book",Vector2(0,20),36)
	joint(book,"PageL",Vector2(-1,0),34)
	joint(book,"PageR",Vector2(1,0),34)
	var spine := joint(book,"Spine",Vector2.ZERO,23)
	marker(spine,"IndexOrigin",Vector2(0,9))
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
		push_error("ARCHIVIST BUILD FAIL: original opaque weighted skin")
		return
	super._ready()
func _build_clips() -> void:
	var library := AnimationLibrary.new()
	var idle := _new_clip(2.0,true)
	_keys(idle,TORSO+":position",[0,1,2],[Vector2(0,-18),Vector2(0,-19),Vector2(0,-18)])
	_keys(idle,TORSO+"/Head/Cap:scale",[0,1,2],[Vector2.ONE,Vector2(1.015,1.025),Vector2.ONE])
	_rotation_keys(idle,"/Book/PageL",[0,1,2],[0,-3,0])
	_rotation_keys(idle,"/Book/PageR",[0,1,2],[0,3,0])
	_rotation_keys(idle,"/Book/Spine",[0,1,2],[0,2,0])
	_rotation_keys(idle,"/Head/GillL",[0,1,2],[0,-2,0])
	_rotation_keys(idle,"/Head/GillR",[0,1,2],[0,2,0])
	_rotation_keys(idle,"/SporeSatchel",[0,1,2],[0,2.5,0])
	library.add_animation("idle",idle)
	var walk := _new_clip(1.04,true)
	var gait := [0,0.26,0.52,0.78,1.04]
	_keys(walk,TORSO+":position",gait,[Vector2(0,-18),Vector2(-1,-20),Vector2(0,-18),Vector2(1,-20),Vector2(0,-18)])
	_rotation_keys(walk,"",gait,[0,-2,0,2,0])
	_rotation_keys(walk,"/LegL",gait,[0,12,0,-12,0])
	_rotation_keys(walk,"/LegR",gait,[0,-12,0,12,0])
	_rotation_keys(walk,"/LegL/ShinL",gait,[0,-8,0,17,0])
	_rotation_keys(walk,"/LegR/ShinR",gait,[0,17,0,-8,0])
	_rotation_keys(walk,"/LegL/ShinL/FootL",gait,[0,4,0,-6,0])
	_rotation_keys(walk,"/LegR/ShinR/FootR",gait,[0,-6,0,4,0])
	_rotation_keys(walk,"/CloakL",gait,[0,-3,0,3,0])
	_rotation_keys(walk,"/CloakR",gait,[0,3,0,-3,0])
	_rotation_keys(walk,"/CloakL/HemL",gait,[0,5,0,-5,0])
	_rotation_keys(walk,"/CloakR/HemR",gait,[0,-5,0,5,0])
	_rotation_keys(walk,"/Head",gait,[0,2,0,-2,0])
	_rotation_keys(walk,"/Head/Cap",gait,[0,-3,0,3,0])
	_rotation_keys(walk,"/Book",gait,[0,1.5,0,-1.5,0])
	_rotation_keys(walk,"/Book/Spine",gait,[0,4,0,-4,0])
	_rotation_keys(walk,"/SporeSatchel",gait,[0,-6,0,6,0])
	library.add_animation("walk",walk)
	var hit := _new_clip(0.23)
	_rotation_keys(hit,"",[0,0.05,0.23],[0,-3,0])
	_rotation_keys(hit,"/Head/Cap",[0,0.07,0.23],[0,5,0])
	_rotation_keys(hit,"/Head/Lens",[0,0.05,0.23],[0,-7,0])
	_rotation_keys(hit,"/Book",[0,0.06,0.23],[0,4,0])
	_rotation_keys(hit,"/Book/PageL",[0,0.07,0.23],[0,-8,0])
	_rotation_keys(hit,"/Book/PageR",[0,0.07,0.23],[0,8,0])
	library.add_animation("hit",hit)
	var entrance := _new_clip(1.4)
	_keys(entrance,TORSO+":position",[0,0.6,1.1,1.4],[Vector2(0,-10),Vector2(0,-16),Vector2(0,-20),Vector2(0,-18)])
	_rotation_keys(entrance,"/Head/Cap",[0,0.8,1.4],[-7,2,0])
	_rotation_keys(entrance,"/Book/PageL",[0,0.7,1.4],[-12,3,0])
	_rotation_keys(entrance,"/Book/PageR",[0,0.7,1.4],[12,-3,0])
	_rotation_keys(entrance,"/CloakL/HemL",[0,0.9,1.4],[8,-2,0])
	_rotation_keys(entrance,"/CloakR/HemR",[0,0.9,1.4],[-8,2,0])
	_rotation_keys(entrance,"/SporeSatchel",[0,0.8,1.4],[8,-3,0])
	library.add_animation("entrance",entrance)
	var death := _new_clip(0.96)
	_keys(death,TORSO+":position",[0,0.32,0.96],[Vector2(0,-18),Vector2(0,-3),Vector2(0,14)])
	_rotation_keys(death,"",[0,0.32,0.96],[0,-17,-38])
	_rotation_keys(death,"/Head",[0,0.96],[0,13])
	_rotation_keys(death,"/Head/Cap",[0,0.96],[0,-12])
	_rotation_keys(death,"/Head/Lens",[0,0.96],[0,-25])
	_rotation_keys(death,"/Book",[0,0.96],[0,22])
	_rotation_keys(death,"/Book/PageL",[0,0.96],[0,-38])
	_rotation_keys(death,"/Book/PageR",[0,0.96],[0,38])
	_rotation_keys(death,"/CloakL/HemL",[0,0.96],[0,19])
	_rotation_keys(death,"/CloakR/HemR",[0,0.96],[0,-13])
	_rotation_keys(death,"/SporeSatchel",[0,0.96],[0,-18])
	library.add_animation("death",death)
	player.add_animation_library("",library)
