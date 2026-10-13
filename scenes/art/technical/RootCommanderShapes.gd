extends "res://scenes/art/technical/SporelingShapes.gd"
## Original hooded root commander; shared patch utility, not old PNG geometry.
const CLOTH := Color("596f70")
const CLOTH_LIGHT := Color("839693")
const BARK := Color("8f806a")
const IVORY := Color("d7cbb0")
const POD := Color("a9ac8b")
const SEAL := Color("b58a73")
func make() -> Array[Dictionary]:
	patches.clear()
	patch("Torso/SeedPack",[-16,-15,11,-18,22,-5,20,21,9,32,-13,26,-24,9,-23,-6],BARK)
	patch("Torso/SeedPack",[-10,-9,7,-11,15,-2,11,17,2,23,-12,17,-17,4],POD,false)
	patch("Torso/SeedPack",[-6,1,6,-1,10,5,6,12,-5,12,-11,6],CLOTH)
	for side in ["L","R"]:
		var leg: String = "Torso/Leg"+side
		patch(leg,[-9,-6,8,-6,12,3,8,15,-6,19,-13,8],BARK)
		patch(leg+"/Shin"+side,[-8,-5,7,-6,11,2,8,15,-7,18,-12,4],CLOTH)
		patch(leg+"/Shin"+side+"/Foot"+side,[-12,-4,7,-6,16,0,17,8,5,12,-13,9,-18,3],BARK)
		patch(leg+"/Shin"+side+"/Foot"+side,[-9,0,5,-1,10,3,5,6,-9,5],IVORY,false)
		var mantle: String = "Torso/Mantle"+side
		patch(mantle,[-16,-17,11,-21,24,-4,21,19,12,31,-9,29,-24,14,-27,-1],CLOTH)
		patch(mantle,[-10,-12,7,-15,16,-2,13,17,5,23,-9,19,-18,6],CLOTH_LIGHT,false)
		patch(mantle,[-13,18,10,19,8,25,0,28,-11,24,-19,17],IVORY,false)
		var arm: String = "Torso/Arm"+side
		patch(arm,[-10,-10,8,-12,17,-3,13,14,1,22,-12,15,-17,1],CLOTH)
		patch(arm,[-5,-6,5,-7,10,-1,6,10,-5,9],IVORY,false)
		patch(arm+"/Forearm"+side,[-10,-6,8,-7,14,2,11,14,0,22,-11,16,-15,4],BARK)
		patch(arm+"/Forearm"+side,[-5,-1,5,-2,8,4,4,11,-6,12],IVORY,false)
		patch(arm+"/Forearm"+side+"/Hand"+side,[-9,-6,7,-7,12,0,10,9,0,13,-10,8,-13,1],POD)
	patch("Torso",[-28,-24,-8,-31,17,-27,31,-12,34,15,20,32,-15,36,-33,21,-36,-3],CLOTH)
	patch("Torso",[-19,-19,-5,-25,12,-22,22,-10,24,12,12,25,-12,28,-25,15,-26,-1],CLOTH_LIGHT,false)
	patch("Torso",[-7,-23,5,-23,10,24,1,31,-8,25,-12,-1],IVORY)
	patch("Torso/Core",[-14,-8,-6,-16,6,-15,15,-6,13,9,1,17,-12,10,-17,0],BARK)
	patch("Torso/Core",[-8,-5,-3,-10,4,-9,9,-3,7,5,0,10,-7,6,-10,0],POD)
	patch("Torso/Core",[-3,-4,2,-4,5,0,1,5,-4,2],SEAL,false)
	var head := "Torso/Head"
	patch(head,[-19,-14,-7,-23,11,-22,23,-10,24,7,14,21,-12,22,-23,9,-25,-4],BARK)
	patch(head+"/Hood",[-26,-7,-22,-23,-10,-30,9,-30,24,-17,29,3,22,19,12,24,-13,25,-27,11,-30,1],CLOTH)
	patch(head+"/Hood",[-20,-6,-15,-19,-5,-24,8,-23,17,-13,21,1,15,12,8,16,-11,16,-21,6],IVORY,false)
	patch(head+"/Hood",[-14,-5,-10,-15,0,-20,9,-15,15,-5,13,8,3,14,-9,10,-16,2],INK)
	patch(head,[-10,-3,-3,-7,2,-3,0,4,-7,7,-13,2],POD,false)
	patch(head,[5,-3,12,-6,17,-1,15,5,8,7,3,2],SEAL,false)
	patch(head+"/Mask",[-14,-4,12,-5,17,3,13,12,0,17,-13,12,-19,3],IVORY)
	patch(head+"/Mask",[-9,0,8,-1,10,4,3,9,-8,7,-13,3],CLOTH,false)
	patch(head+"/HornL",[-5,8,-12,-1,-13,-12,-7,-21,-1,-20,-4,-9,3,-2,8,1,5,8],IVORY)
	patch(head+"/HornR",[-5,8,5,8,11,-1,13,-12,7,-21,1,-20,4,-9,-3,-2,-8,1],IVORY)
	var staff := "Torso/ArmR/ForearmR/HandR/Staff"
	patch(staff,[-4,-38,4,-38,5,41,-5,42],BARK)
	patch(staff,[-2,-28,1,-28,2,33,-2,33],IVORY,false)
	patch(staff,[-13,-38,-15,-49,-7,-61,4,-65,15,-55,17,-42,10,-32,-2,-29],BARK)
	patch(staff,[-8,-39,-9,-48,-3,-55,4,-57,10,-50,11,-43,5,-36,-3,-35],POD)
	patch(staff,[-4,-44,-1,-50,4,-50,7,-45,4,-40,-2,-39],SEAL,false)
	patch(staff,[-7,-7,6,-8,7,-2,-7,-1],CLOTH,false)
	return patches
