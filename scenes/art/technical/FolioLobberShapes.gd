extends "res://scenes/art/technical/SporelingShapes.gd"
## Original pouch courier; shared polygon assembly only, no reused character art.
const CLOTH := Color("726d83")
const LEATHER := Color("8b775b")
const SPORE := Color("b0ad79")
func make() -> Array[Dictionary]:
	patches.clear()
	patch("Torso/Satchel",[-14,-12, -6,-17, 10,-12, 15,0, 10,16, -7,20, -17,10, -19,-2],LEATHER)
	patch("Torso/Satchel",[-12,-7, -4,-11, 8,-7, 10,5, 5,12, -10,13, -14,4],CLOTH)
	patch("Torso/Satchel",[-11,1, 9,0, 9,5, -10,6],PAPER)
	for side in ["L","R"]:
		var leg: String = "Torso/Leg"+side
		var arm: String = "Torso/Arm"+side
		patch(leg,[-4,-2, 4,-2, 4,8, -4,9],CLOTH)
		patch(leg+"/Shin"+side,[-3,-2, 3,-2, 4,8, -3,9],LEATHER)
		patch(leg+"/Shin"+side+"/Foot"+side,[-5,-2, 5,-2, 8,2, 8,6, -5,6],LEATHER)
		patch(arm,[-4,-2, 4,-2, 5,8, -4,9],CLOTH)
		patch(arm+"/Forearm"+side,[-4,-2, 3,-2, 4,8, -4,8],PAPER)
		patch(arm+"/Forearm"+side+"/Hand"+side,[-4,-2, 4,-2, 5,4, 0,7, -5,4],LEATHER)
	patch("Torso",[-12,-10, 9,-11, 14,-3, 14,12, 5,17, -10,15, -15,4],CLOTH)
	patch("Torso",[-4,-8, 5,-8, 10,-1, 9,11, 2,14, -4,9],PAPER)
	patch("Torso",[-11,4, 12,3, 12,8, -10,10],LEATHER)
	patch("Torso",[-10,-5, -6,-8, 3,12, -1,14],LEATHER)
	var head := "Torso/Head"
	patch(head,[-14,-10, -10,-20, 3,-23, 14,-16, 18,-4, 15,10, 3,15, -11,11, -16,0],PAPER)
	patch(head,[-15,-9, -10,-20, 2,-23, 14,-17, 16,-10, 5,-8, -11,-5],CLOTH)
	patch(head,[-10,-15, -3,-20, 5,-18, 8,-13, -1,-11],Color("a49aaa"),false)
	patch(head,[-9,0, -3,-2, 1,1, -4,4, -10,3],INK,false)
	patch(head,[5,-1, 12,-1, 12,3, 6,4],INK,false)
	patch(head,[-5,7, 9,6, 7,12, -3,12],LEATHER)
	var payload := "Torso/ArmR/ForearmR/HandR/Payload"
	patch(payload,[-7,-8, 1,-12, 9,-7, 11,2, 6,10, -5,11, -11,3, -10,-4],SPORE)
	patch(payload,[-4,-7, 0,-9, 5,-6, 2,-2, -4,-2],PAPER,false)
	patch(payload,[-7,3, 8,2, 7,6, -6,7],LEATHER)
	return patches
