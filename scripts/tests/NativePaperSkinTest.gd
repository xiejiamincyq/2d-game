extends SceneTree

const SOURCE := "res://scenes/art/technical/NativePaperSkin.gd"
var assertions := 0
var failures := 0

func check(ok: bool, label: String) -> void:
	assertions += 1
	if not ok:
		failures += 1
		push_error("TEST FAIL: NativePaperSkinTest " + label)

func _initialize() -> void:
	await process_frame
	check(FileAccess.file_exists(SOURCE), "weighted native paper skin is missing")
	if failures:
		quit(1)
		return
	var holder := Node2D.new()
	var skeleton := Skeleton2D.new()
	skeleton.name = "Skeleton2D"
	var bone := Bone2D.new()
	bone.name = "Root"
	bone.position = Vector2(4, -12)
	bone.rest = bone.transform
	bone.set_autocalculate_length_and_angle(false)
	bone.length = 12
	skeleton.add_child(bone)
	holder.add_child(skeleton)
	root.add_child(holder)
	var skin = load(SOURCE).new()
	holder.add_child(skin)
	var shape := PackedVector2Array([Vector2(-4, 0), Vector2(4, 0), Vector2(4, 10), Vector2(-4, 10)])
	var patches: Array[Dictionary] = [{"bone": NodePath("Root"), "points": shape, "color": Color("799478")}]
	check(skin.build(skeleton, patches), "valid native bound shape rejected")
	check(skin is Polygon2D and skin.texture == null, "not an original untextured native mesh")
	check(skin.get_node(skin.skeleton) == skeleton, "skin references wrong skeleton")
	check(skin.get_bone_count() == 1 and skin.get_bone_path(0) == NodePath("Root"), "bone paths are not skeleton-relative")
	check(skin.polygon.size() == 4 and skin.polygons.size() == 1, "patch is not one mesh face")
	check(skin.polygon[0].is_equal_approx(Vector2(0, -12)), "vertices not mapped into skeleton rest space")
	for weight in skin.get_bone_weights(0):
		check(is_equal_approx(weight, 1), "rigid cutout not fully bound")
	for color in skin.vertex_colors:
		check(is_equal_approx(color.a, 1), "skin introduces translucent body")
	var original: PackedVector2Array = skin.polygon.duplicate()
	var invalid: Array[Dictionary] = [{"bone": NodePath("Absent"), "points": shape, "color": Color.WHITE}]
	check(not skin.build(skeleton, invalid), "unknown bone accepted")
	check(skin.polygon == original and skin.get_bone_count() == 1, "failed build destroyed valid mesh")
	invalid[0].bone = NodePath("Root")
	invalid[0].points = PackedVector2Array([Vector2.ZERO, Vector2.ZERO, Vector2.ZERO])
	check(not skin.build(skeleton, invalid), "degenerate face accepted")
	invalid[0].points = shape
	invalid[0].color = Color(1, 1, 1, 0.5)
	check(not skin.build(skeleton, invalid), "half-transparent body accepted")
	invalid[0].color = Color(NAN, 1, 1, 1)
	check(not skin.build(skeleton, invalid), "non-finite color accepted")
	var empty: Array[Dictionary] = []
	check(not skin.build(skeleton, empty), "empty skin accepted")
	check(skin.polygon == original, "invalid changes replaced original mesh")
	holder.queue_free()
	await process_frame
	if not failures:
		print("TEST PASS: NativePaperSkinTest %d assertions" % assertions)
	quit(1 if failures else 0)
