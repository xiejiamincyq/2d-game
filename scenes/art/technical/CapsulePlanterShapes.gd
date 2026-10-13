extends "res://scenes/art/technical/SporelingShapes.gd"
## Original nursery mechanic silhouette; helper-only reuse, no existing geometry.
const COAT := Color("718270")
const BRASS := Color("b59767")
const BOTTLE := Color("bec7a1")
const WOOD := Color("837b61")
func make() -> Array[Dictionary]:
	patches.clear()
	patch("Torso/Rack",[-19,-21, 8,-21, 11,18, -20,18],WOOD)
	patch("Torso/Rack",[-17,-19, -13,-19, -13,17, -17,17],PAPER,false)
	for side in ["L","R"]:
		var bottle: String = "Torso/Rack/Bottle"+side
		patch(bottle,[-6,-15, -4,-19, 3,-19, 6,-14, 7,10, 3,15, -4,15, -7,10],BOTTLE)
		patch(bottle,[-4,0, 4,-1, 4,9, 1,11, -3,10],MOSS,false)
		patch(bottle,[-4,-12, -2,-14, -1,-12, -1,-3, -4,-2],PAPER,false)
		patch(bottle+"/Cap"+side,[-5,-3, 5,-3, 5,3, -5,3],BRASS)
		var leg: String = "Torso/Leg"+side
		patch(leg,[-4,-2, 4,-2, 5,8, -4,9],COAT)
		patch(leg+"/Shin"+side,[-4,-2, 4,-2, 4,8, -3,9],WOOD)
		patch(leg+"/Shin"+side+"/Foot"+side,[-5,-2, 5,-2, 9,2, 8,6, -5,6],COAT)
	patch("Torso",[-13,-11, 8,-12, 14,-5, 15,10, 8,18, -9,16, -15,6],COAT)
	patch("Torso",[-3,-9, 6,-10, 11,-4, 10,10, 4,14, -3,10],PAPER,false)
	patch("Torso",[-13,6, 14,5, 14,10, -12,12],BRASS)
	patch("Torso",[-9,-8, -6,-10, 6,13, 2,15],WOOD)
	var head := "Torso/Head"
	patch(head,[-12,-13, -4,-20, 8,-18, 16,-10, 17,3, 9,12, -4,13, -14,5, -16,-4],PAPER)
	patch(head,[-15,-4, -13,-13, -3,-20, 8,-18, 15,-10, 11,-7, -4,-9],COAT)
	patch(head,[-8,-3, 1,-4, 6,0, 3,5, -7,5],INK,false)
	patch(head,[-5,-1, -1,-1, -1,2, -5,2],BOTTLE,false)
	patch(head+"/Mask",[-3,-5, 7,-6, 12,0, 8,7, -3,7, -6,1],BRASS)
	patch(head+"/Mask",[2,-2, 6,-2, 7,3, 2,4],INK,false)
	patch("Torso/ArmL",[-4,-2, 4,-2, 5,10, -4,10],COAT)
	patch("Torso/ArmL/HandL",[-4,-2, 4,-2, 5,4, 1,7, -5,4],BRASS)
	patch("Torso/ArmR",[-3,-4, 9,-4, 12,3, 8,6, -3,4],COAT)
	patch("Torso/ArmR/ForearmR",[-3,-4, 11,-4, 13,3, 8,5, -3,4],BRASS)
	var clamp := "Torso/ArmR/ForearmR/ClampR"
	patch(clamp,[-3,-6, 7,-7, 12,-4, 12,5, 7,8, -3,6],WOOD)
	patch(clamp,[-1,-4, 8,-4, 9,-1, 1,-1],PAPER,false)
	patch(clamp,[0,2, 9,2, 8,5, 0,5],PAPER,false)
	patch(clamp+"/Payload",[-6,-6, 0,-9, 6,-5, 7,3, 1,8, -5,6, -7,0],BOTTLE)
	patch(clamp+"/Payload",[-2,-5, 1,-6, 3,-3, 0,1, -3,0],PAPER,false)
	return patches
