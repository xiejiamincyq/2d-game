extends SceneTree

const LobScript = preload("res://scripts/components/LobbedProjectile.gd")
const EnemyScript = preload("res://scripts/actors/Enemy.gd")
var assertions := 0

class Target extends Node2D:
	var damage_taken := 0.0
	var hits := 0
	func take_damage(amount: float) -> void:
		damage_taken += amount
		hits += 1

func check(condition: bool, message: String) -> bool:
	assertions += 1
	if condition:
		return true
	push_error("TEST FAIL: LobberVisualLifecycleTest: " + message)
	quit(1)
	return false

func _initialize() -> void:
	var probe := LobScript.new()
	var tint_ok := probe.tint.is_equal_approx(Color("f27a4b"))
	probe.free()
	if not check(tint_ok, "lob warning must use the approved coral danger palette, not legacy purple"):
		return
	if not await test_impact_clock_and_cleanup():
		return
	for parent_z in [22, 50]:
		for distance in [0.0, 72.0, 72.1]:
			if not await test_case(parent_z, distance):
				return
	print("TEST PASS: LobberVisualLifecycleTest %d" % assertions)
	quit(0)

func test_case(parent_z: int, distance: float) -> bool:
	var shots := Node2D.new()
	shots.z_index = parent_z
	root.add_child(shots)
	var target := Target.new()
	target.position = Vector2(40 + distance, 30)
	root.add_child(target)
	var enemy := EnemyScript.new()
	enemy.setup(EnemyScript.EnemyKind.LOBBER, 2, shots, target)
	root.add_child(enemy)
	await process_frame
	enemy.set_physics_process(false)
	enemy.position = Vector2(180, 20)
	enemy.ranged_target_position = Vector2(40, 30)
	enemy._fire_lobber(target)
	var lob := shots.get_child(0)
	lob.set_physics_process(false)
	if not check(lob.tint.is_equal_approx(Color("f27a4b")), "actual enemy launch did not keep coral"):
		return false
	if not check(lob.damage == 16.0 and lob.flight_duration == 0.9 and lob.splash_radius == 72.0, "enemy mechanical overrides changed"):
		return false
	lob._physics_process(0.45)
	if not check(lob.global_position.is_equal_approx(Vector2(110, 25)) and target.hits == 0 and not lob.is_queued_for_deletion(), "half-flight position or timing changed"):
		return false
	if not check(lob.landing_fill.global_position.is_equal_approx(Vector2(40, 30)) and not lob.landing_fill.z_as_relative and lob.landing_fill.z_index == -1, "ground fill drifted or rose over actors"):
		return false
	lob._physics_process(0.449999)
	if not check(target.hits == 0 and not lob.is_queued_for_deletion(), "lob exploded before the 0.9-second boundary"):
		return false
	lob._physics_process(lob.flight_duration - lob.elapsed)
	var hit := distance <= 72.0
	if not check(target.hits == (1 if hit else 0) and target.damage_taken == (16.0 if hit else 0.0) and lob.is_queued_for_deletion(), "exact damage radius or landing moment changed"):
		return false
	var impact := shots.get_node_or_null("LobImpact")
	if not check(impact != null, "landing has no surviving visual impact after projectile deletion"):
		return false
	impact.set_process(false)
	if not check(impact.global_position.is_equal_approx(Vector2(40, 30)) and impact.radius == 72.0 and impact.z_index == -1 and not impact.z_as_relative, "impact footprint changed or non-colliding ground rim inherited the foreground parent"):
		return false
	await process_frame
	if not check(not is_instance_valid(lob) and is_instance_valid(impact), "impact did not survive only as a short independent visual"):
		return false
	impact._process(impact.DURATION + 0.001)
	if not check(impact.is_queued_for_deletion() and target.hits == (1 if hit else 0), "visual impact lingered or applied gameplay damage"):
		return false
	shots.queue_free()
	target.queue_free()
	enemy.queue_free()
	await process_frame
	return true

func test_impact_clock_and_cleanup() -> bool:
	var holder := Node2D.new()
	holder.process_mode = Node.PROCESS_MODE_PAUSABLE
	root.add_child(holder)
	var impact := LobScript.ImpactVisual.new()
	holder.add_child(impact)
	if not check(impact.DURATION == 0.20 and impact.elapsed == 0.0, "impact must start with a fixed 0.20-second process lifetime"):
		return false
	paused = true
	await create_timer(0.06, true, false, true).timeout
	var did_pause := is_instance_valid(impact) and impact.elapsed == 0.0
	paused = false
	if not check(did_pause, "impact continued aging during tree pause"):
		return false
	await process_frame
	await process_frame
	if not check(is_instance_valid(impact) and impact.elapsed > 0.0, "impact did not resume its process clock"):
		return false
	holder.free()
	if not check(not is_instance_valid(impact), "parent cleanup left an orphan impact"):
		return false
	holder = Node2D.new()
	root.add_child(holder)
	impact = LobScript.ImpactVisual.new()
	impact.set_process(false)
	holder.add_child(impact)
	impact._process(0.199)
	if not check(not impact.is_queued_for_deletion() and is_equal_approx(impact.elapsed, 0.199), "impact disappeared before its lifetime boundary"):
		return false
	impact._process(0.001001)
	if not check(impact.is_queued_for_deletion(), "impact did not expire at its fixed lifetime boundary"):
		return false
	await process_frame
	if not check(not is_instance_valid(impact), "expired impact remained in tree"):
		return false
	holder.free()
	return true
