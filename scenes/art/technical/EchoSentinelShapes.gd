extends "res://scenes/art/technical/SporelingShapes.gd"
## Original compact bell/ear-wing monster, no copied priest or actor geometry.
const SHELL := Color("8e8797")
const FOLD := Color("b9acba")
const BRASS := Color("ad986d")
const BOOT := Color("6c7370")
func make() -> Array[Dictionary]:
	patches.clear()
	for side in ["L","R"]:
		var ear: String = "Torso/Ear"+side
		patch(ear,[-4,-4, 4,-4, 6,5, -3,7],BRASS)
		patch(ear+"/Fan"+side,[-9,-9, -3,-13, 5,-11, 9,-5, 9,5, 3,10, -5,6, -9,-2],FOLD)
		patch(ear+"/Fan"+side,[-5,-7, -2,-9, 1,5, -2,5],SHELL,false)
		patch(ear+"/Fan"+side,[2,-7, 5,-5, 5,4, 2,6],PAPER,false)
		var leg: String = "Torso/Leg"+side
		patch(leg,[-4,-2, 4,-2, 4,8, -4,9],BRASS)
		patch(leg+"/Shin"+side,[-3,-2, 3,-2, 4,8, -4,9],BOOT)
		patch(leg+"/Shin"+side+"/Foot"+side,[-5,-2, 5,-2, 8,3, 7,6, -5,6],SHELL)
		var arm: String = "Torso/Arm"+side
		patch(arm,[-3,-2, 3,-2, 4,8, -4,10],BRASS)
		patch(arm+"/Mallet"+side,[-4,-3, 4,-3, 6,3, 3,8, -4,7, -6,2],BOOT)
	# A broad rim and central pendant give a nonhuman bell silhouette.
	patch("Torso",[-13,-17, 8,-18, 16,-10, 17,4, 24,15, 22,21, 9,25, -12,24, -25,18, -24,13, -18,4, -18,-8],SHELL)
	patch("Torso",[-8,-14, 5,-15, 11,-9, 11,4, 16,15, 5,18, -7,16, -12,5, -13,-6],PAPER,false)
	patch("Torso",[-23,14, -12,18, 7,19, 22,14, 22,20, 8,24, -12,23, -24,18],BRASS)
	patch("Torso/Clapper",[-3,-2, 3,-2, 3,12, -3,12],BRASS)
	patch("Torso/Clapper/Tongue",[-5,-2, 3,-3, 7,1, 7,6, 2,10, -5,7, -7,2],BOOT)
	patch("Torso/Clapper/Tongue",[-2,1, 3,0, 4,4, 0,6, -3,3],BRASS,false)
	var head := "Torso/Head"
	patch(head,[-11,-9, -4,-13, 5,-12, 12,-7, 13,3, 6,9, -7,10, -13,3],SHELL)
	patch(head+"/Mask",[-10,-5, 8,-6, 11,-1, 9,5, -9,6, -12,1],INK)
	patch(head+"/Mask",[-6,-1, -2,-1, -2,2, -6,2],FOLD,false)
	patch(head+"/Mask",[3,-2, 7,-2, 7,1, 3,2],PAPER,false)
	patch("Torso/Crown",[-8,-4, -3,-8, 4,-7, 9,-2, 7,3, -7,3],BRASS)
	patch("Torso/Crown",[-3,-4, 2,-4, 3,0, -2,0],PAPER,false)
	return patches
