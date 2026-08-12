extends SceneTree

const MotionRig = preload("res://scripts/art/PlayerMotionRig.gd")
const PLAYER_SCRIPT_PATH := "res://scripts/actors/Player.gd"

var assertions := 0

func _assert_true(condition: bool, message: String) -> bool:
	assertions += 1
	if condition:
		return true
	push_error("TEST FAIL: PlayerMotionRigTest: " + message)
	quit(1)
	return false

func _initialize() -> void:
	if not _assert_true(MotionRig.REVIEW_SKINNED_MESH_CACHE_SCHEMA_VERSION == 1, "motion review cache schema version drifted"):
		return
	if not _assert_true(FileAccess.file_exists(MotionRig.REVIEW_SKINNED_MESH_CACHE_PATH), "versioned motion review cache is missing"):
		return
	var rig := MotionRig.new()
	root.add_child(rig)
	if not _assert_true(rig.initialize(), "motion review rig could not initialize"):
		return
	if not _assert_true(rig.skeleton.get_bone_count() == 14, "motion rig must add two three-bone leg chains to the approved eight-bone grip rig"):
		return
	for bone_name in ["left_thigh", "left_shin", "left_foot", "right_thigh", "right_shin", "right_foot"]:
		if not _assert_true(rig.skeleton.find_bone(bone_name) >= 0, "missing motion bone: " + bone_name):
			return
	if not _assert_true(rig.body_mesh.mesh.surface_get_array_len(0) >= 90000, "approved body vertex count was not preserved"):
		return
	if not _assert_true(rig.body_mesh.mesh.surface_get_array_index_len(0) == 567888, "approved body topology changed during leg rigging"):
		return
	if not _assert_true(rig.leg_region_vertex_count >= 16000, "leg-region coverage is unexpectedly small"):
		return
	if not _assert_true(rig.blended_leg_vertex_count >= 5000, "too few lower-body vertices use continuous leg weights"):
		return
	if not _assert_true(float(rig.underweighted_leg_vertex_count) / rig.leg_region_vertex_count < 0.02, "too many leg-region vertices remain underweighted: %d/%d" % [rig.underweighted_leg_vertex_count, rig.leg_region_vertex_count]):
		return
	if not _assert_true(rig.weapon_attachment is BoneAttachment3D, "motion rig lost the independent rifle attachment"):
		return
	if not _assert_true(rig.weapon_model.get_parent() == rig.weapon_attachment, "motion rig fused or reparented the rifle"):
		return
	if not _assert_true(MotionRig.CANDIDATES == ["A", "B", "C"], "motion candidates must be A, B, and C"):
		return
	var low_outer_arm_bones: PackedInt32Array = rig._influence_bones(Vector3(-0.45, 0.84, 0.04))
	if not _assert_true(low_outer_arm_bones[0] == MotionRig.FIRING_UPPER_BONE, "low outer firing-arm vertices were reassigned to the leg chain"):
		return
	var pelvis_bones: PackedInt32Array = rig._influence_bones(Vector3(-0.12, 0.84, 0.0))
	if not _assert_true(pelvis_bones[0] == MotionRig.LEFT_THIGH_BONE, "central pelvis vertices do not blend into the left leg chain"):
		return

	var profile_a: Dictionary = rig.candidate_profile("A")
	var profile_b: Dictionary = rig.candidate_profile("B")
	var profile_c: Dictionary = rig.candidate_profile("C")
	for key in ["stride", "lift", "recoil_degrees"]:
		if not _assert_true(float(profile_c[key]) > float(profile_a[key]) and float(profile_a[key]) > float(profile_b[key]), "%s must be ordered C > A > B" % key):
			return

	for candidate in MotionRig.CANDIDATES:
		rig.apply_motion(candidate, 0.25, -1.0)
		await process_frame
		var left_forward := rig.left_foot_position()
		var right_back := rig.right_foot_position()
		if not _assert_true(left_forward.z > MotionRig.LEFT_ANKLE_REST.z and right_back.z < MotionRig.RIGHT_ANKLE_REST.z, "%s gait phase 0.25 does not alternate foot travel" % candidate):
			return
		if not _assert_true(left_forward.y >= rig.floor_height() - 0.0001 and right_back.y >= rig.floor_height() - 0.0001, "%s gait phase 0.25 penetrates the floor" % candidate):
			return
		rig.apply_motion(candidate, 0.75, -1.0)
		await process_frame
		var left_back := rig.left_foot_position()
		var right_forward := rig.right_foot_position()
		if not _assert_true(left_back.z < MotionRig.LEFT_ANKLE_REST.z and right_forward.z > MotionRig.RIGHT_ANKLE_REST.z, "%s gait phase 0.75 does not reverse foot travel" % candidate):
			return
		if not _assert_true(left_back.y >= rig.floor_height() - 0.0001 and right_forward.y >= rig.floor_height() - 0.0001, "%s gait phase 0.75 penetrates the floor" % candidate):
			return
		rig.apply_motion(candidate, 0.0, 0.5)
		await process_frame
		if not _assert_true(is_equal_approx(rig.current_weapon_angle_degrees(), float(rig.candidate_profile(candidate)["recoil_degrees"])), "%s peak recoil does not match its declared profile" % candidate):
			return
		if not _assert_true(rig.firing_hand_error() <= MotionRig.CONTACT_TOLERANCE, "%s recoil detached the firing hand" % candidate):
			return
		if not _assert_true(rig.support_hand_error() <= MotionRig.CONTACT_TOLERANCE, "%s recoil detached the support hand" % candidate):
			return
		if not _assert_true(rig.stock_contact_error() <= MotionRig.CONTACT_TOLERANCE, "%s recoil detached the stock" % candidate):
			return

	var player_source := FileAccess.get_file_as_string(PLAYER_SCRIPT_PATH)
	if not _assert_true(not player_source.contains("PlayerMotionRig"), "review motion rig leaked into Player.gd"):
		return
	rig.queue_free()
	await process_frame
	print("TEST PASS: PlayerMotionRigTest %d" % assertions)
	quit(0)
