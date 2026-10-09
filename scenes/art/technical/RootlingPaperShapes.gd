extends RefCounted

# Original draft, authored as native paper geometry; no external image traced.
const INK := Color("1c2926")
const WOOD := Color("927758")
const LIGHT := Color("b39a72")
const MOSS := Color("648a68")
const IVORY := Color("eadcc1")
const TORSO := "Torso"
var patches: Array[Dictionary] = []

func patch(bone: String, coords: Array, color: Color, outline := true) -> void:
	var points := PackedVector2Array()
	for index in range(0, coords.size(), 2):
		points.append(Vector2(coords[index], coords[index + 1]))
	if outline:
		for border in Geometry2D.offset_polygon(points, 1.1, Geometry2D.JOIN_ROUND):
			patches.append({"bone": NodePath(bone), "points": border, "color": INK})
	patches.append({"bone": NodePath(bone), "points": points, "color": color})

func make() -> Array[Dictionary]:
	patches.clear()
	# Back limbs overlap joint caps; the single mesh preserves drawing order.
	for side in ["L", "R"]:
		var arm: String = TORSO + "/Arm" + side
		var leg: String = TORSO + "/Leg" + side
		patch(leg, [-3,-2, 3,-2, 3,8, 0,12, -4,8], WOOD)
		patch(leg + "/Foot" + side, [-3,-2, 3,-2, 6,4, 2,5, 0,3, -2,5, -5,4], WOOD)
		patch(arm, [-3,-2, 3,-2, 4,5, 2,10, -3,10, -4,4], WOOD)
		patch(arm + "/Forearm" + side, [-3,-2, 3,-2, 4,5, 2,9, -3,8], LIGHT)
		patch(arm + "/Forearm" + side + "/Hand" + side, [-3,-2, 3,-2, 5,3, 4,6, 2,4, 0,7, -2,5, -4,6, -5,3], WOOD)
	patch(TORSO, [-9,-10, 7,-11, 12,-5, 11,7, 5,12, -6,12, -12,6, -12,-4], WOOD)
	patch(TORSO, [-8,-7, 5,-9, 8,-3, 6,3, -6,4, -9,-1], LIGHT, false)
	patch(TORSO, [-10,-8, -4,-11, 2,-8, 9,-10, 11,-5, 5,-2, 0,-4, -7,-2], MOSS)
	patch(TORSO, [-3,0, 2,-1, 4,4, 1,7, -4,5], Color("aa6843"))
	var head := TORSO + "/Head"
	# Offset bark mask and leaf crest distinguish this seedling silhouette.
	patch(head, [-14,-13, -10,-20, -3,-18, 2,-22, 11,-18, 15,-10, 13,3, 6,8, -5,8, -13,3, -16,-5], LIGHT)
	patch(head, [-14,-11, -10,-17, -6,-16, -9,-3, -5,5, -12,1, -15,-5], WOOD, false)
	patch(head, [4,-19, 9,-22, 12,-20, 15,-12, 11,-5, 10,4, 5,6, 8,-9], WOOD, false)
	patch(head, [-9,-18, -11,-23, -6,-27, -1,-23, 0,-19], MOSS)
	patch(head, [-1,-21, 1,-28, 8,-30, 10,-27, 5,-20], Color("7f9c6b"))
	# Large dark eye sockets and ivory eyes stay readable at ordinary scale.
	patch(head, [-10,-8, -5,-10, -1,-7, -2,-2, -7,-1, -11,-4], INK, false)
	patch(head, [3,-9, 9,-10, 12,-6, 10,-2, 4,-2, 2,-5], INK, false)
	patch(head, [-7,-7, -4,-7, -4,-3, -7,-3], IVORY, false)
	patch(head, [6,-7, 9,-7, 9,-4, 6,-4], IVORY, false)
	patch(head, [-3,1, 1,0, 5,1, 3,4, -2,4, -5,2], INK, false)
	patch(head, [-1,1, 1,1, 1,3, -1,3], IVORY, false)
	# Broad bark marks only: avoid unreadable high-frequency hatch textures.
	patch(head, [-4,-16, -2,-15, -3,-11, -5,-12], WOOD, false)
	patch(head, [2,-14, 3,-12, 2,-9, 0,-10], WOOD, false)
	return patches
