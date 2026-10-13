extends "res://scenes/art/technical/SporelingShapes.gd"
## Original split-cloak shade. Helpers only; no reused mushroom/bell geometry.
const CLOTH := Color("78677f")
const FOLD := Color("a296ac")
const BOOT := Color("625e6c")
const BONE := Color("dfd5bf")
func make() -> Array[Dictionary]:
	patches.clear()
	for side in ["L","R"]:
		var sx := -1 if side=="L" else 1
		var cape: String = "Torso/Cape"+side
		patch(cape,[-6,-3, 5,-4, 10,6, 9,17, 3,21, -7,13],CLOTH)
		patch(cape+"/Fold"+side,[-7,-3, 4,-5, 9,3, 8,13, 2,10, -1,18, -5,9, -9,12],FOLD)
		patch(cape+"/Fold"+side,[-4,0, 0,-1, 3,9, -1,12],CLOTH,false)
		var leg: String = "Torso/Leg"+side
		patch(leg,[-3,-2, 3,-2, 4,12, -4,13],BONE)
		patch(leg+"/Foot"+side,[-4,-2, 4,-2, 7,4, 5,7, -5,7],BOOT)
		var arm: String = "Torso/Arm"+side
		patch(arm,[-4,-3, 4,-3, 5,8, 3,12, -4,10],CLOTH)
		patch(arm+"/Hook"+side,[-3*sx,-3, 3*sx,-3, 3*sx,5, sx*9,8, sx*10,3, sx*14,2, sx*14,10, sx*8,15, -3*sx,9],BONE)
	patch("Torso",[-10,-15, 8,-16, 14,-9, 13,8, 7,16, -9,15, -15,5, -14,-6],CLOTH)
	patch("Torso",[-4,-10, 4,-12, 8,-5, 5,9, -4,10, -8,3],FOLD,false)
	patch("Torso/Collar",[-17,-4, -8,-9, 5,-8, 17,-3, 11,4, 0,7, -14,3],BOOT)
	patch("Torso/Collar",[-10,-2, 0,2, 10,-2, 7,3, 0,5, -7,2],BONE,false)
	patch("Torso/Charm",[-2,-2, 2,-2, 2,9, -2,9],BOOT)
	patch("Torso/Charm/Pendant",[-4,-2, 2,-4, 6,0, 4,7, -2,9, -5,4],BONE)
	patch("Torso/Charm/Pendant",[-1,1, 2,0, 3,4, 0,6, -2,3],CLOTH,false)
	var head := "Torso/Head"
	patch(head,[-17,-3, -12,-15, -3,-23, 11,-17, 16,-6, 18,7, 8,14, -7,13, -18,7],CLOTH)
	patch(head,[-11,-8, -2,-17, 6,-12, 9,-4, 4,-6, -3,-11],FOLD,false)
	patch(head+"/Mask",[-11,-4, -4,-8, 7,-5, 11,2, 6,10, -6,9, -12,3],INK)
	patch(head+"/Mask",[-7,0, -3,-1, -1,2, -4,3, -7,2],BONE,false)
	patch(head+"/Mask",[3,-1, 7,0, 7,3, 4,2],FOLD,false)
	return patches
