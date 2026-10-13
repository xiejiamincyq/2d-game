extends "res://scenes/art/technical/SporelingShapes.gd"
## Original bell/skeletal custodian. Shares polygon assembly, not character art.
const OSS := Color("d8d0b7")
const OSS_SHADE := Color("a7a28e")
const BRASS := Color("a99367")
const BRASS_LIGHT := Color("cdbb8f")
const PATINA := Color("677f76")
const IRON := Color("606c6b")
const CORD := Color("a27363")
func make() -> Array[Dictionary]:
	patches.clear()
	for side in ["L","R"]:
		var leg: String = "Torso/Leg"+side
		patch(leg,[-8,-6,8,-6,11,2,6,16,-5,18,-10,5],OSS)
		patch(leg,[-3,-1,3,-1,3,11,-3,12],OSS_SHADE,false)
		patch(leg+"/Shin"+side,[-7,-5,7,-5,8,3,5,17,-6,18,-9,4],OSS)
		patch(leg+"/Shin"+side,[-3,0,2,-1,3,12,-3,13],OSS_SHADE,false)
		patch(leg+"/Shin"+side+"/Foot"+side,[-11,-4,7,-5,15,0,17,7,8,11,-11,10,-16,4],IRON)
		patch(leg+"/Shin"+side+"/Foot"+side,[-9,0,6,-1,10,3,6,6,-8,6],OSS,false)
		var arm: String = "Torso/Arm"+side
		patch(arm,[-9,-9,8,-10,13,-1,8,17,-6,20,-11,8,-13,-1],OSS)
		patch(arm,[-4,-3,3,-3,4,13,-4,14],OSS_SHADE,false)
		patch(arm+"/Forearm"+side,[-8,-6,8,-6,11,3,6,16,-5,20,-10,10,-12,0],OSS)
		patch(arm+"/Forearm"+side,[-4,0,4,-1,5,12,-4,14],OSS_SHADE,false)
		var hand: String = arm+"/Forearm"+side+"/Hand"+side
		patch(hand,[-9,-5,7,-6,11,1,8,10,-2,13,-10,8,-12,1],OSS)
		patch(hand,[-10,-1,9,-2,10,3,-10,4],CORD,false)
		var chain: String = hand+"/Chain"+side
		patch(chain,[-3,-3,3,-3,4,26,-4,26],IRON)
		for at in [1,9,17]:
			patch(chain,[-3,at,3,at,3,at+4,-3,at+4],BRASS_LIGHT,false)
		var pendant: String = chain+"/Pendant"+side
		patch(pendant,[-7,-4,6,-5,11,1,13,14,8,19,-9,19,-14,14,-11,3],BRASS)
		patch(pendant,[-3,-1,3,-1,6,4,7,11,3,13,-5,12,-7,5],PATINA,false)
		patch(pendant,[-10,14,10,14,11,17,-10,17],OSS_SHADE,false)
		var ribs: String = "Torso/Ribs"+side
		patch(ribs,[-10,-15,8,-14,16,-4,15,17,6,23,-9,21,-16,8,-15,-6],IRON)
		patch(ribs,[-10,-9,4,-10,10,-4,9,1,-2,-2,-10,0,-13,-3],OSS)
		patch(ribs,[-11,3,2,2,10,7,9,12,-2,9,-10,12,-14,8],OSS)
		patch(ribs,[-9,16,2,13,8,15,7,19,0,22,-9,21],OSS_SHADE,false)
	patch("Torso",[-14,-43,12,-43,20,-27,17,-1,11,16,-13,16,-21,-1,-19,-27],IRON)
	for at in [-36,-23,-10,3]:
		patch("Torso",[-9,at,7,at-1,11,at+5,5,at+10,-7,at+9,-12,at+4],OSS)
		patch("Torso",[-4,at+2,4,at+2,5,at+6,-4,at+6],OSS_SHADE,false)
	var bell := "Torso/Bell"
	patch(bell,[-11,-33,11,-33,19,-23,24,-2,31,20,45,28,46,37,31,44,-29,44,-46,36,-45,27,-32,20,-25,-1,-20,-22],BRASS)
	patch(bell,[-8,-27,8,-27,14,-19,19,2,25,23,36,29,28,34,-27,34,-36,29,-26,23,-19,2,-14,-19],PATINA,false)
	patch(bell,[-12,-17,-5,-22,1,-21,-3,-4,-11,14,-19,23,-23,21,-15,-3],BRASS_LIGHT,false)
	patch(bell,[13,-13,18,3,27,26,18,27,12,14,9,-3],IRON,false)
	patch(bell,[-36,29,-21,26,20,26,36,29,36,36,21,40,-21,40,-36,36],INK)
	patch(bell,[-18,-30,18,-30,20,-24,-20,-24],BRASS_LIGHT)
	var clapper: String = bell+"/Clapper"
	patch(clapper,[-4,-6,4,-6,4,15,10,20,9,29,0,34,-10,28,-10,20,-4,15],OSS_SHADE)
	patch(clapper,[-5,20,4,19,6,25,1,29,-5,26],BRASS_LIGHT,false)
	patch(bell+"/LipL",[-44,-4,-17,-7,1,-5,1,3,-16,6,-43,3],BRASS_LIGHT)
	patch(bell+"/LipL",[-37,-1,-18,-3,-4,-1,-4,1,-17,3,-37,1],BRASS,false)
	patch(bell+"/LipR",[-1,-5,17,-7,43,-3,43,4,16,6,-1,3],BRASS_LIGHT)
	patch(bell+"/LipR",[4,-1,17,-3,37,0,37,2,17,3,4,1],BRASS,false)
	var head := "Torso/Head"
	patch(head,[-22,-15,-10,-25,10,-24,23,-13,25,5,16,18,8,20,7,25,-8,25,-10,20,-20,14,-26,1],OSS)
	patch(head,[-18,-11,-8,-18,7,-18,16,-10,17,4,10,10,-12,11,-20,0],OSS_SHADE,false)
	patch(head,[-17,-7,-8,-10,-3,-5,-5,2,-13,5,-20,1],INK)
	patch(head,[4,-6,11,-10,19,-6,20,1,13,5,5,2],INK)
	patch(head,[-14,-5,-9,-7,-6,-4,-9,0,-14,1,-16,-2],CORD,false)
	patch(head,[9,-4,13,-6,17,-3,15,1,10,1,7,-1],BRASS_LIGHT,false)
	patch(head+"/Mask",[-15,-3,14,-3,18,5,11,14,-11,14,-18,5],OSS)
	patch(head+"/Mask",[-10,1,10,1,12,6,8,9,-9,9,-12,5],INK,false)
	for at in [-7,-1,5]:
		patch(head+"/Mask",[at,2,at+2,2,at+2,7,at,7],OSS,false)
	var crown: String = head+"/Crown"
	patch(crown,[-22,4,-24,-11,-18,-18,-15,-6,-7,-6,-5,-24,2,-27,7,-23,8,-7,16,-7,19,-17,24,-12,23,5],IRON)
	patch(crown,[-18,0,-19,-7,-16,-9,-15,-2,-4,-2,-2,-21,2,-22,4,-19,4,-2,17,-2,19,-8,21,-6,20,1],OSS_SHADE,false)
	patch(crown,[-15,2,15,2,17,6,-17,6],CORD,false)
	return patches
