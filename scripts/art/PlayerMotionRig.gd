extends "res://scripts/art/PlayerGripRig.gd"
class_name PlayerMotionRig

const CANDIDATES := ["A", "B", "C"]

const LEFT_THIGH_BONE := 8
const LEFT_SHIN_BONE := 9
const LEFT_FOOT_BONE := 10
const RIGHT_THIGH_BONE := 11
const RIGHT_SHIN_BONE := 12
const RIGHT_FOOT_BONE := 13

const LEFT_HIP_REST := Vector3(-0.17, 0.82, 0.0)
const LEFT_KNEE_REST := Vector3(-0.18, 0.45, 0.20)
const LEFT_ANKLE_REST := Vector3(-0.18, 0.10, 0.045)
const RIGHT_HIP_REST := Vector3(0.17, 0.82, 0.0)
const RIGHT_KNEE_REST := Vector3(0.18, 0.45, 0.20)
const RIGHT_ANKLE_REST := Vector3(0.18, 0.10, 0.045)

const _PROFILES := {
	"A": {
		"label": "stable_tactical_stride",
		"stride": 0.15,
		"lift": 0.085,
		"recoil_degrees": 4.0,
		"shoulder_bob": 0.010,
	},
	"B": {
		"label": "compact_shuffle",
		"stride": 0.09,
		"lift": 0.045,
		"recoil_degrees": 2.0,
		"shoulder_bob": 0.006,
	},
	"C": {
		"label": "aggressive_advance",
		"stride": 0.22,
		"lift": 0.125,
		"recoil_degrees": 7.0,
		"shoulder_bob": 0.018,
	},
}

var leg_weighted_vertex_count := 0
var blended_leg_vertex_count := 0
var leg_region_vertex_count := 0
var underweighted_leg_vertex_count := 0

func candidate_profile(candidate: String) -> Dictionary:
	if candidate not in CANDIDATES:
		push_error("Unknown player motion candidate: " + candidate)
		return {}
	return (_PROFILES[candidate] as Dictionary).duplicate(true)

func apply_motion(candidate: String, gait_phase: float, recoil_phase: float = -1.0) -> void:
	if candidate not in CANDIDATES:
		push_error("Unknown player motion candidate: " + candidate)
		return
	var profile := _PROFILES[candidate] as Dictionary
	var wrapped_phase := fposmod(gait_phase, 1.0)
	var gait_wave := sin(wrapped_phase * TAU)
	var stride := float(profile["stride"])
	var lift := float(profile["lift"])
	var left_target := LEFT_ANKLE_REST + Vector3(0.0, maxf(gait_wave, 0.0) * lift, gait_wave * stride)
	var right_target := RIGHT_ANKLE_REST + Vector3(0.0, maxf(-gait_wave, 0.0) * lift, -gait_wave * stride)
	_pose_arm(
		LEFT_THIGH_BONE,
		LEFT_SHIN_BONE,
		LEFT_FOOT_BONE,
		LEFT_HIP_REST,
		LEFT_KNEE_REST,
		LEFT_ANKLE_REST,
		left_target,
		Vector3(-0.36, 0.43, 0.42),
		Basis.IDENTITY
	)
	_pose_arm(
		RIGHT_THIGH_BONE,
		RIGHT_SHIN_BONE,
		RIGHT_FOOT_BONE,
		RIGHT_HIP_REST,
		RIGHT_KNEE_REST,
		RIGHT_ANKLE_REST,
		right_target,
		Vector3(0.36, 0.43, 0.42),
		Basis.IDENTITY
	)
	var recoil_degrees := 0.0
	if recoil_phase >= 0.0:
		recoil_degrees = sin(clampf(recoil_phase, 0.0, 1.0) * PI) * float(profile["recoil_degrees"])
	var shoulder_bob := absf(gait_wave) * float(profile["shoulder_bob"])
	_apply_weapon_pose(recoil_degrees, Vector3(0.0, shoulder_bob, 0.0))

func left_foot_position() -> Vector3:
	return skeleton.get_bone_global_pose(LEFT_FOOT_BONE).origin

