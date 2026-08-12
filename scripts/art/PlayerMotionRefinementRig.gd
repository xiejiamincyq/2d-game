extends "res://scripts/art/PlayerMotionRig.gd"
class_name PlayerMotionRefinementRig

const REFINEMENTS := ["A1", "A2", "A3"]
const SELECTED_BASE_PROFILE := "A"
const PELVIS_PIVOT := Vector3(0.0, 0.82, 0.0)
const TORSO_PIVOT := Vector3(0.0, 1.08, 0.02)

const _REFINEMENT_PROFILES := {
	"A1": {
		"label": "restrained_stability",
		"hip_shift": 0.012,
		"pelvis_yaw_degrees": 0.8,
		"torso_counter_yaw_degrees": 1.4,
		"lateral_lean_degrees": 0.7,
		"recoil_torso_degrees": 0.8,
		"recovery": "fast",
	},
	"A2": {
		"label": "realistic_load_transfer",
		"hip_shift": 0.028,
		"pelvis_yaw_degrees": 1.8,
		"torso_counter_yaw_degrees": 3.2,
		"lateral_lean_degrees": 1.8,
		"recoil_torso_degrees": 1.6,
		"recovery": "two_stage",
	},
	"A3": {
		"label": "strong_motion_statement",
		"hip_shift": 0.045,
		"pelvis_yaw_degrees": 3.0,
		"torso_counter_yaw_degrees": 5.5,
		"lateral_lean_degrees": 3.2,
		"recoil_torso_degrees": 2.5,
		"recovery": "overshoot",
	},
}

var _current_mechanics := {
	"hip_shift_x": 0.0,
	"pelvis_yaw_degrees": 0.0,
	"torso_yaw_degrees": 0.0,
	"lateral_lean_degrees": 0.0,
	"recoil_curve": 0.0,
	"recoil_torso_degrees": 0.0,
}

func refinement_profile(refinement: String) -> Dictionary:
	if refinement not in REFINEMENTS:
		push_error("Unknown player motion refinement: " + refinement)
		return {}
	var result := (_REFINEMENT_PROFILES[refinement] as Dictionary).duplicate(true)
	var base_profile := candidate_profile(SELECTED_BASE_PROFILE)
	result["stride"] = base_profile["stride"]
	result["lift"] = base_profile["lift"]
	result["shoulder_bob"] = base_profile["shoulder_bob"]
	result["recoil_degrees"] = base_profile["recoil_degrees"]
	return result

func current_mechanics() -> Dictionary:
	return _current_mechanics.duplicate(true)

func apply_refinement(refinement: String, gait_phase: float, recoil_phase: float = -1.0) -> void:
	if refinement not in REFINEMENTS:
		push_error("Unknown player motion refinement: " + refinement)
		return
	var profile := refinement_profile(refinement)
	var wrapped_phase := fposmod(gait_phase, 1.0)
	var gait_wave := sin(wrapped_phase * TAU)
	var left_target := LEFT_ANKLE_REST + Vector3(
		0.0,
		maxf(gait_wave, 0.0) * float(profile["lift"]),
		gait_wave * float(profile["stride"])
	)
	var right_target := RIGHT_ANKLE_REST + Vector3(
		0.0,
		maxf(-gait_wave, 0.0) * float(profile["lift"]),
		-gait_wave * float(profile["stride"])
	)
	var hip_shift_x := -gait_wave * float(profile["hip_shift"])
	var pelvis_yaw := gait_wave * float(profile["pelvis_yaw_degrees"])
	var torso_yaw := -gait_wave * float(profile["torso_counter_yaw_degrees"])
	var lateral_lean := -gait_wave * float(profile["lateral_lean_degrees"])
	var recoil_curve := _recoil_curve(refinement, recoil_phase)
	var recoil_degrees := recoil_curve * float(profile["recoil_degrees"])
	var recoil_torso := recoil_curve * float(profile["recoil_torso_degrees"])

	var pelvis_basis := Basis(Vector3.UP, deg_to_rad(pelvis_yaw))
	var pelvis_transform := _pivoted_transform(
		pelvis_basis,
		PELVIS_PIVOT,
		Vector3(hip_shift_x, 0.0, 0.0)
	)
	var torso_basis := (
		Basis(Vector3.UP, deg_to_rad(torso_yaw))
		* Basis(Vector3.FORWARD, deg_to_rad(lateral_lean))
		* Basis(Vector3.RIGHT, deg_to_rad(recoil_torso))
	)
	var torso_transform := _pivoted_transform(
		torso_basis,
		TORSO_PIVOT,
		Vector3(hip_shift_x * 0.55, 0.0, 0.0)
	)
	skeleton.set_bone_global_pose(ROOT_BONE, pelvis_transform)
	skeleton.set_bone_global_pose(TORSO_BONE, torso_transform)
	_pose_leg_chain(
		LEFT_THIGH_BONE,
		LEFT_SHIN_BONE,
		LEFT_FOOT_BONE,
		pelvis_transform,
		LEFT_HIP_REST,
		LEFT_KNEE_REST,
		LEFT_ANKLE_REST,
		left_target,
		Vector3(-0.36, 0.43, 0.42)
	)
	_pose_leg_chain(
		RIGHT_THIGH_BONE,
		RIGHT_SHIN_BONE,
		RIGHT_FOOT_BONE,
		pelvis_transform,
		RIGHT_HIP_REST,
		RIGHT_KNEE_REST,
		RIGHT_ANKLE_REST,
		right_target,
		Vector3(0.36, 0.43, 0.42)
	)
	var shoulder_bob := absf(gait_wave) * float(profile["shoulder_bob"])
	_apply_weapon_pose_transformed(
		recoil_degrees,
		Vector3(0.0, shoulder_bob, 0.0),
		torso_transform
	)
	_current_mechanics = {
		"hip_shift_x": hip_shift_x,
		"pelvis_yaw_degrees": pelvis_yaw,
		"torso_yaw_degrees": torso_yaw,
		"lateral_lean_degrees": lateral_lean,
		"recoil_curve": recoil_curve,
		"recoil_torso_degrees": recoil_torso,
	}

func _pose_leg_chain(
	thigh_bone: int,
	shin_bone: int,
	foot_bone: int,
	pelvis_transform: Transform3D,
	hip_rest: Vector3,
	knee_rest: Vector3,
	plant_rest: Vector3,
	target_plant: Vector3,
	hint: Vector3
) -> void:
	_pose_arm(
		thigh_bone,
		shin_bone,
		foot_bone,
		pelvis_transform * hip_rest,
		pelvis_transform * knee_rest,
		pelvis_transform * plant_rest,
		target_plant,
		pelvis_transform * hint,
		Basis.IDENTITY
	)

func _pivoted_transform(basis: Basis, pivot: Vector3, offset: Vector3) -> Transform3D:
	return Transform3D(basis, pivot + offset - basis * pivot)

func _recoil_curve(refinement: String, recoil_phase: float) -> float:
	if recoil_phase < 0.0:
		return 0.0
	var phase := clampf(recoil_phase, 0.0, 1.0)
	if phase <= 0.35:
		return phase / 0.35
	if refinement == "A1":
		return maxf(0.0, 1.0 - (phase - 0.35) / 0.30)
	if refinement == "A2":
		if phase <= 0.70:
			return 1.0 - 0.75 * ((phase - 0.35) / 0.35)
		return 0.25 * (1.0 - (phase - 0.70) / 0.30)
	if phase <= 0.72:
		return 1.0 - 1.15 * ((phase - 0.35) / 0.37)
	return -0.15 * (1.0 - (phase - 0.72) / 0.28)
