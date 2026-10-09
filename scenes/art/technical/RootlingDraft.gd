extends "res://scenes/art/technical/NativeMonsterSample.gd"

# Style/performance laboratory only. Shares this goal's newly authored native
# motion contract, never the technical sample's scene or CC0 raster cutouts.
const PaperSkin = preload("res://scenes/art/technical/NativePaperSkin.gd")
const Shapes = preload("res://scenes/art/technical/RootlingPaperShapes.gd")
static var _skin_cache: Dictionary = {}
static var _motion_cache: AnimationLibrary
var _build_count := 0

func _init() -> void:
	var facing := Node2D.new()
	facing.name = "Facing"
	add_child(facing)
	var rig := Skeleton2D.new()
	rig.name = "Skeleton2D"
	facing.add_child(rig)
	var torso := joint(rig, "Torso", Vector2(0, -10), 16)
	joint(torso, "Head", Vector2(0, -16), 14)
	for side in ["L", "R"]:
		var sign_x := -1 if side == "L" else 1
		var arm := joint(torso, "Arm" + side, Vector2(11 * sign_x, -6), 9)
		var forearm := joint(arm, "Forearm" + side, Vector2(0, 9), 7)
		joint(forearm, "Hand" + side, Vector2(0, 7), 6)
		var leg := joint(torso, "Leg" + side, Vector2(6 * sign_x, 10), 10)
		joint(leg, "Foot" + side, Vector2(0, 10), 5)
	var skin := PaperSkin.new()
	skin.name = "Skin"
	facing.add_child(skin)
	var animator := AnimationPlayer.new()
	animator.name = "AnimationPlayer"
	add_child(animator)
	var warning := Label.new()
	warning.name = "Warning"
	warning.text = "!"
	warning.position = Vector2(-4, -70)
	warning.visible = false
	warning.add_theme_font_size_override("font_size", 16)
	warning.add_theme_color_override("font_color", Color("f0d68d"))
	warning.add_theme_color_override("font_outline_color", Color("1c2926"))
	warning.add_theme_constant_override("outline_size", 3)
	add_child(warning)

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
	var skin: Polygon2D = $Facing/Skin
	if _skin_cache.is_empty():
		if not skin.build(skeleton, Shapes.new().make()):
			push_error("TEST FAIL: Rootling native skin could not bind")
			return
		_build_count += 1
		var paths: Array[NodePath] = []
		var weights: Array[PackedFloat32Array] = []
		for index in skin.get_bone_count():
			paths.append(skin.get_bone_path(index))
			weights.append(skin.get_bone_weights(index))
		_skin_cache = {"points": skin.polygon, "faces": skin.polygons, "colors": skin.vertex_colors, "paths": paths, "weights": weights}
	else:
		# Fixed draft rest rig only. Packed arrays are copy-on-write; bone poses
		# and AnimationPlayer playback remain independent on every actor.
		skin.polygon = _skin_cache.points
		skin.polygons = _skin_cache.faces
		skin.vertex_colors = _skin_cache.colors
		skin.skeleton = skin.get_path_to(skeleton)
		for index in _skin_cache.paths.size():
			skin.add_bone(_skin_cache.paths[index], _skin_cache.weights[index])
	super._ready()

func _build_clips() -> void:
	if _motion_cache == null:
		super._build_clips()
		_motion_cache = player.get_animation_library("")
	else:
		player.add_animation_library("", _motion_cache)

func skin_build_count() -> int:
	return _build_count
