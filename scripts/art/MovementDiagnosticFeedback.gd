extends "res://scripts/systems/CombatFeedback.gd"

# Fixture only. All damage, VFX, camera and audio feedback remains inherited.
var track := "D"
var events: Array[Dictionary] = []
var cleanup_active := false
var _reset_in_progress := false

func reset_all() -> void:
	_reset_in_progress = true
	super.reset_all()
	_reset_in_progress = false

func request_hit_stop(requested_ms: float) -> float:
	var before := Engine.time_scale
	var granted := super.request_hit_stop(requested_ms) if track == "R" else 0.0
	events.append({"event": "request", "physics_frame": Engine.get_physics_frames(),
		"ticks_usec": Time.get_ticks_usec(), "requested_ms": requested_ms, "granted_ms": granted,
		"scale_before": before, "scale_after": Engine.time_scale, "suppressed_by_fixture": track == "D"})
	return granted

func _restore_time_scale() -> void:
	var before := Engine.time_scale
	var owned := _owns_time_scale
	super._restore_time_scale()
	if owned or not is_equal_approx(before, Engine.time_scale):
		events.append({"event": "restore", "physics_frame": Engine.get_physics_frames(),
			"ticks_usec": Time.get_ticks_usec(), "scale_before": before, "scale_after": Engine.time_scale,
			"reason": "cleanup" if cleanup_active else ("state_reset" if _reset_in_progress else "natural_expiry")})
