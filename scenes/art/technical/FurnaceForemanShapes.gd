extends "res://scenes/art/technical/SporelingShapes.gd"
## Original iron furnace anatomy; shares opaque patch assembly, not character geometry.
const IRON := Color("667077")
const SOOT := Color("344149")
const COPPER := Color("9e7856")
const EMBER := Color("cb8751")
const ASH := Color("bab39c")
func make() -> Array[Dictionary]:
	patches.clear()
	patch("Torso/Bellows",[-17,-24,11,-22,15,17,5,25,-14,21,-21,5],COPPER)
	for y in [-16,-6,4,14]:
		patch("Torso/Bellows",[-16,y,11,y-1,12,y+3,-15,y+4],SOOT,false)
	patch("Torso/Chimney",[-10,8,-12,-54,-8,-65,9,-65,14,-54,12,10],SOOT)
	patch("Torso/Chimney",[-9,-63,9,-63,12,-55,-11,-55],IRON)
	patch("Torso/Chimney",[-6,-51,-1,-52,0,-10,-4,-9],ASH,false)
	patch("Torso/Chimney",[-10,-24,12,-24,12,-17,-10,-17],COPPER)
	for side in ["L","R"]:
		var leg: String = "Torso/Leg"+side
		patch(leg,[-9,-4,9,-4,11,13,7,20,-9,18,-12,6],SOOT)
		patch(leg,[-6,-1,6,-1,7,8,-6,10],IRON)
		patch(leg+"/Shin"+side,[-10,-3,9,-3,13,12,6,21,-11,17,-14,5],IRON)
		patch(leg+"/Shin"+side,[-7,2,4,1,7,5,2,9,-9,8],ASH,false)
		patch(leg+"/Shin"+side+"/Foot"+side,[-11,-4,8,-4,18,2,18,10,-14,10,-19,5],SOOT)
		patch(leg+"/Shin"+side+"/Foot"+side,[-9,-1,8,-1,12,3,11,5,-11,5],COPPER)
		var shoulder: String = "Torso/Shoulder"+side
		var arm: String = shoulder+"/Arm"+side
		patch(shoulder,[-15,-11,-9,-19,12,-19,18,-9,14,9,-10,12,-18,2],IRON)
		patch(shoulder,[-11,-10,-4,-14,8,-13,12,-8,7,-3,-8,-2],ASH,false)
		patch(shoulder,[-11,4,12,2,13,6,-8,9],COPPER)
		patch(arm,[-7,-4,8,-4,12,13,6,23,-8,21,-12,7],SOOT)
		patch(arm,[-5,0,6,0,7,14,-4,17],COPPER)
		var forearm: String = arm+"/Forearm"+side
		patch(forearm,[-12,-4,10,-5,15,15,9,26,-9,24,-16,7],IRON)
		patch(forearm,[-9,0,8,0,10,7,-11,9],ASH,false)
		patch(forearm,[-10,17,10,15,11,21,-9,22],SOOT)
		patch(forearm+"/Hand"+side,[-11,-4,11,-4,16,4,15,14,7,19,-10,17,-16,7],SOOT)
		patch(forearm+"/Hand"+side,[-8,0,8,0,12,5,9,10,-8,10,-12,5],COPPER)
		patch(forearm+"/Hand"+side,[-7,4,8,3,9,6,-8,7],ASH,false)
	patch("Torso",[-29,-31,17,-34,31,-23,38,2,32,31,15,39,-22,35,-37,18,-39,-9],SOOT)
	patch("Torso",[-25,-26,14,-28,26,-19,31,4,27,27,12,32,-19,28,-30,15,-32,-6],IRON)
	patch("Torso",[-25,23,27,21,25,29,-21,31],COPPER)
	var chest := "Torso/Chest"
	patch(chest,[-23,-21,20,-21,28,-9,26,20,12,30,-18,26,-28,11,-29,-7],COPPER)
	patch(chest,[-18,-16,16,-16,21,-7,19,16,9,23,-13,20,-22,8,-23,-4],SOOT)
	var door := chest+"/Door"
	patch(door,[-18,-12,15,-12,21,-4,20,14,8,22,-15,18,-22,6,-23,-4],IRON)
	patch(door,[-14,-8,11,-8,16,-2,14,11,5,16,-12,13,-17,3],EMBER)
	patch(door,[-13,-4,12,-4,13,0,-14,0],SOOT,false)
	patch(door,[-14,4,12,4,11,8,-12,8],SOOT,false)
	patch(door,[-5,-7,-1,-7,-1,14,-5,14],SOOT,false)
	patch(door,[5,-7,9,-7,8,13,4,15],SOOT,false)
	for side in ["L","R"]:
		var vent: String = chest+"/Vent"+side
		patch(vent,[-8,-11,8,-11,11,-4,10,13,-7,14,-11,3],SOOT)
		patch(vent,[-5,-7,5,-7,6,-2,-6,-2],EMBER)
		patch(vent,[-6,4,6,4,5,9,-5,9],COPPER)
	var head := "Torso/Head"
	patch(head,[-25,-24,-13,-33,13,-32,27,-19,30,5,18,20,-12,20,-27,9,-30,-10],SOOT)
	patch(head,[-22,-21,-12,-28,10,-27,23,-17,25,4,14,15,-9,15,-22,6,-25,-7],IRON)
	patch(head,[-18,-18,-9,-23,7,-22,16,-15,10,-12,-13,-11],ASH,false)
	patch(head,[-15,10,17,8,14,16,-10,18],COPPER)
	var visor := head+"/Visor"
	patch(visor,[-24,-9,15,-10,24,-3,22,8,-19,10,-28,2],SOOT)
	patch(visor,[-18,-4,16,-5,17,0,-17,2],EMBER)
	patch(visor,[-7,-6,-3,-6,-3,4,-7,4],SOOT,false)
	patch(visor,[5,-6,9,-6,9,3,5,4],SOOT,false)
	patch(head,[-6,4,4,3,9,9,5,14,-6,14,-10,10],SOOT)
	patch(head,[-5,7,-2,7,-2,11,-5,11],ASH,false)
	patch(head,[2,7,5,7,5,11,2,11],ASH,false)
	return patches
