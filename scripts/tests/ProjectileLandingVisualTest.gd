extends SceneTree

const LobScript = preload("res://scripts/components/LobbedProjectile.gd")
const OutlineScript = preload("res://scripts/art/PlayerOcclusionOutline.gd")
const FLOOR_Z := -100
const ACTOR_BODY_Z := 0
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
	if not _test_effective_z_oracle():
		return
	for settings in [[22, 0, true, 0], [50, 7, true, 3], [50, 7, false, 3]]:
		if not await _test_landing_case(settings[0], settings[1], settings[2], settings[3]):
			return
	print("TEST PASS: ProjectileLandingVisualTest %d" % assertions)
	quit(0)

func _effective_z(item: CanvasItem) -> int:
	var value := item.z_index
	var ancestor: CanvasItem = item.get_parent() as CanvasItem
	var relative := item.z_as_relative
	while relative and ancestor != null:
		value += ancestor.z_index
		relative = ancestor.z_as_relative
		ancestor = ancestor.get_parent() as CanvasItem
	return value

func _test_effective_z_oracle() -> bool:
	var ancestor := Node2D.new()
	ancestor.z_index = 7
	root.add_child(ancestor)
	var parent := Node2D.new()
	parent.z_index = 50
	ancestor.add_child(parent)
	var child := Node2D.new()
	child.z_index = -2
	parent.add_child(child)
	if not check(_effective_z(child) == 55, "relative z oracle did not accumulate both ancestors"):
		return false
	parent.z_as_relative = false
	if not check(_effective_z(child) == 48, "absolute parent z did not stop ancestor accumulation"):
		return false
	child.z_as_relative = false
	if not check(_effective_z(child) == -2, "absolute child z still inherited its parent layer"):
		return false
	ancestor.free()
	return true

func _test_landing_case(parent_z: int, ancestor_z: int, parent_relative: bool, projectile_z: int) -> bool:
	var ancestor := Node2D.new()
	ancestor.z_index = ancestor_z
	root.add_child(ancestor)
	var shots := Node2D.new()
	shots.z_index = parent_z
	shots.z_as_relative = parent_relative
	ancestor.add_child(shots)
	var target := Target.new()
	root.add_child(target)
	var lob := LobScript.new()
	lob.process_mode = Node.PROCESS_MODE_DISABLED
	lob.z_index = projectile_z
	if parent_z == 50:
		# Match the live Enemy._fire_lobber override as well as component defaults.
		lob.damage = 16.0
		lob.flight_duration = 0.9
	lob.configure(Vector2(180, 20), Vector2(40, 30), target)
	shots.add_child(lob)
	await process_frame
	var fill := lob.get_node_or_null("LandingFill") as Node2D
	if not check(fill != null, "landing fill is not separated from projectile and boundary"):
		return false
	var expected_parent_z := parent_z + (ancestor_z if parent_relative else 0)
	if not check(_effective_z(shots) == expected_parent_z and _effective_z(lob) == expected_parent_z + projectile_z, "projectile hierarchy did not preserve relative/absolute parent z behavior"):
		return false
	if not check(_effective_z(shots) > OutlineScript.OUTLINE_Z_INDEX and _effective_z(lob) > OutlineScript.OUTLINE_Z_INDEX, "projectile parent and boundary must remain above outline layer 21"):
		return false
	var fill_z := _effective_z(fill)
	if not check(fill_z > FLOOR_Z and fill_z < ACTOR_BODY_Z, "LandingFill effective z=%d must lie strictly between floor -100 and actor body 0 (parent=%d ancestor=%d relative=%s)" % [fill_z, parent_z, ancestor_z, parent_relative]):
		return false
	if not check(fill.global_position.is_equal_approx(lob.target_position), "fill center does not match landing target"):
		return false
	lob._physics_process(lob.flight_duration * 0.5)
	if not check(fill.global_position.is_equal_approx(lob.target_position), "fill drifted while projectile moved"):
		return false
	if not check(target.damage_taken == 0.0 and not lob.is_queued_for_deletion(), "layer change altered flight timing"):
		return false
	target.position = lob.target_position + Vector2(lob.splash_radius, 0)
	lob._physics_process(lob.flight_duration * 0.5)
	if not check(target.damage_taken == lob.damage and lob.is_queued_for_deletion(), "landing damage or radius boundary changed"):
		return false
	await process_frame
	if not check(not is_instance_valid(fill), "landing fill survived its projectile"):
		return false
	var outside := LobScript.new()
	outside.process_mode = Node.PROCESS_MODE_DISABLED
	outside.configure(Vector2.ZERO, Vector2.ZERO, target)
	shots.add_child(outside)
	target.position = Vector2(outside.splash_radius + 0.1, 0)
	var before := target.damage_taken
	outside._physics_process(outside.flight_duration)
	if not check(target.damage_taken == before, "outside-radius target received damage"):
		return false
	ancestor.queue_free()
	target.queue_free()
	await process_frame
	return true
