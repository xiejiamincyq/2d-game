extends SceneTree

const SOURCE := "res://scenes/art/technical/RootlingDraft.gd"
var assertions := 0
var failures := 0

func check(ok: bool, label: String) -> void:
	assertions += 1
	if not ok:
		failures += 1
		push_error("TEST FAIL: RootlingDraftTest " + label)

func _initialize() -> void:
	await process_frame
	check(FileAccess.file_exists(SOURCE), "original native rootling draft missing")
	if failures:
		quit(1)
		return
	var actor = load(SOURCE).new()
	root.add_child(actor)
	var rig: Skeleton2D = actor.get_node("Facing/Skeleton2D")
	var skin: Polygon2D = actor.get_node("Facing/Skin")
	check(rig.get_bone_count() == 12 and skin.get_bone_count() == 12, "not all native joints have bound skin")
	check(actor.find_children("*", "Sprite2D", true, false).is_empty(), "draft reuses old sprites/CC0 cutout textures")
	check(actor.find_children("*", "Polygon2D", true, false).size() == 1, "skin split into independently drawn nodes")
	check(actor.find_children("*", "CollisionObject2D", true, false).is_empty(), "visual draft changes collision")
	check(skin.texture == null and skin.vertex_colors.size() == skin.polygon.size(), "not original colored native geometry")
	check(skin.polygons.size() >= 20, "missing silhouette/face/limb shapes")
	var all_weights: Array[PackedFloat32Array] = []
	for joint in skin.get_bone_count():
		var weights := skin.get_bone_weights(joint)
		check(weights.size() == skin.polygon.size(), "partial vertex weights")
		all_weights.append(weights)
	for vertex in skin.polygon.size():
		var total := 0.0
		for weights in all_weights:
			total += weights[vertex]
		check(is_equal_approx(total, 1), "unbound vertex")
		check(is_equal_approx(skin.vertex_colors[vertex].a, 1), "translucent paper body")
	actor.player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	for clip in ["idle", "walk", "warning", "attack", "hit", "death"]:
		check(actor.play_clip(clip), "clip not available " + clip)
		actor.player.seek(actor.player.get_animation(clip).length * 0.4, true)
		check(actor.position == Vector2.ZERO and actor.scale == Vector2.ONE, "animation changes collision pivot")
		if clip != "death":
			check(actor.cancel_action(), "ordinary animation not cancellable")
			check(not actor.get_node("Warning").visible, "cancel leaves marker")
	check(not actor.play_clip("walk"), "death auto-resurrects")
	actor.reset_sample()
	actor.set_facing_left(true)
	check(actor.get_node("Facing").scale.x == -1 and actor.scale.x == 1, "mirror flips actor/collision root")
	var second = load(SOURCE).new()
	root.add_child(second)
	check(second.player.get_animation_library("") == actor.player.get_animation_library(""), "immutable animation keys rebuilt per instance")
	check(second.has_method("skin_build_count"), "missing build instrumentation")
	if second.has_method("skin_build_count"):
		check(second.skin_build_count() == 0, "original mesh triangulation/weights rebuilt per spawn")
	var second_skin: Polygon2D = second.get_node("Facing/Skin")
	check(second_skin.polygon == skin.polygon and second_skin.vertex_colors == skin.vertex_colors, "cached skin changes original geometry")
	check(second_skin.get_bone_count() == 12, "cached binding incomplete")
	var second_head: Bone2D = second.get_node("Facing/Skeleton2D/Torso/Head")
	actor.get_node("Facing/Skeleton2D/Torso/Head").rotation = 0.5
	check(is_zero_approx(second_head.rotation), "shared resources couple independent bone poses")
	second.queue_free()
	actor.queue_free()
	await process_frame
	if not failures:
		print("TEST PASS: RootlingDraftTest %d assertions" % assertions)
	quit(1 if failures else 0)
