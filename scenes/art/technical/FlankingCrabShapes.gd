extends "res://scenes/art/technical/SporelingShapes.gd"
## New small estuary scuttler; patch/outline helper only, no Boss geometry reuse.
const SLATE := Color("7d9191")
const SALT := Color("d7ccb0")
const DEEP := Color("47656a")
const RUST := Color("bc8467")
func signed_patch(bone: String,coords: Array,color: Color,sx: int,outline := true) -> void:
	var mirrored: Array = []
	for index in coords.size(): mirrored.append(coords[index]*sx if index%2==0 else coords[index])
	patch(bone,mirrored,color,outline)
func make() -> Array[Dictionary]:
	patches.clear()
	for leg_name in ["FL","FR","BL","BR"]:
		var sx := -1 if leg_name.ends_with("L") else 1
		var leg: String = "Torso/Leg"+leg_name
		signed_patch(leg,[-4,-4,10,-3,16,3,12,8,-3,6,-6,0],DEEP,sx)
		signed_patch(leg,[0,-1,8,-1,11,3,7,5,0,3],SALT,sx,false)
		signed_patch(leg+"/Shin"+leg_name,[-4,-3,5,-2,10,8,6,14,0,11,-6,2],SLATE,sx)
		signed_patch(leg+"/Shin"+leg_name,[0,2,4,2,6,7,3,10,0,8],SALT,sx,false)
	for side in ["L","R"]:
		var sx := -1 if side=="L" else 1
		var arm: String = "Torso/Arm"+side
		signed_patch(arm,[-5,-5,8,-4,14,3,9,10,-3,7,-7,0],DEEP,sx)
		var claw: String = arm+"/Claw"+side
		signed_patch(claw,[-6,-7,2,-13,14,-14,21,-8,19,-2,12,-1,10,-6,2,-6,3,2,12,6,16,12,6,16,-5,9,-9,1],SALT,sx)
		signed_patch(claw,[-3,-5,3,-10,13,-10,17,-7,11,-5,1,-3,2,5,9,8,8,11,0,7,-5,0],SLATE,sx,false)
		signed_patch(claw+"/Jaw"+side,[-3,-3,5,-5,15,-2,21,5,18,9,12,5,6,3,2,7,-4,6],DEEP,sx)
		signed_patch(claw+"/Jaw"+side,[2,-1,7,-2,14,1,17,5,12,3,6,1,2,3],SALT,sx,false)
	patch("Torso",[-24,-14,-13,-24,9,-25,25,-16,30,-2,22,18,2,24,-22,14,-30,0],DEEP)
	patch("Torso/Shell",[-25,-12,-17,-24,0,-28,19,-23,29,-9,25,9,10,20,-11,18,-26,6,-30,-3],SALT)
	patch("Torso/Shell",[-19,-10,-12,-19,0,-23,14,-18,21,-8,19,7,7,14,-9,12,-21,3],SLATE)
	# Offset broken spiral is a bold identity cue, not fine texture.
	patch("Torso/Shell",[-13,-4,-7,-14,5,-17,13,-10,14,2,8,8,-4,8,-9,1,-5,-4,2,-5,6,-1,5,3,0,3,-2,0,-4,2,0,5,6,4,9,0,7,-7,1,-11,-6,-8,-9,-1],SALT,false)
	patch("Torso/Shell",[12,-15,17,-12,20,-7,16,-7,12,-11],RUST,false)
	patch("Torso/Head",[-14,-6,-7,-12,9,-11,17,-4,14,8,2,12,-11,8,-18,1],DEEP)
	patch("Torso/Head",[-10,-3,-4,-7,7,-6,11,-1,8,5,-4,6,-12,1],SALT)
	for side in ["L","R"]:
		var eye: String = "Torso/Head/Eye"+side
		patch(eye,[-3,5,-4,-7,-7,-10,-5,-16,3,-18,9,-13,8,-7,4,-4,3,6],DEEP)
		patch(eye,[-4,-11,-3,-14,3,-15,6,-12,5,-8,0,-7,-4,-9],SALT)
		patch(eye,[0,-13,3,-13,4,-10,2,-8,-1,-10],INK,false)
	patch("Torso/Head/Mandible",[-7,-2,5,-3,9,2,5,6,-6,5,-10,1],RUST)
	patch("Torso/Head/Mandible",[-4,0,4,0,4,2,-4,2],INK,false)
	return patches
