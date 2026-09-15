extends SceneTree

const LobScript = preload("res://scripts/components/LobbedProjectile.gd")
const OutlineScript = preload("res://scripts/art/PlayerOcclusionOutline.gd")
var assertions := 0

class Target extends Node2D:
	var damage_taken := 0.0
	func take_damage(amount: float) -> void:
		damage_taken += amount

func check(condition: bool, message: String) -> bool:
	assertions += 1
	if condition:
		return true
	push_error("TEST FAIL: ProjectileLandingVisualTest: " + message)
	quit(1)
	return false

func _initialize() -> void:
	var shots := Node2D.new()
	shots.z_index = OutlineScript.OUTLINE_Z_INDEX + 1
	root.add_child(shots)
	var target := Target.new()
	root.add_child(target)
	var lob := LobScript.new()
	lob.process_mode = Node.PROCESS_MODE_DISABLED
	lob.configure(Vector2(180, 20), Vector2(40, 30), target)
	shots.add_child(lob)
	await process_frame
	var fill := lob.get_node_or_null("LandingFill") as Node2D
	if not check(fill != null, "landing fill is not separated from projectile and boundary"):
		return
	if not check(shots.z_index + fill.z_index < OutlineScript.OUTLINE_Z_INDEX and shots.z_index > OutlineScript.OUTLINE_Z_INDEX, "fill/contour/boundary layer order incorrect"):
		return
	if not check(fill.global_position.is_equal_approx(lob.target_position), "fill center does not match landing target"):
		return
	lob._physics_process(lob.flight_duration * 0.5)
	if not check(fill.global_position.is_equal_approx(lob.target_position), "fill drifted while projectile moved"):
		return
	if not check(target.damage_taken == 0.0 and not lob.is_queued_for_deletion(), "layer change altered flight timing"):
		return
	target.position = lob.target_position + Vector2(lob.splash_radius, 0)
	lob._physics_process(lob.flight_duration * 0.5)
	if not check(target.damage_taken == lob.damage and lob.is_queued_for_deletion(), "landing damage or radius boundary changed"):
		return
	await process_frame
	if not check(not is_instance_valid(fill), "landing fill survived its projectile"):
		return
	var outside := LobScript.new()
	outside.process_mode = Node.PROCESS_MODE_DISABLED
	outside.configure(Vector2.ZERO, Vector2.ZERO, target)
	shots.add_child(outside)
	target.position = Vector2(outside.splash_radius + 0.1, 0)
	var before := target.damage_taken
	outside._physics_process(outside.flight_duration)
	if not check(target.damage_taken == before, "outside-radius target received damage"):
		return
	shots.queue_free()
	target.queue_free()
	await process_frame
	print("TEST PASS: ProjectileLandingVisualTest %d" % assertions)
	quit(0)
