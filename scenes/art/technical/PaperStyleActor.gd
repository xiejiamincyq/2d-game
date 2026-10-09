extends Node2D

# Original style authoring laboratory, excluded from release. Static poses only:
# neither the player action set nor deferred large attack resources are produced.
const PaperSkin = preload("res://scenes/art/technical/NativePaperSkin.gd")
const INK := Color("1c2926")
const IVORY := Color("eadcc1")
var kind := "player"
var patches: Array[Dictionary] = []

func _ready() -> void:
	assert(kind in ["player", "large"])
	var facing := Node2D.new()
	facing.name = "Facing"
	add_child(facing)
	var rig := Skeleton2D.new()
	rig.name = "Skeleton2D"
	facing.add_child(rig)
	var large := kind == "large"
	var torso := joint(rig, "Torso", Vector2(0, -18 if large else -10), 24 if large else 16)
	joint(torso, "Head", Vector2(0, -23 if large else -16), 20 if large else 14)
	for side in ["L", "R"]:
		var sign_x := -1 if side == "L" else 1
		var arm := joint(torso, "Arm" + side, Vector2((20 if large else 11) * sign_x, -7 if large else -6), 12 if large else 9)
		var forearm := joint(arm, "Forearm" + side, Vector2(0, 12 if large else 9), 10 if large else 7)
		joint(forearm, "Hand" + side, Vector2(0, 10 if large else 7), 8 if large else 6)
		var leg := joint(torso, "Leg" + side, Vector2((11 if large else 6) * sign_x, 16 if large else 10), 12 if large else 10)
		joint(leg, "Foot" + side, Vector2(0, 12 if large else 10), 8 if large else 5)
	var skin := PaperSkin.new()
	skin.name = "Skin"
	facing.add_child(skin)
	if large:
		large_shapes()
	else:
		player_shapes()
	assert(skin.build(rig, patches), "Original style skin failed to bind")
	if not large:
		make_weapon(rig.get_node("Torso/ArmR/ForearmR/HandR"))

func joint(parent: Node, label: String, at: Vector2, length: float) -> Bone2D:
	var bone := Bone2D.new()
	bone.name = label
	bone.position = at
	bone.rest = bone.transform
	bone.set_autocalculate_length_and_angle(false)
	bone.set_length(length)
	parent.add_child(bone)
	return bone

func patch(bone: String, coords: Array, color: Color, outline := true) -> void:
	var points := PackedVector2Array()
	for index in range(0, coords.size(), 2):
		points.append(Vector2(coords[index], coords[index + 1]))
	if outline:
		for border in Geometry2D.offset_polygon(points, 1.1, Geometry2D.JOIN_ROUND):
			patches.append({"bone": NodePath(bone), "points": border, "color": INK})
	patches.append({"bone": NodePath(bone), "points": points, "color": color})

func player_shapes() -> void:
	var teal := Color("5aada3")
	var coat := Color("487d76")
	var face := Color("c49471")
	for side in ["L", "R"]:
		var leg: String = "Torso/Leg" + side
		var arm: String = "Torso/Arm" + side
		patch(leg, [-3,-1, 3,-1, 3,10, -3,10], Color("45555b"))
		patch(leg + "/Foot" + side, [-4,-1, 3,-1, 5,4, -5,4], Color("334344"))
		patch(arm, [-4,-2, 4,-2, 4,9, -3,10], coat)
		patch(arm + "/Forearm" + side, [-3,-1, 3,-1, 3,6, -3,7], teal)
		patch(arm + "/Forearm" + side + "/Hand" + side, [-3,-1, 3,-1, 3,4, -3,4], face)
	patch("Torso", [-8,-9, 8,-9, 11,7, 8,11, -9,11, -11,7], coat)
	patch("Torso", [-6,-7, 0,-3, 6,-7, 8,4, 0,6, -8,4], teal, false)
	patch("Torso", [-2,-5, 2,-5, 2,9, -2,9], IVORY, false)
	patch("Torso", [-10,7, 10,7, 10,10, -10,10], Color("79674f"))
	patch("Torso", [-2,7, 3,7, 3,10, -2,10], Color("b0784e"), false)
	var head := "Torso/Head"
	# Broad cream hood and human goggles, not the enemy's bark/leaf silhouette.
	patch(head, [-13,-9, -9,-16, 7,-17, 13,-11, 14,1, 8,7, -8,7, -14,1], Color("c8bc9a"))
	patch(head, [-10,-7, 9,-8, 11,-3, 9,4, -8,4, -11,-1], face)
	patch(head, [-10,-8, 10,-8, 11,-1, -11,-1], INK, false)
	patch(head, [-8,-6, -2,-6, -2,-3, -8,-3], Color("a7d3cb"), false)
	patch(head, [2,-6, 8,-6, 8,-3, 2,-3], Color("a7d3cb"), false)
	patch(head, [-7,-14, 6,-15, 10,-10, -10,-9], IVORY, false)
	patch(head, [-4,3, 4,3, 4,5, -4,5], INK, false)