func right_foot_position() -> Vector3:
	return skeleton.get_bone_global_pose(RIGHT_FOOT_BONE).origin

func floor_height() -> float:
	return minf(LEFT_ANKLE_REST.y, RIGHT_ANKLE_REST.y)

func _build_skeleton() -> Skeleton3D:
	var result: Skeleton3D = super._build_skeleton()
	result.name = "PlayerMotionReviewSkeleton"
	_add_bone(result, "left_thigh", ROOT_BONE, Transform3D(Basis.IDENTITY, LEFT_HIP_REST))
	_add_bone(result, "left_shin", LEFT_THIGH_BONE, Transform3D(Basis.IDENTITY, LEFT_KNEE_REST - LEFT_HIP_REST))
	_add_bone(result, "left_foot", LEFT_SHIN_BONE, Transform3D(Basis.IDENTITY, LEFT_ANKLE_REST - LEFT_KNEE_REST))
	_add_bone(result, "right_thigh", ROOT_BONE, Transform3D(Basis.IDENTITY, RIGHT_HIP_REST))
	_add_bone(result, "right_shin", RIGHT_THIGH_BONE, Transform3D(Basis.IDENTITY, RIGHT_KNEE_REST - RIGHT_HIP_REST))
	_add_bone(result, "right_foot", RIGHT_SHIN_BONE, Transform3D(Basis.IDENTITY, RIGHT_ANKLE_REST - RIGHT_KNEE_REST))
	return result

func _build_skinned_body() -> MeshInstance3D:
	leg_weighted_vertex_count = 0
	blended_leg_vertex_count = 0
	leg_region_vertex_count = 0
	underweighted_leg_vertex_count = 0
	return super._build_skinned_body()

func _bone_influences(point: Vector3) -> PackedFloat32Array:
	if not _uses_leg_influences(point):
		return super._bone_influences(point)
	var leg_presence := 1.0 - smoothstep(0.72, 0.94, point.y)
	var foot_raw := 1.0 - smoothstep(0.08, 0.27, point.y)
	var shin_raw := smoothstep(0.04, 0.20, point.y) * (1.0 - smoothstep(0.43, 0.66, point.y))
	var thigh_raw := smoothstep(0.30, 0.60, point.y)
	var raw_total := foot_raw + shin_raw + thigh_raw
	if raw_total <= 0.000001 or leg_presence <= 0.000001:
		return PackedFloat32Array([1.0, 0.0, 0.0, 0.0])
	return PackedFloat32Array([
		1.0 - leg_presence,
		leg_presence * thigh_raw / raw_total,
		leg_presence * shin_raw / raw_total,
		leg_presence * foot_raw / raw_total,
	])

func _influence_bones(point: Vector3) -> PackedInt32Array:
	if not _uses_leg_influences(point):
		return super._influence_bones(point)
	if point.x < 0.0:
		return PackedInt32Array([LEFT_THIGH_BONE, LEFT_SHIN_BONE, LEFT_FOOT_BONE])
	return PackedInt32Array([RIGHT_THIGH_BONE, RIGHT_SHIN_BONE, RIGHT_FOOT_BONE])

func _record_influence_metrics(point: Vector3, influences: PackedFloat32Array) -> void:
	if not _uses_leg_influences(point):
		super._record_influence_metrics(point, influences)
		return
	var leg_weight := influences[1] + influences[2] + influences[3]
	if leg_weight > 0.25:
		leg_weighted_vertex_count += 1
	if point.y < 0.72:
		leg_region_vertex_count += 1
		if leg_weight < 0.80:
			underweighted_leg_vertex_count += 1
	var active_leg_weights := 0
	for influence_index in range(1, 4):
		if influences[influence_index] > 0.01:
			active_leg_weights += 1
	if active_leg_weights >= 2 or (influences[0] > 0.001 and influences[0] < 0.999):
		blended_leg_vertex_count += 1

func _uses_leg_influences(point: Vector3) -> bool:
	if point.y < 0.78:
		return true
	if point.y >= 0.90:
		return false
	return absf(point.x) <= 0.38
