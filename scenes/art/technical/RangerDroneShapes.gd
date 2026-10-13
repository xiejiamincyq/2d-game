extends "res://scenes/art/technical/SporelingShapes.gd"
## Original small paper survey companion. Shares only opaque outline helpers.
const TEAL := Color("69a8a1")
const BRASS := Color("b2996e")
const DARK := Color("435750")
func make() -> Array[Dictionary]:
	patches.clear()
	patch("Torso/Tail",[-5,-2,1,-2,1,2,-5,3,-7,0],BRASS)
	for side in ["L","R"]:
		var sign_x := -1 if side=="L" else 1
		var path: String = "Torso/Wing"+side
		patch(path,[0,-3,sign_x*6,-4,sign_x*7,1,sign_x*4,4,0,2],TEAL)
		patch(path+"/Tip"+side,[0,-2,sign_x*4,-3,sign_x*6,0,sign_x*4,3,0,2],PAPER)
	patch("Torso",[-8,-4,-3,-7,4,-6,8,-2,7,5,2,7,-6,5,-9,0],PAPER)
	patch("Torso",[-6,0,6,-1,6,4,1,6,-6,4],TEAL)
	patch("Torso",[-3,-4,2,-4,4,-1,-4,-1],Color("f0e4c6"),false)
	patch("Torso/Head",[-3,-4,3,-4,6,-1,5,3,0,5,-4,2],DARK)
	patch("Torso/Head/Lens",[-2,-2,2,-2,3,0,2,2,-2,2,-3,0],TEAL)
	patch("Torso/Head/Lens",[0,-1,2,-1,2,1,0,1],Color("ece0c1"),false)
	patch("Torso/Gun",[-2,-2,5,-2,5,2,-2,2],BRASS)
	patch("Torso/Gun/Nozzle",[-1,-2,4,-2,6,-1,6,1,4,2,-1,2],DARK)
	patch("Torso/Gun/Nozzle",[3,-1,5,-1,5,1,3,1],TEAL,false)
	return patches
