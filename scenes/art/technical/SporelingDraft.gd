extends "res://scenes/art/technical/NativeMonsterSample.gd"
## Shared authoring helpers only; all rig proportions, skin and clips are new.
const PaperSkin = preload("res://scenes/art/technical/NativePaperSkin.gd")
const Shapes = preload("res://scenes/art/technical/SporelingShapes.gd")
func _init() -> void:
	var facing := Node2D.new()
	facing.name = "Facing"
	add_child(facing)
	var rig := Skeleton2D.new()
	rig.name = "Skeleton2D"
	facing.add_child(rig)
	var torso := joint(rig, "Torso", Vector2(0, -6), 14)
	var head := joint(torso, "Head", Vector2(1, -18), 14)
	var mouth := joint(head, "Mouth", Vector2(10, 2), 12)
	var nozzle := Marker2D.new()
	nozzle.name = "Muzzle"
	nozzle.position = Vector2(13, 1)
	mouth.add_child(nozzle)
	joint(torso, "SporeSac", Vector2(-10, -5), 18)
	for side in ["L", "R"]:
		var x := -1 if side == "L" else 1
		var arm := joint(torso, "Arm" + side, Vector2(10 * x, -2), 7)
		var forearm := joint(arm, "Forearm" + side, Vector2(0, 7), 6)
		joint(forearm, "Hand" + side, Vector2(0, 6), 5)
		var leg := joint(torso, "Leg" + side, Vector2(5 * x, 11), 8)
		joint(leg, "Foot" + side, Vector2(0, 8), 5)
	var skin := PaperSkin.new()
	skin.name = "Skin"
	facing.add_child(skin)
	var animator := AnimationPlayer.new()
	animator.name = "AnimationPlayer"
	add_child(animator)
	var warning := Label.new()
	warning.name = "Warning"
	warning.visible = false
	add_child(warning) # Runtime Enemy owns the only head exclamation marker.
func joint(parent: Node, joint_name: String, at: Vector2, length: float) -> Bone2D:
	var bone := Bone2D.new()
	bone.name = joint_name
	bone.position = at
	bone.rest = bone.transform
	bone.set_autocalculate_length_and_angle(false)
	bone.set_length(length)
	parent.add_child(bone)
	return bone
func _ready() -> void:
	if not $Facing/Skin.build(skeleton, Shapes.new().make()):
		push_error("SPORELING BUILD FAIL: opaque skin binding")
		return
	super._ready()
func _build_clips() -> void:
	var library := AnimationLibrary.new()
	var idle := _new_clip(1.4, true)
	_keys(idle, TORSO + ":position", [0,0.7,1.4], [Vector2(0,-6),Vector2(0,-7),Vector2(0,-6)])
	_rotation_keys(idle, "/SporeSac", [0,0.7,1.4], [0,4,0])
	_rotation_keys(idle, "/Head/Mouth", [0,0.7,1.4], [0,-3,0])
	library.add_animation("idle", idle)
	var walk := _new_clip(0.72, true)
	var steps := [0,0.18,0.36,0.54,0.72]
	_keys(walk, TORSO + ":position", steps, [Vector2(0,-6),Vector2(0,-7.5),Vector2(0,-6),Vector2(0,-7.5),Vector2(0,-6)])
	_rotation_keys(walk, "/LegL", steps, [0,18,0,-18,0])
	_rotation_keys(walk, "/LegR", steps, [0,-18,0,18,0])
	_rotation_keys(walk, "/ArmL", steps, [0,-12,0,12,0])
	_rotation_keys(walk, "/ArmR", steps, [0,12,0,-12,0])
	_rotation_keys(walk, "/Head", steps, [0,2,0,-2,0])
	_rotation_keys(walk, "/SporeSac", steps, [0,7,0,-7,0])
	library.add_animation("walk", walk)
	var warning := _new_clip(0.18)
	_rotation_keys(warning, "", [0,0.09,0.18], [0,-5,-7])
	_rotation_keys(warning, "/Head", [0,0.09,0.18], [0,-3,-6])
	_rotation_keys(warning, "/Head/Mouth", [0,0.09,0.18], [0,-9,-16])
	_keys(warning, TORSO + "/SporeSac:scale", [0,0.18], [Vector2.ONE,Vector2(1.08,1.04)])
	library.add_animation("warning", warning)
	var attack := _new_clip(0.24)
	var spit := [0,0.025,0.07,0.14,0.24]
	_rotation_keys(attack, "", spit, [-7,4,2,0,0])
	_rotation_keys(attack, "/Head", spit, [-6,6,4,0,0])
	_rotation_keys(attack, "/Head/Mouth", spit, [-16,8,4,0,0])
	_keys(attack, TORSO + "/SporeSac:scale", spit, [Vector2(1.08,1.04),Vector2(0.90,0.97),Vector2(0.96,1),Vector2.ONE,Vector2.ONE])
	_rotation_keys(attack, "/ArmR/ForearmR", spit, [0,-16,-8,0,0])
	library.add_animation("attack", attack)
	var hit := _new_clip(0.16)
	_rotation_keys(hit, "", [0,0.04,0.16], [0,-10,0])
	_rotation_keys(hit, "/Head", [0,0.04,0.16], [0,12,0])
	_rotation_keys(hit, "/SporeSac", [0,0.04,0.16], [0,-12,0])
	library.add_animation("hit", hit)
	var death := _new_clip(0.48)
	_keys(death, TORSO + ":position", [0,0.2,0.48], [Vector2(0,-6),Vector2(0,1),Vector2(0,8)])
	_rotation_keys(death, "", [0,0.2,0.48], [0,-28,-76])
	_rotation_keys(death, "/Head", [0,0.2,0.48], [0,10,22])
	_rotation_keys(death, "/Head/Mouth", [0,0.48], [0,25])
	_rotation_keys(death, "/SporeSac", [0,0.48], [0,30])
	_rotation_keys(death, "/ArmR", [0,0.48], [0,45])
	library.add_animation("death", death)
	player.add_animation_library("", library)
