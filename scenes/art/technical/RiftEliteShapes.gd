extends "res://scenes/art/technical/SporelingShapes.gd"
## Original stepped armor and twin split emitters; helpers only, no reused body.
const ARMOR := Color("809ca3")
const PLUM := Color("867b94")
const BRASS := Color("b4a28b")
const LIGHT := Color("d6d7c7")
func make() -> Array[Dictionary]:
	patches.clear()
	patch("Torso/Halo",[-17,-5, -7,-11, 8,-10, 18,-3, 16,5, 6,9, -9,8, -18,2],PLUM)
	patch("Torso/Halo",[-11,-3, 0,-7, 12,-2, 9,3, -2,5, -12,1],INK,false)
	for side in ["L","R"]:
		var sx := -1 if side=="L" else 1
		var prism: String = "Torso/Halo/Prism"+side
		patch(prism,[-3*sx,1, 1*sx,-14, 7*sx,-5, 4*sx,10],BRASS)
		patch(prism,[0,0, 2*sx,-9, 4*sx,-3, 2*sx,6],LIGHT,false)
		var leg: String = "Torso/Leg"+side
		patch(leg,[-4,-2, 4,-2, 5,8, 2,13, -4,11],PLUM)
		patch(leg+"/Shin"+side,[-4,-2, 4,-2, 5,9, 0,13, -5,8],ARMOR)
		patch(leg+"/Shin"+side,[0,0, 3,1, 2,8, 0,9],LIGHT,false)
		patch(leg+"/Shin"+side+"/Foot"+side,[-5*sx,-2, 4*sx,-2, 7*sx,3, 7*sx,6, -5*sx,6],BRASS)
	patch("Torso",[-13,-15, 8,-17, 15,-10, 13,6, 7,15, -9,14, -15,3],ARMOR)
	patch("Torso",[-11,-11, 0,-15, 10,-12, 8,-7, 0,-5, -9,-7],LIGHT,false)
	patch("Torso",[-10,2, 0,6, 9,1, 6,11, -6,12],PLUM,false)
	patch("Torso/Core",[-8,-3, 0,-9, 9,-2, 7,7, -1,11, -8,5],INK)
	patch("Torso/Core",[-5,-1, 0,-5, 6,-1, 4,5, -1,7, -5,3],BRASS,false)
	patch("Torso/Core/Lens",[-3,0, 0,-3, 4,0, 0,5],LIGHT,false)
	for side in ["L","R"]:
		var sx := -1 if side=="L" else 1
		var arm: String = "Torso/Arm"+side
		patch(arm,[-6,-4, 0,-7, 7,-3, 5,9, -5,10],ARMOR)
		patch(arm,[-3,-3, 2,-4, 4,2, -3,3],LIGHT,false)
		patch(arm+"/Forearm"+side,[-4,-2, 4,-3, 6,5, 4,12, -4,10],PLUM)
		patch(arm+"/Forearm"+side,[0,0, 3,1, 4,7, 1,9],BRASS,false)
		var blade: String = arm+"/Forearm"+side+"/Blade"+side
		patch(blade,[-4*sx,-2, 3*sx,-3, 12*sx,1, 19*sx,8, 15*sx,12, 8*sx,6, -3*sx,6],BRASS)
		patch(blade,[4*sx,0, 10*sx,2, 17*sx,8, 13*sx,9, 8*sx,5, 4*sx,4],LIGHT,false)
		patch(blade,[-2*sx,0, 2*sx,0, 3*sx,4, -2*sx,4],PLUM,false)
	var head := "Torso/Head"
	patch(head,[-16,-2, -12,-14, -6,-14, -6,-20, 5,-20, 5,-15, 12,-13, 17,-2, 13,11, -12,11],ARMOR)
	patch(head,[-10,-11, -4,-12, -4,-16, 2,-16, 2,-11, 9,-9, 5,-6, -8,-6],LIGHT,false)
	patch(head+"/Mask",[-12,-4, 10,-5, 13,2, 7,10, -8,10, -13,3],INK)
	patch(head+"/Mask",[-8,-1, -3,-2, -1,1, -5,3, -8,2],BRASS,false)
	patch(head+"/Mask",[2,-2, 8,-1, 8,2, 4,3],LIGHT,false)
	patch(head+"/Mask",[-4,6, 4,6, 2,8, -2,8],PLUM,false)
	return patches
