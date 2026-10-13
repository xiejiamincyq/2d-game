extends "res://scenes/art/technical/SporelingShapes.gd"
## Only opaque polygon assembly shared. All hood/coat/gun geometry original.
const SALT := Color("92b5ac")
const COAT := Color("4d6259")
const COPPER := Color("ac845d")
func make() -> Array[Dictionary]:
	patches.clear()
	patch("Torso/Scarf",[-11,-9, -4,-12, 3,-5, 6,10, -2,22, -10,18, -14,3],COAT)
	patch("Torso/Scarf",[-8,0, -2,-1, 2,11, -3,18, -8,14],SALT,false)
	for side in ["L","R"]:
		var leg: String = "Torso/Leg"+side
		var arm: String = "Torso/Arm"+side
		patch(leg,[-3,-2, 3,-2, 4,7, -3,9],COAT)
		patch(leg+"/Shin"+side,[-3,-2, 3,-2, 3,8, -3,8],PAPER)
		patch(leg+"/Shin"+side+"/Foot"+side,[-4,-2, 5,-2, 9,2, 8,6, -5,6],COAT)
		patch(arm,[-4,-2, 4,-2, 5,8, -3,9],COAT)
		patch(arm+"/Forearm"+side,[-3,-2, 3,-2, 4,7, -3,8],SALT)
		patch(arm+"/Forearm"+side+"/Hand"+side,[-4,-2, 3,-2, 5,2, 3,6, -3,6],PAPER)
	patch("Torso",[-10,-10, 8,-11, 13,-3, 11,11, 3,17, -10,13, -13,0],COAT)
	patch("Torso",[-7,-8, 2,-8, 7,-2, 6,10, 1,14, -6,9],SALT)
	patch("Torso",[4,-7, 8,-6, 10,10, 7,13],PAPER,false)
	patch("Torso",[-9,6, 10,4, 10,8, -8,10],COPPER)
	patch("Torso",[-6,0, -3,-3, 1,-1, 0,3, -4,4],PAPER,false)
	var head := "Torso/Head"
	# Tall soft hood, open face, staggered salt plates; no mushroom/ram-mask reuse.
	patch(head,[-15,-10, -12,-21, -2,-27, 10,-22, 17,-11, 17,8, 9,14, -10,12, -16,2],COAT)
	patch(head,[-12,-14, -8,-21, -1,-24, 7,-21, 10,-13, 4,-8, -7,-9],SALT,false)
	patch(head,[-10,-7, 10,-7, 13,0, 9,10, -6,11, -12,3],PAPER)
	patch(head,[-8,-2, -2,-3, 0,1, -5,3, -9,1],INK,false)
	patch(head,[3,-2, 9,-3, 11,0, 7,2, 3,1],INK,false)
	patch(head,[-4,5, 9,3, 11,7, 5,12, -6,10],SALT)
	patch(head,[-14,-11, -9,-13, -7,-6, -12,-3],COPPER)
	var gun := "Torso/ArmR/ForearmR/HandR/NeedleGun"
	patch(gun,[-6,-4, 4,-6, 10,-4, 22,-4, 24,-1, 23,3, 9,3, 4,7, -4,6, -8,2],COAT)
	patch(gun,[5,-3, 22,-3, 23,0, 21,2, 5,2],COPPER)
	patch(gun,[21,-4, 26,-4, 26,3, 21,3],SALT)
	patch(gun,[-5,-2, 3,-4, 7,-2, 5,2, -4,3],PAPER,false)
	patch(gun,[9,-7, 15,-7, 15,-4, 9,-4],SALT)
	return patches
