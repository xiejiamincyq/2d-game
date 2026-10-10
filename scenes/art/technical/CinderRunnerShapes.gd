extends RefCounted
## Original forge imp: ram-mask, folding mantle and articulated spring shins.
const INK := Color("292b29")
const IRON := Color("666b61")
const BRICK := Color("a57557")
const PAPER := Color("d5c49c")
var patches: Array[Dictionary] = []
func patch(bone: String, coords: Array, color: Color, outline := true) -> void:
	var points := PackedVector2Array()
	for index in range(0,coords.size(),2):
		points.append(Vector2(coords[index],coords[index+1]))
	if outline:
		for border in Geometry2D.offset_polygon(points,1.2,Geometry2D.JOIN_ROUND):
			patches.append({"bone":NodePath(bone),"points":border,"color":INK})
	patches.append({"bone":NodePath(bone),"points":points,"color":color})
func make() -> Array[Dictionary]:
	patches.clear()
	patch("Torso/Mantle",[-13,-10, -5,-16, 3,-14, 5,-6, 5,9, -5,17, -15,10],BRICK)
	patch("Torso/Mantle",[-8,-10, -5,-13, -1,-11, -1,8, -5,10, -8,5],IRON)
	for side in ["L","R"]:
		var leg: String = "Torso/Leg" + side
		var arm: String = "Torso/Arm" + side
		patch(leg,[-3,-2, 3,-2, 4,7, -2,10, -4,5],IRON)
		patch(leg + "/Shin" + side,[-3,-2, 3,-2, 4,6, 2,9, -3,7],PAPER)
		patch(leg + "/Shin" + side,[ -3,2, 3,2, 3,4, -3,4],IRON,false)
		patch(leg + "/Shin" + side + "/Foot" + side,[-4,-2, 4,-3, 9,1, 9,5, -5,5],BRICK)
		patch(arm,[-4,-2, 4,-2, 5,4, 3,9, -3,8],BRICK)
		patch(arm + "/Forearm" + side,[-3,-2, 3,-2, 4,7, -4,8],IRON)
		patch(arm + "/Forearm" + side + "/Hand" + side,[-4,-2, 3,-3, 6,1, 4,6, -3,6, -5,2],PAPER)
	patch("Torso",[-9,-10, 9,-9, 12,-1, 10,9, 1,13, -10,7, -12,-1],IRON)
	patch("Torso",[-7,-7, 3,-8, 9,-3, 6,4, -5,5],BRICK)
	patch("Torso",[-9,5, 9,4, 9,8, -7,10],PAPER)
	patch("Torso",[-2,5, 3,5, 4,9, -2,9],INK,false)
	# Low angular mask, forward brow and two riveted cheek plates, not a cap.
	var head := "Torso/Head"
	patch(head,[-14,-11, -7,-19, 9,-19, 17,-12, 20,-2, 15,8, 3,12, -10,8, -16,0],IRON)
	patch(head,[-13,-12, -6,-19, 8,-18, 16,-12, 22,-8, 20,-3, 8,-5, -12,-4],BRICK)
	patch(head,[-9,-15, -4,-19, 3,-18, 8,-11, 6,-9, 1,-11, -4,-14],PAPER,false)
	patch(head,[-11,-1, 17,-1, 15,4, -9,4],INK,false)
	patch(head,[7,0, 13,0, 12,2, 7,2],PAPER,false)
	patch(head,[-12,5, -6,4, -4,8, -8,10, -13,8],BRICK)
	patch(head,[8,5, 16,4, 15,8, 9,10, 6,8],BRICK)
	patch(head,[-9,6, -7,6, -7,8, -9,8],PAPER,false)
	patch(head,[11,6, 13,6, 13,8, 11,8],PAPER,false)
	return patches
