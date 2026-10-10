extends RefCounted
## Original mushroom courier silhouette; no traced raster or external artwork.
const INK := Color("1c2926")
const PAPER := Color("d6c8a4")
const STEM := Color("afa783")
const MOSS := Color("607e60")
const ACID := Color("a8ba63")
var patches: Array[Dictionary] = []
func patch(bone: String, coords: Array, color: Color, outline := true) -> void:
	var points := PackedVector2Array()
	for index in range(0, coords.size(), 2):
		points.append(Vector2(coords[index], coords[index + 1]))
	if outline:
		for border in Geometry2D.offset_polygon(points, 1.2, Geometry2D.JOIN_ROUND):
			patches.append({"bone": NodePath(bone), "points": border, "color": INK})
	patches.append({"bone": NodePath(bone), "points": points, "color": color})
func make() -> Array[Dictionary]:
	patches.clear()
	for side in ["L", "R"]:
		var arm: String = "Torso/Arm" + side
		var leg: String = "Torso/Leg" + side
		patch(leg, [-3,-2, 3,-2, 3,9, -3,9], STEM)
		patch(leg + "/Foot" + side, [-3,-2, 4,-2, 7,3, 5,5, -4,5], MOSS)
		patch(arm, [-3,-2, 3,-2, 3,8, -3,9], STEM)
		patch(arm + "/Forearm" + side, [-3,-2, 3,-2, 3,7, -3,8], STEM)
		patch(arm + "/Forearm" + side + "/Hand" + side, [-3,-2, 3,-2, 5,2, 2,6, -3,5, -4,1], MOSS)
	# Back spore reservoir is independently articulated, not a bark-mask recolor.
	patch("Torso/SporeSac", [-10,-11, -2,-14, 7,-11, 10,-2, 8,10, 0,15, -9,9, -12,0], MOSS)
	patch("Torso/SporeSac", [-7,-5, -3,-8, 1,-5, 1,1, -3,4, -7,1], ACID)
	patch("Torso/SporeSac", [2,5, 5,3, 8,5, 7,9, 4,10, 2,8], ACID, false)
	patch("Torso", [-10,-10, 5,-12, 11,-6, 11,9, 6,13, -6,12, -11,4], MOSS)
	patch("Torso", [-3,-8, 5,-9, 8,-5, 7,9, 2,11, -3,7], STEM, false)
	patch("Torso", [-10,2, 10,1, 10,5, -9,6], Color("827354"))
	var head := "Torso/Head"
	patch(head, [-11,-9, 12,-9, 15,-1, 12,10, 2,13, -9,9, -13,1], STEM)
	# Wide asymmetrical cap and hanging gills, three broad spots only.
	patch(head, [-24,-8, -19,-20, -8,-28, 6,-29, 19,-21, 25,-10, 26,-5, 14,-2, -12,-2, -25,-5], PAPER)
	patch(head, [-24,-6, -12,-8, 15,-8, 25,-5, 13,-1, -13,-1], Color("8e8261"))
	patch(head, [-14,-19, -10,-23, -6,-21, -7,-16, -12,-15], Color("efe3c4"), false)
	patch(head, [2,-25, 7,-25, 11,-21, 8,-18, 3,-19], Color("efe3c4"), false)
	patch(head, [14,-15, 18,-16, 21,-12, 17,-10], Color("efe3c4"), false)
	patch(head, [-5,0, 0,-1, 3,2, 1,6, -4,6, -7,3], INK, false)
	patch(head, [-3,1, 0,1, 0,4, -3,4], Color("ece0c1"), false)
	# The hinged mouth has its own skin weights and editable emission locator.
	patch(head + "/Mouth", [-3,-5, 8,-4, 13,-1, 13,4, 8,6, -4,4], STEM)
	patch(head + "/Mouth", [8,-2, 12,-1, 12,3, 8,4, 6,1], INK, false)
	patch(head + "/Mouth", [9,0, 11,0, 11,2, 9,2], ACID, false)
	return patches
