extends "res://scenes/art/technical/NativeMonsterSample.gd"
const SkinBuilder = preload("res://scenes/art/technical/NativePaperSkin.gd")
const Shapes = preload("res://scenes/art/technical/RiftObserverShapes.gd")
## Original tripod/aperture/split-rim anatomy; no large attack resources.
func _init() -> void:
	visual_bounds_padding = 16
	var facing := Node2D.new()
	facing.name = "Facing"
	add_child(facing)
	var rig := Skeleton2D.new()
	rig.name = "Skeleton2D"
	facing.add_child(rig)
	var torso := joint(rig,"Torso",Vector2(0,-12),36)
	for leg_name in ["L","R","B"]:
		var sign_x := -1 if leg_name=="L" else 1
		var is_back: bool = leg_name=="B"
		var leg := joint(torso,"Leg"+leg_name,Vector2(0 if is_back else sign_x*28,25),20)
		var shin := joint(leg,"Shin"+leg_name,Vector2(0 if is_back else sign_x*10,18),21)
		joint(shin,"Foot"+leg_name,Vector2(0 if is_back else sign_x*8,15),20)
	var keel := joint(torso,"Keel",Vector2(0,20),25)
	joint(keel,"Counterweight",Vector2(0,20),21)
	for side in ["L","R"]:
		var sign_x := -1 if side=="L" else 1
		var arm := joint(torso,"ScopeArm"+side,Vector2(sign_x*49,-15),23)
		var elbow := joint(arm,"Elbow"+side,Vector2(sign_x*15,0),22)
		var probe := joint(elbow,"Probe"+side,Vector2(sign_x*12,-17),20)
		marker(probe,"SensorOrigin",Vector2(0,0))
	var beacon := joint(torso,"Beacon",Vector2(0,-94),20)
	marker(beacon,"PhaseOrigin",Vector2(0,-11))
	var hub := joint(torso,"RingHub",Vector2(0,-24),67)
	for segment in ["A","B","C","D","E","F"]:
		joint(hub,"Segment"+segment,Vector2.ZERO,67)
	var lens := joint(torso,"Lens",Vector2(0,-24),37)
	joint(lens,"IrisL",Vector2(-8,0),26)
	joint(lens,"IrisR",Vector2(8,0),26)
	var pupil := joint(lens,"Pupil",Vector2.ZERO,13)
	marker(pupil,"AimOrigin",Vector2.ZERO)
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
		push_error("RIFT BUILD FAIL: original opaque weighted skin")
		return
	super._ready()
