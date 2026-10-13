extends "res://scenes/art/technical/SporelingShapes.gd"
## Original four-foot compass surveyor; no reused monster silhouettes/geometry.
const PLATE := Color("7c8589")
const BRASS := Color("b9a586")
const CLOTH := Color("746e82")
const LIGHT := Color("d4cebc")
func make() -> Array[Dictionary]:
	patches.clear()
	patch("Torso/TailFin",[-7,-3, -11,-11, -2,-9, 6,-2, 4,6, -5,9],CLOTH)
	patch("Torso/TailFin",[-7,-7, -2,-6, 2,-1, 0,3],BRASS,false)
	for limb in ["BackL","BackR","FrontL","FrontR"]:
		var sx := -1 if limb.ends_with("L") else 1
		var leg: String = "Torso/"+limb
		patch(leg,[-4,-2, 4,-2, 5,8, 2,12, -4,10],CLOTH)
		patch(leg+"/Foot",[-4*sx,-2, 3*sx,-3, 8*sx,4, 6*sx,7, -5*sx,7],PLATE)
		patch(leg+"/Foot",[-1*sx,0, 2*sx,0, 5*sx,4, 1*sx,4],LIGHT,false)
	patch("Torso",[-22,-8, -14,-15, 13,-14, 24,-4, 22,9, 12,14, -14,13, -24,4],PLATE)
	patch("Torso",[-17,-8, -9,-11, 12,-10, 18,-5, 11,-2, -14,-3],LIGHT,false)
	patch("Torso",[-18,5, 13,5, 15,10, -12,10],CLOTH,false)
	patch("Torso/CounterArm",[-4,-4, 4,-4, 6,8, 2,12, -5,8],BRASS)
	patch("Torso/CounterArm/Weight",[-5,-3, 4,-4, 7,3, 4,10, -3,9, -7,3],CLOTH)
	patch("Torso/CounterArm/Weight",[-3,-1, 2,-1, 4,3, 1,6, -3,4],LIGHT,false)
	patch("Torso/Compass",[-11,-2, -7,-10, 3,-12, 11,-6, 12,4, 4,12, -7,10, -12,3],INK)
	patch("Torso/Compass",[-8,-1, -5,-7, 3,-9, 8,-4, 8,3, 2,8, -6,6, -8,2],BRASS,false)
	patch("Torso/Compass/Needle",[-1,-6, 2,-2, 2,5, 0,7, -2,2],CLOTH,false)
	patch("Torso/Compass/Needle",[-1,-6, 2,-2, 0,1, -2,2],LIGHT,false)
	patch("Torso/CutArm",[-4,-4, 5,-4, 12,3, 10,8, 3,10, -4,5],BRASS)
	patch("Torso/CutArm/Gimbal",[-5,-5, 2,-7, 8,-2, 9,4, 2,8, -5,4],CLOTH)
	patch("Torso/CutArm/Gimbal",[-2,-2, 3,-3, 5,1, 1,4, -2,2],LIGHT,false)
	patch("Torso/CutArm/Gimbal/Tine",[-4,-3, 3,-3, 17,-1, 22,2, 17,5, 3,4, -4,2],PLATE)
	patch("Torso/CutArm/Gimbal/Tine",[0,-1, 16,0, 19,2, 14,3, 0,2],LIGHT,false)
	patch("Torso/Head",[-15,-4, -10,-15, 1,-19, 11,-15, 16,-5, 13,8, -12,9],CLOTH)
	patch("Torso/Head",[-10,-6, -6,-13, 1,-15, 9,-11, 5,-7],LIGHT,false)
	patch("Torso/Head/Visor",[-13,-3, 11,-4, 14,2, 10,7, -10,7, -14,2],INK)
	patch("Torso/Head/Visor",[-8,0, 7,-1, 9,2, 6,4, -8,4],BRASS,false)
	patch("Torso/Head/Visor",[-4,0, -1,0, -1,3, -4,3],LIGHT,false)
	return patches
