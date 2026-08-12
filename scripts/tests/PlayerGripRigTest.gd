extends SceneTree

const GripRig = preload("res://scripts/art/PlayerGripRig.gd")
const PLAYER_SCRIPT_PATH := "res://scripts/actors/Player.gd"

var assertions := 0

func _assert_true(condition: bool, message: String) -> bool:
	assertions += 1
	if condition:
		return true
	push_error("TEST FAIL: PlayerGripRigTest: " + message)
	quit(1)
	return false

func _initialize() -> void:
	var rig := GripRig.new()
	root.add_child(rig)
	if not _assert_true(rig.initialize(), "review rig could not initialize"):
		return
	if not _assert_true(rig.skeleton is Skeleton3D, "rig has no Skeleton3D"):
		return
	if not _assert_true(rig.skeleton.get_bone_count() == 8, "rig must contain root, torso, and two three-bone arms"):
		return
	for bone_name in ["root", "torso", "firing_upper_arm", "firing_forearm", "firing_hand", "support_upper_arm", "support_forearm", "support_hand"]:
		if not _assert_true(rig.skeleton.find_bone(bone_name) >= 0, "missing bone: " + bone_name):
			return
	if not _assert_true(rig.body_mesh.mesh.surface_get_array_len(0) >= 90000, "approved body vertex count was not preserved"):
		return
	var arrays := rig.body_mesh.mesh.surface_get_arrays(0)
	if not _assert_true((arrays[Mesh.ARRAY_BONES] as PackedInt32Array).size() == rig.body_mesh.mesh.surface_get_array_len(0) * 4, "body has no four-slot skin indices"):
		return
	if not _assert_true((arrays[Mesh.ARRAY_WEIGHTS] as PackedFloat32Array).size() == rig.body_mesh.mesh.surface_get_array_len(0) * 4, "body has no four-slot skin weights"):
		return
	if not _assert_true(rig.arm_weighted_vertex_count >= 12000, "too few vertices are assigned to the arm chains"):
		return
	if not _assert_true(rig.body_mesh.mesh.surface_get_array_index_len(0) == 567888, "full approved body topology was not preserved"):
		return
	if not _assert_true(rig.blended_vertex_count >= 8000, "too few vertices use continuous torso/arm blend weights"):
		return
	if not _assert_true(rig.arm_region_vertex_count >= 12000, "arm-region coverage is unexpectedly small"):
		return
	if not _assert_true(float(rig.underweighted_arm_vertex_count) / rig.arm_region_vertex_count < 0.02, "too many arm-region vertices remain underweighted: %d/%d" % [rig.underweighted_arm_vertex_count, rig.arm_region_vertex_count]):
		return
	if not _assert_true(rig.weapon_attachment is BoneAttachment3D, "rifle is not driven by BoneAttachment3D"):
		return
	if not _assert_true(rig.weapon_attachment.bone_name == "firing_hand", "rifle is attached to the wrong bone"):
		return
	if not _assert_true(rig.weapon_model.get_parent() == rig.weapon_attachment, "rifle is not a separate child of the firing-hand attachment"):
		return

	for action in GripRig.ACTIONS:
		rig.apply_action(action)
		await process_frame
		if not _assert_true(rig.firing_hand_error() <= GripRig.CONTACT_TOLERANCE, "%s firing-hand contact drifted: %.6f" % [action, rig.firing_hand_error()]):
			return
		if not _assert_true(rig.support_hand_error() <= GripRig.CONTACT_TOLERANCE, "%s support-hand contact drifted: %.6f" % [action, rig.support_hand_error()]):
			return
		if not _assert_true(rig.stock_contact_error() <= GripRig.CONTACT_TOLERANCE, "%s stock left the shoulder: %.6f" % [action, rig.stock_contact_error()]):
			return

	var player_source := FileAccess.get_file_as_string(PLAYER_SCRIPT_PATH)
	if not _assert_true(not player_source.contains("PlayerGripRig"), "review rig leaked into Player.gd"):
		return
	rig.queue_free()
	await process_frame
	print("TEST PASS: PlayerGripRigTest %d" % assertions)
	quit(0)
