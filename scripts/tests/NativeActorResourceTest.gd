extends SceneTree

const SCENE := "res://scenes/actors/native/rootling_paper_v3.tscn"
var assertions := 0
var failures := 0

func check(ok: bool, label: String) -> void:
	assertions += 1
	if not ok:
		failures += 1
		push_error("TEST FAIL: NativeActorResourceTest " + label)

func _initialize() -> void:
	await process_frame
	check(FileAccess.file_exists(SCENE), "editable native actor scene missing")
	if failures:
		quit(1)
		return
	var packed: PackedScene = load(SCENE)
	check(packed.get_state().get_node_count() >= 17, "bones/skin constructed only at runtime, not editable")
	var actor = packed.instantiate()
	root.add_child(actor)
	var rig: Skeleton2D = actor.get_node("Facing/Skeleton2D")
	var skin: Polygon2D = actor.get_node("Facing/Skin")
	var player: AnimationPlayer = actor.get_node("AnimationPlayer")
	player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	check(player.get_animation_library("").resource_path == "res://assets/art/actors/native/rootling_motion_v3.tres", "editable motion library embedded instead of external/shared")
	check(rig.get_bone_count() == 12 and skin.get_bone_count() == 12, "missing native skin joints")
	check(actor.get_script().resource_path == "res://scripts/components/NativeActorView.gd", "scene retains excluded technical controller")
	check(skin.get_script() == null and skin.texture == null, "scene requires draft geometry builder or texture")
	check(actor.find_children("*", "CollisionObject2D", true, false).is_empty(), "visual scene owns gameplay collision")
	for node in actor.find_children("*", "Node", true, false):
		check(node.owner == actor, "editable ownership missing " + str(node.name))
	for clip in ["idle", "walk", "warning", "attack", "hit", "death"]:
		check(player.has_animation(clip), "missing editable motion " + clip)
		var motion := player.get_animation(clip)
		check(motion.get_track_count() >= 2 and motion.length > 0, "empty motion " + clip)
		for track in motion.get_track_count():
			check(motion.track_get_type(track) == Animation.TYPE_VALUE, "motion controls gameplay methods")
			var target := str(motion.track_get_path(track))
			check(target.begins_with("Facing/Skeleton2D/Torso") or target == "Warning:visible", "motion controls nonvisual property")
		check(actor.play_clip(clip), "editable clip rejected")
		player.seek(motion.length * 0.4, true)
		check(actor.position == Vector2.ZERO and actor.scale == Vector2.ONE and actor.rotation == 0, "clip changes root/collision alignment")
		if clip != "death":
			check(actor.cancel_action(), "live action not cancelled")
			for joint in rig.get_bone_count():
				check(rig.get_bone(joint).transform.is_equal_approx(rig.get_bone(joint).rest), "cancel leaves stale joint")
			check(not actor.get_node("Warning").visible, "cancel leaves warning")
	check(not actor.play_clip("walk") and not actor.cancel_action(), "death is not terminal")
	player.seek(player.get_animation("death").length, true)
	var terminal := rig.get_bone(0).transform
	player.advance(1)
	check(rig.get_bone(0).transform.is_equal_approx(terminal), "death resets itself")
	actor.free()
	var live = packed.instantiate()
	root.add_child(live)
	live.player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	live.play_clip("walk")
	live.player.advance(0.12)
	var before: float = live.player.current_animation_position
	live.play_clip("walk")
	check(is_equal_approx(live.player.current_animation_position, before), "repeated motion restarts gait")
	check(not live.play_clip("absent") and live.player.current_animation == "walk", "unknown clip corrupts current pose")
	live.set_facing_left(true)
	check(live.get_node("Facing").scale == Vector2(-1, 1) and live.scale == Vector2.ONE, "mirroring moves collision root")
	live.play_clip("attack")
	live.player.advance(0.6)
	check(live.player.current_animation == "idle", "ordinary completion does not return to idle")
	live.player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_IDLE
	var pose: Transform2D = live.skeleton.get_bone(0).transform
	paused = true
	await process_frame
	await process_frame
	check(live.skeleton.get_bone(0).transform.is_equal_approx(pose), "paused view advances")
	paused = false
	live.free()
	if failures == 0:
		print("TEST PASS: NativeActorResourceTest %d" % assertions)
	quit(1 if failures else 0)
