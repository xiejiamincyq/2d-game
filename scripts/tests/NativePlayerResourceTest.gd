extends SceneTree

const SCENE := "res://scenes/actors/native/player_paper_v1.tscn"
const CLIPS := ["idle", "walk", "shoot", "dash", "hit", "death", "entrance"]
var assertions := 0
var failures := 0

func check(ok: bool, message: String) -> void:
	assertions += 1
	if not ok:
		failures += 1
		push_error("TEST FAIL: NativePlayerResourceTest " + message)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	check(FileAccess.file_exists(SCENE), "four-facing editable new player absent")
	if failures:
		quit(1)
		return
	var packed: PackedScene = load(SCENE)
	var actor = packed.instantiate()
	root.add_child(actor)
	check(actor.find_children("*", "CollisionObject2D", true, false).is_empty(), "art owns gameplay collision")
	var hashes: Array[int] = []
	for facing in ["Front", "Back", "Left", "Right"]:
		var view: Node2D = actor.get_node(facing)
		var rig: Skeleton2D = view.get_node("Skeleton2D")
		var skin: Polygon2D = view.get_node("Skin")
		var animator: AnimationPlayer = view.get_node("AnimationPlayer")
		check(rig.get_bone_count() == 13 and skin.get_bone_count() == 12, "body/weapon native chains absent " + facing)
		check(skin.get_script() == null and skin.texture == null and skin.get_node(skin.skeleton) == rig, "skin depends on authoring or old texture")
		hashes.append(hash(skin.polygon) ^ hash(skin.vertex_colors))
		check(animator.get_animation_library("").resource_path == "res://assets/art/actors/native/player_%s_motion_v1.tres" % facing.to_lower(), "motion not external/editable")
		for index in rig.get_bone_count():
			var bone := rig.get_bone(index)
			check(bone.rest.is_finite() and not is_zero_approx(bone.rest.determinant()), "invalid rest")
		for color in skin.vertex_colors:
			check(is_equal_approx(color.a, 1), "body contains translucent colors")
		for vertex in skin.polygon.size():
			var total := 0.0
			for binding in skin.get_bone_count():
				total += skin.get_bone_weights(binding)[vertex]
			check(is_equal_approx(total, 1), "unbound or non-normalized skin vertex")
		for clip in CLIPS:
			check(animator.has_animation(clip), "new action missing " + clip)
			var motion := animator.get_animation(clip)
			for track in motion.get_track_count():
				check(motion.track_get_type(track) == Animation.TYPE_VALUE and str(motion.track_get_path(track)).begins_with("Skeleton2D/"), "action writes gameplay or root transforms")
		check(view.scale == Vector2.ONE, "facing only uses root mirror")
	check(hashes[0] != hashes[1] and hashes[2] != hashes[3], "front/back or left/right copied unchanged")
	for direction in [Vector2.DOWN, Vector2.UP, Vector2.LEFT, Vector2.RIGHT]:
		for action in CLIPS:
			var sample = packed.instantiate()
			root.add_child(sample)
			sample.set_aim(direction)
			sample.sample_clip(action, 0)
			var rig: Skeleton2D = sample.get_node(sample.facing + "/Skeleton2D")
			var poses: Array[Transform2D] = []
			for index in rig.get_bone_count():
				poses.append(rig.get_bone(index).transform)
			var animator: AnimationPlayer = sample.get_node(sample.facing + "/AnimationPlayer")
			sample.sample_clip(action, animator.get_animation(action).length * 0.25)
			var changed := false
			for index in rig.get_bone_count():
				changed = changed or not poses[index].is_equal_approx(rig.get_bone(index).transform)
			check(changed, "action has no actual joint movement: " + sample.facing + "/" + action)
			var torso: Bone2D = rig.get_node("Torso")
			var frozen := torso.transform
			await process_frame
			await process_frame
			check(torso.transform.is_equal_approx(frozen), "view advanced independently of authoritative sample clock")
			sample.free()
	for degree in range(0, 360, 5):
		check(actor.set_aim(Vector2.RIGHT.rotated(deg_to_rad(degree))), "valid aim refused")
		check(actor.sample_clip("walk", 0.17), "gait sample refused")
		var view: Node2D = actor.get_node(actor.facing)
		var weapon: Bone2D = view.get_node("Skeleton2D/Torso/ArmR/ForearmR/HandR/Weapon")
		check(weapon.get_parent() is Bone2D and weapon.position == Vector2.ZERO and absf(actor.aim_offset) <= PI / 4 + 0.001, "weapon detached/orbiting aim")
		check(actor.get_muzzle_position().distance_to(actor.global_position) < 60, "gun muzzle orbits remotely")
		var count := 0
		for direction in ["Front", "Back", "Left", "Right"]:
			count += 1 if actor.get_node(direction).visible else 0
		check(count == 1, "multiple bodies visible")
	var before: String = actor.facing
	check(not actor.set_aim(Vector2(NAN, 0)) and actor.facing == before, "nonfinite aim changed pose")
	check(not actor.sample_clip("walk", -1) and not actor.sample_clip("missing", 0), "bad action/time accepted")
	actor.sample_clip("dash", 0.08)
	check(actor.cancel_action() and actor.clip == "idle", "cancel failed")
	check(actor.sample_clip("death", 0.3), "death refused")
	check(not actor.cancel_action() and not actor.sample_clip("walk", 0) and not actor.set_aim(Vector2.UP), "dead actor revived/turned")
	actor.free()
	await process_frame
	if failures == 0:
		print("TEST PASS: NativePlayerResourceTest %d" % assertions)
	quit(1 if failures else 0)