func _build_clips() -> void:
	var library := AnimationLibrary.new()
	var idle := _new_clip(2.2,true)
	_keys(idle,TORSO+":position",[0,1.1,2.2],[Vector2(0,-12),Vector2(0,-13.5),Vector2(0,-12)])
	_keys(idle,TORSO+"/Lens/IrisL:position",[0,1.1,2.2],[Vector2(-8,0),Vector2(-9.5,0),Vector2(-8,0)])
	_keys(idle,TORSO+"/Lens/IrisR:position",[0,1.1,2.2],[Vector2(8,0),Vector2(9.5,0),Vector2(8,0)])
	_rotation_keys(idle,"/RingHub/SegmentA",[0,1.1,2.2],[0,2,0])
	_rotation_keys(idle,"/RingHub/SegmentD",[0,1.1,2.2],[0,-2,0])
	_rotation_keys(idle,"/Keel/Counterweight",[0,1.1,2.2],[0,2,0])
	_rotation_keys(idle,"/ScopeArmL/ElbowL/ProbeL",[0,1.1,2.2],[0,-3,0])
	_rotation_keys(idle,"/ScopeArmR/ElbowR/ProbeR",[0,1.1,2.2],[0,3,0])
	library.add_animation("idle",idle)
	var walk := _new_clip(0.96,true)
	var gait := [0,0.24,0.48,0.72,0.96]
	_keys(walk,TORSO+":position",gait,[Vector2(0,-12),Vector2(-1,-14),Vector2(0,-12),Vector2(1,-14),Vector2(0,-12)])
	_rotation_keys(walk,"",gait,[0,-1.8,0,1.8,0])
	_rotation_keys(walk,"/LegL",gait,[0,10,0,-10,0])
	_rotation_keys(walk,"/LegR",gait,[0,-10,0,10,0])
	_rotation_keys(walk,"/LegB",gait,[0,6,0,-6,0])
	_rotation_keys(walk,"/LegL/ShinL",gait,[0,-8,0,14,0])
	_rotation_keys(walk,"/LegR/ShinR",gait,[0,14,0,-8,0])
	_rotation_keys(walk,"/LegB/ShinB",gait,[0,-12,0,12,0])
	_rotation_keys(walk,"/LegL/ShinL/FootL",gait,[0,5,0,-5,0])
	_rotation_keys(walk,"/LegR/ShinR/FootR",gait,[0,-5,0,5,0])
	_rotation_keys(walk,"/LegB/ShinB/FootB",gait,[0,4,0,-4,0])
	_rotation_keys(walk,"/ScopeArmL",gait,[0,-3,0,3,0])
	_rotation_keys(walk,"/ScopeArmR",gait,[0,3,0,-3,0])
	_rotation_keys(walk,"/ScopeArmL/ElbowL",gait,[0,4,0,-4,0])
	_rotation_keys(walk,"/ScopeArmR/ElbowR",gait,[0,-4,0,4,0])
	_rotation_keys(walk,"/ScopeArmL/ElbowL/ProbeL",gait,[0,-5,0,5,0])
	_rotation_keys(walk,"/ScopeArmR/ElbowR/ProbeR",gait,[0,5,0,-5,0])
	_rotation_keys(walk,"/Keel/Counterweight",gait,[0,5,0,-5,0])
	_rotation_keys(walk,"/Lens",gait,[0,1.5,0,-1.5,0])
	for index in 6:
		var direction := -1 if index%2 else 1
		_rotation_keys(walk,"/RingHub/Segment"+["A","B","C","D","E","F"][index],gait,[0,direction*2.3,0,-direction*2.3,0])
	_rotation_keys(walk,"/Beacon",gait,[0,-3,0,3,0])
	library.add_animation("walk",walk)
	var hit := _new_clip(0.21)
	_rotation_keys(hit,"",[0,0.045,0.21],[0,-3,0])
	_rotation_keys(hit,"/Lens",[0,0.05,0.21],[0,5,0])
	_keys(hit,TORSO+"/Lens/Pupil:position",[0,0.05,0.21],[Vector2.ZERO,Vector2(2,0),Vector2.ZERO])
	_rotation_keys(hit,"/Beacon",[0,0.06,0.21],[0,-6,0])
	_rotation_keys(hit,"/RingHub/SegmentB",[0,0.06,0.21],[0,4,0])
	_rotation_keys(hit,"/RingHub/SegmentE",[0,0.06,0.21],[0,-4,0])
	library.add_animation("hit",hit)
	var entrance := _new_clip(1.4)
	_keys(entrance,TORSO+":position",[0,0.6,1.1,1.4],[Vector2(0,-4),Vector2(0,-10),Vector2(0,-14),Vector2(0,-12)])
	_keys(entrance,TORSO+"/Lens/IrisL:position",[0,0.9,1.4],[Vector2(-12,0),Vector2(-7,0),Vector2(-8,0)])
	_keys(entrance,TORSO+"/Lens/IrisR:position",[0,0.9,1.4],[Vector2(12,0),Vector2(7,0),Vector2(8,0)])
	_rotation_keys(entrance,"/Beacon",[0,0.9,1.4],[-6,2,0])
	_rotation_keys(entrance,"/LegB/ShinB",[0,1.4],[9,0])
	_rotation_keys(entrance,"/ScopeArmL/ElbowL",[0,0.9,1.4],[-6,2,0])
	_rotation_keys(entrance,"/ScopeArmR/ElbowR",[0,0.9,1.4],[6,-2,0])
	library.add_animation("entrance",entrance)
	var death := _new_clip(1.0)
	_keys(death,TORSO+":position",[0,0.35,1],[Vector2(0,-12),Vector2(0,1),Vector2(0,16)])
	_rotation_keys(death,"",[0,0.35,1],[0,-15,-36])
	_rotation_keys(death,"/Lens",[0,1],[0,12])
	_keys(death,TORSO+"/Lens/Pupil:scale",[0,1],[Vector2.ONE,Vector2(0.65,0.65)])
	_rotation_keys(death,"/Beacon",[0,1],[0,-22])
	_rotation_keys(death,"/Keel/Counterweight",[0,1],[0,19])
	_rotation_keys(death,"/LegL/ShinL",[0,1],[0,18])
	_rotation_keys(death,"/LegR/ShinR",[0,1],[0,-15])
	_rotation_keys(death,"/LegB/ShinB",[0,1],[0,17])
	_rotation_keys(death,"/ScopeArmL",[0,1],[0,13])
	_rotation_keys(death,"/ScopeArmR",[0,1],[0,-13])
	for index in 6:
		var direction := -1 if index%2 else 1
		_rotation_keys(death,"/RingHub/Segment"+["A","B","C","D","E","F"][index],[0,1],[0,direction*7])
	library.add_animation("death",death)
	player.add_animation_library("",library)
