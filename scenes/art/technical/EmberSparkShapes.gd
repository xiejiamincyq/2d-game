extends "res://scenes/art/technical/SporelingShapes.gd"
## Only patch/outline helper shared; all furnace silhouettes are original.
const IRON := Color("687271")
const COAL := Color("444945")
const BRASS := Color("b8a178")
const EMBER := Color("cb754d")
func make() -> Array[Dictionary]:
	patches.clear()
	for side in ["L","R"]:
		var leg: String = "Torso/Leg"+side
		patch(leg,[-4,-3,4,-3,5,9,-4,10],IRON)
		patch(leg+"/Shin"+side,[-3,-2,4,-2,4,10,-3,11],BRASS)
		patch(leg+"/Shin"+side+"/Foot"+side,[-5,-2,5,-2,9,2,8,6,-6,6],COAL)
	patch("Torso/Bellows",[-12,-13,3,-16,9,-11,11,8,3,14,-12,10,-15,-2],COAL)
	for y in [-9,-2,5]:
		patch("Torso/Bellows",[-12,y,5,y-1,7,y+2,-12,y+3],BRASS)
	patch("Torso/Chimney",[-5,2,-5,-19,3,-22,8,-17,7,2],IRON)
	patch("Torso/Chimney",[-3,-17,3,-19,5,-16,4,-12,-3,-11],COAL,false)
	patch("Torso",[-15,-12,11,-13,19,-6,19,12,9,19,-9,18,-17,8],IRON)
	patch("Torso",[-11,-6,9,-7,13,-2,12,10,7,14,-8,13,-12,6],COAL)
	patch("Torso",[-7,-2,6,-3,9,1,7,8,-5,9,-8,4],EMBER)
	patch("Torso/Valve",[-5,-5,2,-7,7,-3,7,4,1,7,-6,4,-7,-1],BRASS)
	patch("Torso/Valve",[-3,-2,3,-2,3,2,-3,2],COAL,false)
	patch("Torso/ArmL",[-4,-3,4,-3,5,10,-4,11],IRON)
	patch("Torso/ArmL/HandL",[-5,-2,4,-2,6,3,3,7,-5,6],BRASS)
	patch("Torso/Head",[-14,-8,-8,-14,10,-14,16,-7,14,6,7,11,-8,9,-15,2],IRON)
	patch("Torso/Head",[-15,-7,16,-7,18,-3,-16,-2],BRASS)
	patch("Torso/Head/Visor",[-10,-4,10,-4,12,2,7,7,-8,6,-12,1],COAL)
	patch("Torso/Head/Visor",[-6,-1,5,-1,7,2,4,4,-5,3],EMBER,false)
	patch("Torso/ArmR",[-4,-5,7,-4,14,1,13,8,5,9,-4,5],BRASS)
	patch("Torso/ArmR/Nozzle",[-3,-6,15,-7,22,-4,22,5,15,8,-3,6],IRON)
	patch("Torso/ArmR/Nozzle",[14,-5,20,-3,20,4,14,6],COAL)
	patch("Torso/ArmR/Nozzle",[16,-2,19,-1,19,2,16,3],EMBER,false)
	return patches
