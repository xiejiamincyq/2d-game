extends "res://scenes/art/technical/SporelingShapes.gd"
## Original split-rim observatory tripod; no external/traced character geometry.
const FRAME := Color("8e8d9f")
const FRAME_SHADE := Color("62697e")
const PLATE := Color("c7bdab")
const COOL := Color("789797")
const GLASS := Color("435e6b")
const RETICLE := Color("b78b77")
func signed_patch(bone: String,coords: Array,color: Color,sign_x: int,outline := true) -> void:
	var mirrored: Array = []
	for index in coords.size():
		mirrored.append(coords[index]*sign_x if index%2==0 else coords[index])
	patch(bone,mirrored,color,outline)
func arc_patch(bone: String,angle: float,inner: float,outer: float,color: Color,outline := true) -> void:
	var coords: Array = []
	for offset in [-25.0,0.0,25.0]:
		var point := Vector2.from_angle(deg_to_rad(angle+offset))*outer
		coords.append_array([point.x,point.y])
	for offset in [25.0,0.0,-25.0]:
		var point := Vector2.from_angle(deg_to_rad(angle+offset))*inner
		coords.append_array([point.x,point.y])
	patch(bone,coords,color,outline)
func make() -> Array[Dictionary]:
	patches.clear()
	for leg_name in ["B","L","R"]:
		var sign_x := -1 if leg_name=="L" else 1
		var leg: String = "Torso/Leg"+leg_name
		signed_patch(leg,[-9,-7,9,-8,17,2,17,15,6,22,-8,16,-13,2],FRAME_SHADE,sign_x)
		signed_patch(leg,[-4,-3,5,-4,10,4,8,12,-1,14,-7,6],PLATE,sign_x,false)
		signed_patch(leg+"/Shin"+leg_name,[-8,-6,8,-7,13,2,11,14,4,21,-8,17,-12,4],FRAME,sign_x)
		signed_patch(leg+"/Shin"+leg_name,[-4,-1,4,-2,7,4,4,12,-5,11],FRAME_SHADE,sign_x,false)
		signed_patch(leg+"/Shin"+leg_name+"/Foot"+leg_name,[-11,-5,8,-6,20,2,18,10,3,13,-12,10,-16,3],PLATE,sign_x)
		signed_patch(leg+"/Shin"+leg_name+"/Foot"+leg_name,[-8,0,6,-1,13,3,9,7,-6,6],COOL,sign_x,false)
	patch("Torso/Keel",[-16,-4,15,-5,22,9,16,24,-15,25,-22,10],FRAME_SHADE)
	patch("Torso/Keel",[-9,0,8,-1,13,10,8,18,-9,19,-14,11],PLATE,false)
	patch("Torso/Keel/Counterweight",[-13,-5,10,-7,19,2,15,14,0,21,-15,14,-19,3],FRAME)
	patch("Torso/Keel/Counterweight",[-7,-1,6,-2,11,4,7,10,-6,11,-11,5],RETICLE,false)
	for side in ["L","R"]:
		var sign_x := -1 if side=="L" else 1
		var arm: String = "Torso/ScopeArm"+side
		signed_patch(arm,[-7,-7,9,-8,20,-3,23,7,12,14,-3,10,-10,2],FRAME_SHADE,sign_x)
		signed_patch(arm,[-2,-3,8,-4,15,0,15,5,6,8,-4,4],PLATE,sign_x,false)
		signed_patch(arm+"/Elbow"+side,[-7,-7,7,-9,18,-4,20,5,12,14,-3,12,-9,4],FRAME,sign_x)
		signed_patch(arm+"/Elbow"+side,[-3,-3,5,-4,11,0,10,7,2,9,-5,4],COOL,sign_x,false)
		var probe: String = arm+"/Elbow"+side+"/Probe"+side
		patch(probe,[-10,-14,7,-16,14,-8,14,7,5,16,-11,12,-16,1],PLATE)
		patch(probe,[-6,-9,5,-10,9,-5,9,4,3,9,-7,7,-10,0],GLASS)
		patch(probe,[-4,-6,1,-7,4,-4,1,0,-4,1,-7,-2],COOL,false)
	patch("Torso",[-25,-35,22,-36,35,-20,35,10,22,29,-18,31,-34,11,-35,-17],FRAME_SHADE)
	patch("Torso",[-17,-28,14,-29,23,-17,24,6,14,21,-13,23,-24,7,-24,-12],PLATE,false)
	patch("Torso/Beacon",[-4,-6,4,-6,5,19,-5,20],FRAME)
	patch("Torso/Beacon",[-8,-10,0,-19,9,-11,10,-2,0,5,-10,-2],PLATE)
	patch("Torso/Beacon",[-3,-11,1,-14,5,-10,4,-5,-1,-3,-5,-6],RETICLE,false)
	var hub := "Torso/RingHub"
	patch(hub,[-5,-57,5,-57,8,-9,56,-5,56,5,7,9,4,57,-5,57,-9,8,-56,5,-56,-5,-9,-9],FRAME_SHADE)
	var names := ["A","B","C","D","E","F"]
	for index in names.size():
		var segment: String = hub+"/Segment"+names[index]
		var angle: float = -90.0+60.0*index
		arc_patch(segment,angle,53,67,FRAME)
		arc_patch(segment,angle,56,62,PLATE,false)
		var center := Vector2.from_angle(deg_to_rad(angle))*60
		patch(segment,[center.x-3,center.y-3,center.x+3,center.y-3,center.x+3,center.y+3,center.x-3,center.y+3],RETICLE,false)
	var lens := "Torso/Lens"
	patch(lens,[-32,-17,-18,-33,3,-37,25,-29,37,-8,36,14,21,31,-1,36,-23,28,-36,9],PLATE)
	patch(lens,[-26,-13,-14,-27,3,-30,20,-22,29,-6,28,11,16,25,-1,29,-18,22,-29,7],FRAME_SHADE)
	patch(lens,[-19,-13,-6,-22,10,-20,22,-7,21,12,8,23,-10,21,-23,8,-24,-4],GLASS,false)
	for side in ["L","R"]:
		var sign_x := -1 if side=="L" else 1
		signed_patch(lens+"/Iris"+side,[2,-23,12,-20,21,-10,23,6,14,20,4,24,-2,18,7,5,6,-9,-1,-17],FRAME,sign_x)
		signed_patch(lens+"/Iris"+side,[4,-17,10,-14,16,-5,16,6,9,13,6,17,4,12,10,2,7,-9],COOL,sign_x,false)
	patch(lens+"/Pupil",[-10,-5,-5,-11,6,-11,12,-4,10,7,3,13,-8,10,-13,2],PLATE)
	patch(lens+"/Pupil",[-6,-3,-3,-7,3,-7,7,-2,5,5,0,8,-6,5,-8,1],INK)
	patch(lens+"/Pupil",[-3,-4,1,-4,2,-1,-1,1,-4,-1],RETICLE,false)
	return patches
