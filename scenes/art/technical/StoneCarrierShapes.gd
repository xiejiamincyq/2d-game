extends "res://scenes/art/technical/SporelingShapes.gd"
## Original rock/root porter. Inherits only opaque patch assembly, not geometry.
const STONE := Color("7c897c")
const SLATE := Color("596961")
const ROOT := Color("8d7358")
func make() -> Array[Dictionary]:
	patches.clear()
	patch("Torso/Backstone",[-18,-29,-9,-38,8,-34,20,-20,22,4,10,22,-12,18,-24,4],SLATE)
	patch("Torso/Backstone",[-16,-24,-7,-31,7,-27,12,-13,3,-4,-13,-9],STONE)
	patch("Torso/Backstone",[-9,-25,-3,-29,2,-23,-1,-14,-7,-16],PAPER,false)
	for side in ["L","R"]:
		var leg: String = "Torso/Leg"+side
		var shoulder: String = "Torso/Shoulder"+side
		var arm: String = shoulder+"/Arm"+side
		patch(leg,[-7,-2,7,-2,8,10,-6,12],ROOT)
		patch(leg+"/Shin"+side,[-6,-2,5,-3,8,8,4,12,-7,10],STONE)
		patch(leg+"/Shin"+side+"/Foot"+side,[-8,-3,5,-3,13,2,12,8,-9,8],ROOT)
		patch(leg+"/Shin"+side+"/Foot"+side,[-5,0,6,0,8,3,-6,3],PAPER,false)
		patch(shoulder,[-12,-9,-5,-15,8,-12,14,-4,10,9,-9,10,-15,2],STONE)
		patch(shoulder,[-9,-7,-3,-11,6,-8,7,-3,-5,-1],PAPER,false)
		patch(arm,[-6,-2,7,-3,9,9,5,14,-8,12],SLATE)
		patch(arm+"/Forearm"+side,[-8,-3,6,-4,10,8,5,15,-7,14,-11,5],ROOT)
		patch(arm+"/Forearm"+side,[-7,1,6,-1,8,5,-8,7],STONE)
		patch(arm+"/Forearm"+side+"/Hand"+side,[-8,-3,8,-3,13,3,11,12,0,16,-10,9,-12,2],STONE)
		patch(arm+"/Forearm"+side+"/Hand"+side,[-6,3,8,3,8,7,-7,7],PAPER,false)
	patch("Torso",[-18,-16,14,-18,25,-4,22,19,8,26,-16,23,-27,6],SLATE)
	patch("Torso",[-13,-11,10,-13,17,-3,14,14,3,20,-12,16,-18,2],STONE)
	patch("Torso",[-8,-7,4,-9,10,-2,7,8,-1,11,-9,5],PAPER)
	patch("Torso",[-19,12,20,10,19,16,-16,19],ROOT)
	patch("Torso",[-5,13,4,12,6,19,-5,20],Color("ad9873"))
	var head := "Torso/Head"
	patch(head,[-19,-17,-13,-28,3,-30,17,-22,23,-9,20,10,6,17,-12,13,-22,1],STONE)
	patch(head,[-17,-16,-10,-24,1,-26,10,-19,7,-10,-5,-8],PAPER,false)
	patch(head,[-16,-5,-7,-8,-2,-4,-5,2,-15,2],INK,false)
	patch(head,[5,-7,15,-8,19,-3,17,2,7,1],INK,false)
	patch(head,[-11,-3,-7,-4,-7,-1,-11,0],Color("c4ca96"),false)
	patch(head,[9,-4,13,-4,14,-1,10,-1],Color("c4ca96"),false)
	patch(head,[-9,7,8,6,12,10,5,14,-7,13,-12,10],ROOT)
	patch(head,[-3,-23,1,-20,-2,-12,2,-7,-2,-4,-5,-10],SLATE,false)
	return patches
