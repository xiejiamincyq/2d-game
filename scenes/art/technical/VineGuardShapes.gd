extends "res://scenes/art/technical/SporelingShapes.gd"
## Original nursery sovereign. Shared patch assembler only; no borrowed geometry.
const BARK := Color("755c42")
const LEAF := Color("42634e")
const LICHEN := Color("839965")
const SEED := Color("d48b58")
func make() -> Array[Dictionary]:
	patches.clear()
	for side in ["L","R"]:
		var vine: String = "Torso/Vine"+side
		patch(vine,[-7,-5,5,-4,8,15,3,30,-6,28,-10,12],LEAF)
		patch(vine,[-3,0,0,0,3,19,0,23,-3,17],LICHEN,false)
		patch(vine+"/Tip"+side,[-5,-4,5,-4,8,12,3,24,10,31,6,35,-3,29,-8,13],LEAF)
		patch(vine+"/Tip"+side,[-2,14,3,13,4,19,-1,23,-4,20],SEED)
		var leg: String = "Torso/Leg"+side
		patch(leg,[-10,-4,10,-4,12,14,5,22,-9,19,-13,7],BARK)
		patch(leg,[0,0,5,-1,6,14,2,17,-1,13],PAPER,false)
		patch(leg+"/Shin"+side,[-8,-4,8,-3,10,13,3,20,-9,17,-12,4],LEAF)
		patch(leg+"/Shin"+side+"/Foot"+side,[-11,-4,7,-4,18,3,18,8,9,9,0,5,-8,10,-16,7,-17,2],BARK)
		var shoulder: String = "Torso/Shoulder"+side
		var arm: String = shoulder+"/Arm"+side
		patch(shoulder,[-16,-8,-9,-19,7,-19,18,-8,15,10,2,16,-13,10],LEAF)
		patch(shoulder,[-10,-9,0,-14,10,-8,6,3,-4,4],LICHEN)
		patch(arm,[-9,-4,8,-4,13,14,6,23,-10,19,-14,4],BARK)
		patch(arm,[-7,0,-2,-1,1,11,-4,15,-8,10],PAPER,false)
		var forearm: String = arm+"/Forearm"+side
		patch(forearm,[-9,-4,9,-5,12,13,6,23,-6,24,-13,10],BARK)
		patch(forearm,[-9,3,9,1,11,8,-8,11],LEAF)
		patch(forearm+"/Hand"+side,[-10,-5,8,-5,14,3,16,13,11,19,6,13,3,22,-2,21,-5,13,-12,17,-16,12,-13,2],BARK)
		patch(forearm+"/Hand"+side,[-7,0,5,-1,10,5,6,10,-4,9],LICHEN)
	patch("Torso",[-28,-25,12,-29,30,-18,35,9,24,31,2,38,-27,31,-38,12,-36,-10],LEAF)
	patch("Torso",[-21,-19,-4,-25,14,-18,18,9,8,26,-15,24,-25,7],BARK)
	patch("Torso",[-4,-15,8,-12,13,0,8,17,-1,22,-10,13,-11,-1],PAPER)
	patch("Torso",[-2,-6,5,-4,7,3,4,11,-3,13,-7,6,-6,-1],SEED)
	patch("Torso",[-32,17,-13,20,5,17,27,11,25,18,8,24,-14,27,-31,24],LICHEN)
	patch("Torso",[-22,-4,-17,-7,-13,-3,-14,4,-19,6,-24,2],SEED)
	var head := "Torso/Head"
	patch(head,[-27,-19,-16,-30,5,-31,24,-22,30,-3,23,21,3,28,-20,20,-31,3],BARK)
	patch(head,[-26,-7,-18,-18,-5,-20,6,-14,9,3,3,21,-13,20,-24,10],PAPER)
	var mask := head+"/Mask"
	patch(mask,[-24,-14,-8,-20,11,-18,25,-8,23,12,6,24,-10,20,-24,6],PAPER)
	patch(mask,[-20,-5,-10,-9,-3,-5,-6,2,-17,3],INK,false)
	patch(mask,[5,-8,15,-9,21,-4,18,2,7,2],INK,false)
	patch(mask,[-14,-3,-10,-4,-9,-1,-13,0],SEED,false)
	patch(mask,[10,-5,14,-5,15,-2,11,-2],SEED,false)
	patch(mask,[-4,0,1,-2,5,4,2,9,-2,7],BARK,false)
	patch(mask,[-12,12,7,10,13,14,1,18,-10,17],BARK)
	patch(mask,[-14,-16,-9,-17,-7,-11,-11,-6,-10,5,-15,7,-15,-2,-11,-8],BARK,false)
	var crown := head+"/Crown"
	patch(crown,[-29,5,-35,-6,-32,-23,-24,-14,-21,-29,-17,-40,-10,-30,-8,-17,0,-31,6,-47,13,-39,15,-20,25,-34,31,-37,29,-19,34,-10,27,6,4,14,-19,11],LEAF)
	patch(crown,[-26,-5,-23,-14,-18,-10,-15,3,-5,6,9,2,20,-10,23,-6,20,6,5,11,-16,8],LICHEN)
	patch(crown,[1,-29,6,-37,11,-32,12,-24,7,-19,2,-23],SEED)
	patch(crown,[-20,-25,-17,-32,-13,-27,-13,-20,-17,-17,-21,-20],PAPER)
	patch(crown,[23,-26,27,-31,29,-28,27,-21,23,-18,20,-22],PAPER)
	return patches
