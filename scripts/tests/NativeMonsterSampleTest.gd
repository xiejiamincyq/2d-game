extends SceneTree

const SAMPLE := "res://scenes/art/technical/NativeMonsterSample.tscn"
var assertions := 0
var failures := 0

func check(ok: bool, label: String) -> void:
	assertions += 1
	if not ok:
		failures += 1
		push_error("TEST FAIL: NativeMonsterSampleTest " + label)

func _initialize() -> void:
	await process_frame
	check(FileAccess.file_exists(SAMPLE), "native skeletal sample is missing")
	if failures > 0:
		quit(1)
		return
	var scene = load(SAMPLE)
	var actor = scene.instantiate()
	root.add_child(actor)
	var skeleton: Skeleton2D = actor.get_node("Facing/Skeleton2D")
	var player: AnimationPlayer = actor.get_node("AnimationPlayer")
	player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	check(skeleton.get_bone_count() == 12, "not a complete native joint hierarchy")
	var rest_poses: Dictionary = {}
	for index in skeleton.get_bone_count():
		var bone := skeleton.get_bone(index)
		check(bone is Bone2D and bone.get_rest().is_finite(), "invalid native rest pose")
		check(not bone.get_autocalculate_length_and_angle() and bone.get_length() > 0, "leaf gizmo/rest length is unspecified")
		rest_poses[bone] = bone.transform
	check(actor.find_children("*", "CollisionObject2D", true, false).is_empty(), "visual component contains gameplay collision")
	var provenance: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/art/source/campaign_native_sample_v1/provenance.json"))
	for skin in actor.find_children("*", "Sprite2D", true, false):
		var source: String = skin.texture.resource_path
		check(source.ends_with(".png") and provenance.source_files_sha256.has(source.get_file()), "sample imports a different unreviewed atlas export")
		check(FileAccess.get_sha256(source) == provenance.source_files_sha256.get(source.get_file(), "missing"), "CC0 source bytes differ from audited original")
		check(is_equal_approx(skin.modulate.a, 1.0) and is_equal_approx(skin.self_modulate.a, 1.0), "skin tint makes the character translucent")
	var clips := ["idle", "walk", "warning", "attack", "hit", "death"]
	for clip in clips:
		check(player.has_animation(clip), "missing newly authored clip " + clip)
		var animation := player.get_animation(clip)
		check(animation.length > 0 and animation.get_track_count() >= 2, "empty placeholder animation " + clip)
		for track in animation.get_track_count():
			check(animation.track_get_type(track) == Animation.TYPE_VALUE, "animation can call gameplay methods")
			var path := str(animation.track_get_path(track))
			check(path.begins_with("Facing/Skeleton2D/Torso/") or path.begins_with("Facing/Skeleton2D/Torso:" ) or path == "Warning:visible", "animation targets non-visual state")
		check(actor.play_clip(clip), "clip rejected " + clip)
		player.seek(animation.length * 0.4, true)
		check(actor.position == Vector2.ZERO and actor.rotation == 0.0 and actor.scale == Vector2.ONE, "clip moves the actor root")
		check(is_equal_approx(actor.modulate.a, 1.0), "body rendered translucent")
		if clip != "death":
			check(actor.cancel_action(), "alive action cannot be cancelled")
			for bone in rest_poses:
				check(bone.transform.is_equal_approx(rest_poses[bone]), "cancel leaves stale pose " + str(bone.name))
			check(not actor.get_node("Warning").visible, "cancel leaves warning marker")
	check(not actor.play_clip("walk") and not actor.cancel_action(), "death can be interrupted/resurrected")
	player.seek(player.get_animation("death").length, true)
	var dead_pose: Transform2D = skeleton.get_bone(0).transform
	player.advance(1.0)
	check(skeleton.get_bone(0).transform.is_equal_approx(dead_pose), "death restarts/returns to idle")
	actor.reset_sample()
	check(actor.play_clip("walk"), "explicit technical reset does not revive sample")
	player.seek(0.16, true)
	var hand: Bone2D = actor.get_node("Facing/Skeleton2D/Torso/ArmR/ForearmR/HandR")
	var hand_before := hand.global_position
	var shoulder: Bone2D = actor.get_node("Facing/Skeleton2D/Torso/ArmR")
	shoulder.rotation += 0.3
	check(hand.global_position.distance_to(hand_before) > 2.0, "hand is not attached to shoulder chain")
	actor.cancel_action()
	actor.set_facing_left(true)
	check(actor.get_node("Facing").scale == Vector2(-1, 1) and actor.scale == Vector2.ONE, "mirroring modifies collision/actor transform")
	actor.set_facing_left(false)
	check(not actor.play_clip("unknown"), "unknown clip accepted")
	actor.play_clip("attack")
	player.advance(0.6)
	check(player.current_animation == "idle", "completed ordinary action does not return to idle")
	actor.play_clip("warning")
	player.advance(0.01)
	check(actor.get_node("Warning").visible, "short head warning marker missing")
	actor.play_clip("hit")
	check(not actor.get_node("Warning").visible, "interrupted warning survives hit")
	actor.cancel_action()
	actor.play_clip("walk")
	player.advance(0.1)
	var gait_time := player.current_animation_position
	actor.play_clip("walk")
	check(is_equal_approx(player.current_animation_position, gait_time), "repeated movement commands reset gait")
	player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_IDLE
	player.advance(0.0)
	var before_pause: Transform2D = skeleton.get_bone(0).transform
	paused = true
	await process_frame
	await process_frame
	check(skeleton.get_bone(0).transform.is_equal_approx(before_pause), "native player advances while scene is paused")
	paused = false
	actor.free()
	if failures == 0:
		print("TEST PASS: NativeMonsterSampleTest %d" % assertions)
	quit(0 if failures == 0 else 1)
