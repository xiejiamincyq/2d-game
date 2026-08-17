extends SceneTree

const RefinementRig = preload("res://scripts/art/PlayerMotionRefinementRig.gd")
const PLAYER_SCRIPT_PATH := "res://scripts/actors/Player.gd"

var assertions := 0

func _assert_true(condition: bool, message: String) -> bool:
	assertions += 1
	if condition:
		return true
	push_error("TEST FAIL: PlayerMotionRefinementRigTest: " + message)
	quit(1)
	return false

func _initialize() -> void:
	var rig := RefinementRig.new()
	root.add_child(rig)
	if not _assert_true(rig.initialize(), "refinement review rig could not initialize"):
		return
	if not _assert_true(rig.skeleton.get_bone_count() == 14, "refinement must preserve the approved fourteen-bone motion rig"):
		return
	if not _assert_true(rig.body_mesh.mesh.surface_get_array_len(0) == 94652, "refinement changed the approved body vertex count"):
		return
	if not _assert_true(rig.body_mesh.mesh.surface_get_array_index_len(0) == 567888, "refinement changed the approved topology"):
		return
	if not _assert_true(RefinementRig.REFINEMENTS == ["A1", "A2", "A3"], "refinement candidates must be A1, A2, and A3"):
		return

	var base_profile: Dictionary = rig.candidate_profile("A")
	for refinement in RefinementRig.REFINEMENTS:
		var profile: Dictionary = rig.refinement_profile(refinement)
		if not _assert_true(float(profile["stride"]) == float(base_profile["stride"]), "%s changed approved A stride" % refinement):
			return
		if not _assert_true(float(profile["lift"]) == float(base_profile["lift"]), "%s changed approved A lift" % refinement):
			return
		if not _assert_true(float(profile["shoulder_bob"]) == float(base_profile["shoulder_bob"]), "%s changed approved A shoulder bob" % refinement):
			return
		if not _assert_true(float(profile["recoil_degrees"]) == float(base_profile["recoil_degrees"]), "%s changed approved A peak recoil" % refinement):
			return

	var a1: Dictionary = rig.refinement_profile("A1")
	var a2: Dictionary = rig.refinement_profile("A2")
	var a3: Dictionary = rig.refinement_profile("A3")
	for key in ["hip_shift", "pelvis_yaw_degrees", "torso_counter_yaw_degrees", "lateral_lean_degrees"]:
		if not _assert_true(float(a3[key]) > float(a2[key]) and float(a2[key]) > float(a1[key]), "%s mechanics amplitude must be ordered A3 > A2 > A1" % key):
			return

	var measured_hip_shifts := {}
	for refinement in RefinementRig.REFINEMENTS:
		rig.apply_refinement(refinement, 0.25, -1.0)
		await process_frame
		var mechanics: Dictionary = rig.current_mechanics()
		measured_hip_shifts[refinement] = absf(float(mechanics["hip_shift_x"]))
		if not _assert_true(float(mechanics["pelvis_yaw_degrees"]) * float(mechanics["torso_yaw_degrees"]) < 0.0, "%s torso does not counter-rotate against the pelvis" % refinement):
			return
		if not _assert_true(rig.left_foot_position().z > RefinementRig.LEFT_ANKLE_REST.z and rig.right_foot_position().z < RefinementRig.RIGHT_ANKLE_REST.z, "%s lost approved A alternating foot travel" % refinement):
			return
		if not _assert_true(rig.left_foot_position().y >= rig.floor_height() - 0.0001 and rig.right_foot_position().y >= rig.floor_height() - 0.0001, "%s gait penetrates the floor" % refinement):
			return
		if not _assert_contacts(rig, refinement + " gait"):
			return
	if not _assert_true(float(measured_hip_shifts["A3"]) > float(measured_hip_shifts["A2"]) and float(measured_hip_shifts["A2"]) > float(measured_hip_shifts["A1"]), "measured hip shift does not preserve A3 > A2 > A1"):
		return

	for refinement in RefinementRig.REFINEMENTS:
		rig.apply_refinement(refinement, 0.0, 0.35)
		await process_frame
		if not _assert_true(is_equal_approx(rig.current_weapon_angle_degrees(), 4.0), "%s does not preserve the approved four-degree peak recoil" % refinement):
			return
		if not _assert_contacts(rig, refinement + " peak recoil"):
			return
	rig.apply_refinement("A1", 0.0, 0.75)
	if not _assert_true(is_zero_approx(rig.current_weapon_angle_degrees()), "A1 should complete its fast recovery before phase 0.75"):
		return
	rig.apply_refinement("A2", 0.0, 0.75)
	if not _assert_true(rig.current_weapon_angle_degrees() > 0.0, "A2 should retain a small positive recovery tail at phase 0.75"):
		return
	rig.apply_refinement("A3", 0.0, 0.75)
	if not _assert_true(rig.current_weapon_angle_degrees() < 0.0, "A3 should show controlled recoil overshoot at phase 0.75"):
		return

	var player_source := FileAccess.get_file_as_string(PLAYER_SCRIPT_PATH)
	if not _assert_true(not player_source.contains("PlayerMotionRefinementRig"), "review refinement rig leaked into Player.gd"):
		return
	rig.queue_free()
	await process_frame
	print("TEST PASS: PlayerMotionRefinementRigTest %d" % assertions)
	quit(0)

func _assert_contacts(rig: Node, label: String) -> bool:
	if not _assert_true(rig.firing_hand_error() <= RefinementRig.CONTACT_TOLERANCE, label + " detached the firing hand"):
		return false
	if not _assert_true(rig.support_hand_error() <= RefinementRig.CONTACT_TOLERANCE, label + " detached the support hand"):
		return false
	return _assert_true(rig.stock_contact_error() <= RefinementRig.CONTACT_TOLERANCE, label + " detached the stock")
