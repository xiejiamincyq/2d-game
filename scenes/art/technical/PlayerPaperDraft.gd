extends "res://scenes/art/technical/PaperStyleActor.gd"
## Original four-view author source, never an old atlas or runtime dependency.
const Motion = preload("res://scenes/art/technical/PlayerPaperMotion.gd")
const ANGLES := {"Front": PI / 2, "Back": -PI / 2, "Left": PI, "Right": 0.0}
var direction := "Front"
var rig: Skeleton2D

func _ready() -> void:
	rig = Skeleton2D.new()
	rig.name = "Skeleton2D"
	add_child(rig)
	var profile := direction in ["Left", "Right"]
	var sx := -1 if direction == "Left" else 1
	var torso := joint(rig, "Torso", Vector2(0, -10), 16)
	joint(torso, "Head", Vector2(0, -17), 14)
	for side in ["L", "R"]:
		var sign_x := -1 if side == "L" else 1
		var shoulder := Vector2((4 if profile else 10) * sign_x, -5)
		var arm := joint(torso, "Arm" + side, shoulder, 9)
		var elbow := Vector2(sx * 4, 7) if profile else Vector2(0, 8)
		if direction == "Back" and side == "R":
			elbow = Vector2(3, -2)
		var forearm := joint(arm, "Forearm" + side, elbow, 7)
		var hand_at := Vector2(sx * 5, 0) if profile else Vector2(0, 6)
		if direction == "Back" and side == "R":
			hand_at = Vector2(0, -5)
		joint(forearm, "Hand" + side, hand_at, 5)
		var leg := joint(torso, "Leg" + side, Vector2((4 if profile else 6) * sign_x, 10), 9)
		joint(leg, "Foot" + side, Vector2(0, 9), 5)
	_draw_parts(profile, sx)
	var skin := PaperSkin.new()
	skin.name = "Skin"
	add_child(skin)
	assert(skin.build(rig, patches))
	var weapon := joint(rig.get_node("Torso/ArmR/ForearmR/HandR"), "Weapon", Vector2.ZERO, 13)
	weapon.rotation = ANGLES[direction]
	weapon.rest = weapon.transform
	var barrel := Polygon2D.new()
	barrel.name = "Pistol"
	barrel.polygon = PackedVector2Array([Vector2(-3,-3), Vector2(13,-3), Vector2(13,2), Vector2(3,2), Vector2(1,7), Vector2(-3,7)])
	barrel.color = INK
	weapon.add_child(barrel)
	var metal := Polygon2D.new()
	metal.name = "CopperSlide"
	metal.polygon = PackedVector2Array([Vector2(0,-2), Vector2(11,-2), Vector2(11,0), Vector2(0,0)])
	metal.color = Color("b58352")
	weapon.add_child(metal)
	var muzzle := Node2D.new()
	muzzle.name = "Muzzle"
	muzzle.position = Vector2(14, -0.5)
	weapon.add_child(muzzle)
	# Rear-facing firearm passes behind the body, not through its hood.
	weapon.z_index = -1 if direction == "Back" else 1
	var animator := AnimationPlayer.new()
	animator.name = "AnimationPlayer"
	add_child(animator)
	animator.add_animation_library("", Motion.new().make(rig, direction))

func _draw_parts(profile: bool, sx: int) -> void:
	var coat := Color("497c72")
	var teal := Color("65aba0")
	var face := Color("c99775")
	# Far limbs first, coat covers shoulder seams, closer cuff comes last.
	for side in ["L", "R"]:
		var path: String = "Torso/Leg" + side
		patch(path, [-3,-1, 3,-1, 3,9, -3,9], Color("465451"))
		patch(path + "/Foot" + side, [-4,-1, 3,-1, 5,3, 3,5, -5,5], Color("344744"))
		var arm: String = "Torso/Arm" + side
		patch(arm, [-3,-2, 4,-2, 4,7, -3,8], coat)
		patch(arm + "/Forearm" + side, [-3,-1, 3,-1, 3,6, -3,7], teal)
		patch(arm + "/Forearm" + side + "/Hand" + side, [-3,-2, 3,-2, 3,3, -3,4], face)
	var width := 7 if profile else 10
	patch("Torso", [-width,-8, width,-8, width+2,7, width,12, -width,12, -width-2,7], coat)
	if direction == "Back":
		patch("Torso", [-7,-6, 7,-6, 8,7, -8,7], Color("7e7357"))
		patch("Torso", [-6,-5, 6,-5, 6,2, -6,2], Color("b5a781"), false)
		patch("Torso", [-1,-5, 1,-5, 1,8, -1,8], IVORY, false)
	else:
		patch("Torso", [-width+2,-6, 0,-2, width-2,-6, width,3, 0,5, -width,3], teal, false)
		patch("Torso", [-1,-4, 2,-4, 2,9, -1,9], IVORY, false)
	patch("Torso", [-width,8, width,8, width,10, -width,10], Color("826646"))
	if profile:
		patch("Torso", [sx*-6,1, sx*-10,2, sx*-10,9, sx*-5,10], Color("9d845b"))
	var head := "Torso/Head"
	if profile:
		patch(head, [-10,-11, -6,-17, 5,-18, 11,-11, 13,-2, 6,6, -7,5, -12,-2], Color("c7b996"))
		patch(head, [sx*3,-8, sx*11,-7, sx*14,-2, sx*10,4, sx*3,3], face)
		patch(head, [sx*-9,-8, sx*11,-8, sx*12,-2, sx*-9,-3], INK, false)
		patch(head, [sx*6,-6, sx*11,-5, sx*11,-3, sx*6,-3], Color("b8d7c8"), false)
		patch(head, [-6,-15, 4,-16, 8,-11, -7,-10], IVORY, false)
		# Original left cheek patch / right copper clasp, not just root flipping.
		patch(head, [sx*4,1, sx*8,1, sx*8,3, sx*4,3], Color("ac7d51") if direction == "Right" else Color("dac6a1"), false)
	else:
		patch(head, [-13,-10, -8,-17, 7,-18, 13,-11, 14,0, 8,7, -8,7, -14,0], Color("c7b996"))
		patch(head, [-7,-15, 6,-16, 10,-11, -10,-10], IVORY, false)
		if direction == "Front":
			patch(head, [-10,-7, 9,-7, 11,-2, 8,4, -8,4, -11,-1], face)
			patch(head, [-11,-8, 10,-8, 11,-1, -11,-1], INK, false)
			for x in [-8, 2]:
				patch(head, [x,-6, x+6,-6, x+6,-3, x,-3], Color("b8d7c8"), false)
			patch(head, [-3,3, 3,3, 3,5, -3,5], INK, false)
		else:
			patch(head, [-11,-7, 11,-7, 12,-3, -12,-3], INK, false)
			patch(head, [-2,-13, 2,-13, 2,3, -2,3], Color("b5a781"), false)
			patch(head, [-5,3, 5,3, 5,6, -5,6], IVORY, false)