func make_weapon(hand: Bone2D) -> void:
	# A compact one-handed, front-foreshortened pistol. The real hand socket
	# inherits shoulder/elbow motion, never rotation around the gameplay root.
	var grip := Node2D.new()
	grip.name = "WeaponGrip"
	grip.position = Vector2(0, 2)
	hand.add_child(grip)
	var body := Polygon2D.new()
	body.name = "Weapon"
	body.polygon = PackedVector2Array([Vector2(-4,-2), Vector2(4,-2), Vector2(4,9), Vector2(2,12), Vector2(-2,12), Vector2(-4,9)])
	body.color = INK
	grip.add_child(body)
	var barrel := Polygon2D.new()
	barrel.name = "CopperBarrel"
	barrel.polygon = PackedVector2Array([Vector2(-2,0), Vector2(2,0), Vector2(2,8), Vector2(-2,8)])
	barrel.color = Color("b0784e")
	body.add_child(barrel)

func large_shapes() -> void:
	var stone := Color("93958a")
	var light := Color("b8b5a0")
	var bark := Color("73694f")
	for side in ["L", "R"]:
		var leg: String = "Torso/Leg" + side
		var arm: String = "Torso/Arm" + side
		patch(leg, [-6,-3, 5,-3, 6,10, -6,11], bark)
		patch(leg + "/Foot" + side, [-7,-2, 5,-2, 10,4, 7,7, 1,5, -3,7, -9,6], bark)
		patch(arm, [-8,-4, 5,-5, 8,5, 5,13, -7,12, -10,4], stone)
		patch(arm + "/Forearm" + side, [-6,-2, 6,-2, 7,10, -6,11], bark)
		patch(arm + "/Forearm" + side + "/Hand" + side, [-7,-3, 5,-3, 8,3, 5,8, -6,8, -9,3], stone)
	# A broad shield-like slab body, low heavy arms, no rootling leaf crest.
	patch("Torso", [-16,-14, 12,-16, 20,-7, 18,13, 9,20, -13,18, -20,9, -20,-5], bark)
	patch("Torso", [-14,-10, 9,-12, 15,-5, 14,9, 5,15, -12,13, -15,5], stone)
	patch("Torso", [-11,-7, 6,-9, 11,-4, 2,1, -11,0], light, false)
	patch("Torso", [-3,1, 2,0, 6,5, 2,11, -4,8], Color("aa6843"))
	var head := "Torso/Head"
	patch(head, [-17,-10, -12,-22, 9,-24, 18,-14, 16,4, 6,10, -11,8, -19,1], stone)
	patch(head, [-11,-18, 6,-20, 12,-13, -13,-11], light, false)
	patch(head, [-16,-8, -2,-5, -4,0, -14,-2], INK, false)
	patch(head, [2,-5, 15,-9, 14,-3, 4,0], INK, false)
	patch(head, [-12,-5, -7,-4, -7,-2, -12,-3], IVORY, false)
	patch(head, [7,-4, 12,-5, 12,-3, 7,-2], IVORY, false)
	patch(head, [-6,4, 5,3, 6,6, -4,7], INK, false)
