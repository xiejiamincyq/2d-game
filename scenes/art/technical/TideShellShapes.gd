extends "res://scenes/art/technical/SporelingShapes.gd"
## Original squat estuary creature. Patch helper only; no humanoid geometry reuse.
const SHELL := Color("c4c6af")
const SLATE := Color("768b90")
const TIDE := Color("526e78")
const SALT := Color("e3d9b8")
const CORAL := Color("b98869")
func signed_patch(bone: String,coords: Array,color: Color,sign_x: int,outline := true) -> void:
	var mirrored: Array = []
	for index in coords.size():
		mirrored.append(coords[index]*sign_x if index%2==0 else coords[index])
	patch(bone,mirrored,color,outline)
func make() -> Array[Dictionary]:
	patches.clear()
	patch("Torso/Tail",[-17,-3,13,-4,21,7,12,19,0,23,-14,18,-24,8],TIDE)
	patch("Torso/Tail",[-10,2,9,1,13,7,6,12,-8,10,-15,6],SHELL)
	for leg_name in ["FL","FR","BL","BR"]:
		var sign_x := -1 if leg_name.ends_with("L") else 1
		var leg: String = "Torso/Leg"+leg_name
		signed_patch(leg,[-6,-6,13,-1,18,7,12,14,-2,10,-9,1],TIDE,sign_x)
		signed_patch(leg,[-1,-2,9,1,12,5,8,8,0,6],SHELL,sign_x)
		signed_patch(leg+"/Shin"+leg_name,[-5,-5,11,-1,17,10,9,18,-4,12,-9,1],SLATE,sign_x)
		signed_patch(leg+"/Shin"+leg_name,[0,-1,8,2,11,8,5,11,-2,7],SALT,sign_x,false)
		signed_patch(leg+"/Shin"+leg_name+"/Foot"+leg_name,[-4,-4,8,-3,18,6,14,10,2,9,-7,4],TIDE,sign_x)
	for side in ["L","R"]:
		var sign_x := -1 if side=="L" else 1
		var shoulder: String = "Torso/Shoulder"+side
		signed_patch(shoulder,[-10,-9,9,-13,18,-6,17,7,5,14,-10,9,-16,0],TIDE,sign_x)
		signed_patch(shoulder,[-7,-5,6,-8,12,-3,9,4,-3,5],SHELL,sign_x)
		signed_patch(shoulder+"/Arm"+side,[-9,-6,10,-7,17,1,15,13,3,18,-10,9,-13,0],SLATE,sign_x)
		signed_patch(shoulder+"/Arm"+side,[-5,-3,8,-4,11,2,8,7,-2,9],SALT,sign_x,false)
		var pincer: String = shoulder+"/Arm"+side+"/Pincer"+side
		# Open crescent claw with explicit negative space, not a round glove.
		signed_patch(pincer,[-15,-7,-8,-21,7,-27,21,-21,29,-11,18,-8,9,-13,2,-10,7,-1,21,1,30,-5,25,12,12,22,-4,20,-16,8,-20,0],SHELL,sign_x)
		signed_patch(pincer,[-10,-7,-5,-17,6,-21,15,-17,10,-15,2,-17,-5,-11,-4,-4,4,5,14,9,20,5,19,12,9,17,-1,14,-12,5],SLATE,sign_x,false)
		signed_patch(pincer,[-8,-13,-3,-19,4,-22,9,-21,5,-19,-2,-16],SALT,sign_x,false)
	patch("Torso",[-37,-20,-17,-32,18,-30,40,-15,45,8,28,30,-6,35,-35,23,-46,4],TIDE)
	patch("Torso",[-25,-18,-9,-27,18,-24,31,-12,34,8,20,23,-5,27,-27,17,-35,2],SLATE)
	patch("Torso",[-19,16,23,14,21,23,5,30,-15,26,-25,22],SHELL)
	var carapace := "Torso/Carapace"
	patch(carapace,[-50,-1,-42,-22,-24,-35,-4,-39,17,-35,39,-22,52,-3,45,20,24,34,-3,38,-30,30,-49,16,-55,7],SHELL)
	patch(carapace,[-44,-1,-35,-19,-21,-28,-3,-32,15,-27,33,-18,42,-1,36,17,19,27,-3,30,-25,23,-41,12],SLATE)
	patch(carapace,[-31,-4,-23,-20,-6,-26,13,-22,28,-11,32,5,21,19,1,23,-19,16],SHELL)
	patch(carapace,[-25,-3,-18,-15,-4,-20,9,-17,14,-12,5,-13,-10,-15,-17,-9,-20,1],SALT,false)
	patch(carapace,[-5,3,4,-1,14,3,20,11,10,17,0,16,-9,10],TIDE)
	patch(carapace,[0,5,6,3,13,7,11,12,3,13,-2,9],CORAL)
	patch(carapace,[-43,5,-38,1,-30,5,-29,11,-36,14,-43,11],SALT)
	patch(carapace,[32,-7,38,-6,43,1,40,7,34,6,30,0],SALT)
	var head := "Torso/Head"
	patch(head,[-22,-10,-9,-18,9,-18,24,-8,28,7,17,18,-14,19,-28,7],TIDE)
	patch(head,[-18,-7,-7,-13,7,-13,18,-5,20,6,11,13,-10,14,-20,5],SHELL)
	for side in ["L","R"]:
		var stalk: String = head+"/EyeStalk"+side
		patch(stalk,[-4,7,-5,-13,-10,-19,-7,-26,6,-27,12,-20,8,-11,5,8],TIDE)
		patch(stalk,[-7,-20,-4,-24,4,-24,8,-19,5,-14,-4,-14],SALT)
		patch(stalk,[-2,-22,3,-22,5,-18,2,-15,-3,-17],INK,false)
		patch(stalk,[-1,-21,1,-21,1,-19,-1,-19],CORAL,false)
	patch(head+"/Jaw",[-13,-4,9,-5,16,1,10,9,-9,10,-17,2],SLATE)
	patch(head+"/Jaw",[-8,-1,6,-2,10,1,5,4,-7,5,-11,2],INK,false)
	patch(head+"/Jaw",[-7,0,-3,0,-2,3,-6,3],SALT,false)
	patch(head+"/Jaw",[3,-1,7,0,6,3,2,3],SALT,false)
	return patches
