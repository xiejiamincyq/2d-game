extends "res://scenes/art/technical/SporelingShapes.gd"
## Original paper seed cluster, not the old cap or a recolored humanoid.
const HUSK := Color("b5b28a")
const SEED := Color("ded2ac")
const SPORE := Color("819278")
const ROOT := Color("586d59")
const AMBER := Color("bb9663")
func make() -> Array[Dictionary]:
	patches.clear()
	for side in ["L","R"]:
		var sx := -1 if side=="L" else 1
		var leg: String = "Torso/Leg"+side
		patch(leg,[-4,-2,3,-3,6,6,4,13,-3,12,-6,5],ROOT)
		patch(leg+"/Foot"+side,[-4,-2,4,-3,8,1,10,6,5,8,-5,6,-8,1],HUSK)
		patch(leg+"/Foot"+side,[-3,0,3,0,5,3,2,5,-3,3],SEED,false)
	for name in ["TL","TR","BL","BR"]:
		var pod: String = "Torso/Pod"+name
		patch(pod,[-10,-7,-7,-15,4,-17,12,-11,15,0,9,10,-1,12,-11,5,-14,-2],SPORE)
		patch(pod,[-7,-6,-4,-11,3,-12,8,-7,10,-1,5,5,-2,6,-8,1],HUSK)
		patch(pod,[-4,-8,-1,-10,3,-9,4,-6,1,-4,-3,-5],SEED,false)
		patch(pod+"/Tip"+name,[-5,-4,4,-4,8,1,6,7,0,9,-6,5,-8,0],ROOT)
		patch(pod+"/Tip"+name,[-2,-1,3,-1,5,2,3,5,-2,5,-4,2],SEED)
	patch("Torso",[-16,-20,-5,-25,9,-22,19,-12,20,6,12,22,-1,26,-16,19,-22,4,-22,-9],ROOT)
	patch("Torso",[-12,-16,-3,-20,8,-17,13,-8,14,6,6,18,-3,20,-13,14,-16,2,-16,-8],HUSK)
	patch("Torso/Core",[-13,-19,-2,-23,10,-19,17,-7,16,9,9,22,-2,26,-13,20,-19,5,-19,-9],SEED)
	# Split seam is a broad offset leaf fold, not a fine noise texture.
	patch("Torso/Core",[-2,-21,4,-16,-1,-9,5,-1,0,6,4,14,-3,24,-7,19,-2,11,-7,5,-3,-2,-8,-9,-4,-15],AMBER,false)
	patch("Torso/Core",[-13,-8,-8,-13,-6,-10,-9,-5,-12,2,-15,-1],Color("efe2bf"),false)
	patch("Torso/Head",[-10,-8,-3,-13,7,-11,13,-3,11,7,1,12,-10,7,-14,-1],ROOT)
	patch("Torso/Head",[-7,-5,-1,-9,6,-7,9,-1,6,5,-3,7,-10,1],HUSK)
	patch("Torso/Head/Eye",[-7,-4,5,-4,9,0,6,5,-5,5,-9,1],INK)
	patch("Torso/Head/Eye",[-4,-1,-1,-1,-1,2,-4,2],SEED,false)
	patch("Torso/Head/Eye",[2,-1,5,-1,5,2,2,2],SEED,false)
	return patches
