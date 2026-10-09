extends SceneTree

const Enemy = preload("res://scripts/actors/Enemy.gd")
const Projectile = preload("res://scripts/components/Projectile.gd")
const BossProjectile = preload("res://scripts/components/BossProjectile.gd")
var assertions := 0
var failures := 0

func check(condition: bool, message: String) -> void:
	assertions += 1
	if not condition:
		failures += 1
		push_error("TEST FAIL: EnemyAttackFeedbackTest: " + message)

func _initialize() -> void:
	var actor := Enemy.new()
	actor.setup(0, 0, null)
	root.add_child(actor)
	actor.process_mode = Node.PROCESS_MODE_DISABLED
	var target := Node2D.new()
	root.add_child(target)
	var attack: RefCounted = actor.basic_attack
	check(attack.has_method("get_attack_strokes"), "locked attack has no active-only AB strokes")
	if attack.has_method("get_attack_strokes"):
		for angle in [0.0, PI * 0.5, PI, PI * 1.5]:
			for move in range(2):
				actor.position = Vector2.ZERO
				target.position = Vector2.RIGHT.rotated(angle) * 100
				attack.cancel()
				attack.begin(actor, target, move)
				var polygon: PackedVector2Array = attack.get_warning_polygon(actor)
				check(attack.get_attack_strokes(actor).is_empty(), "decorative attack strokes shown during warning")
				for fraction in [0.0, 0.25, 0.5, 0.75, 0.99]:
					attack.stage = attack.Stage.ACTIVE
					attack.elapsed = attack.get_warning_duration() + attack.get_active_duration() * fraction
					actor.position = attack.direction * 99.0 * fraction if move == 1 else Vector2.ZERO
					var strokes: Array = attack.get_attack_strokes(actor)
					check(strokes.size() <= 1, "compact stroke budget exceeded")
					for stroke: PackedVector2Array in strokes:
						for point: Vector2 in stroke:
							check(Geometry2D.is_point_in_polygon(point + actor.position, polygon), "stroke center outside locked warning geometry")
					check(attack.get_warning_polygon(actor) == polygon if move == 0 else attack.origin == Vector2.ZERO, "visual rewrote locked attack origin/domain")
				attack.stage = attack.Stage.RECOVERY
				check(attack.get_attack_strokes(actor).is_empty(), "strokes linger during recovery")
				attack.cancel()
				check(attack.get_attack_strokes(actor).is_empty(), "canceled attack left strokes")
	for script in [Projectile, BossProjectile]:
		var shot: Area2D = script.new()
		check(shot.has_method("get_hostile_trail_points"), "hostile shot missing directional trail geometry")
		if shot.has_method("get_hostile_trail_points"):
			shot.velocity = Vector2(100, 0)
			check(shot.get_hostile_trail_points().is_empty(), "friendly shot got hostile trail")
			shot.target_group = &"player"
			for heading in [Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT, Vector2.UP]:
				shot.velocity = heading * 100
				var points: PackedVector2Array = shot.get_hostile_trail_points()
				check(points.size() == 3, "hostile trail is not one bounded wedge")
				for point: Vector2 in points:
					check(point.dot(heading) <= 0 and point.length() <= shot.radius * 4.3, "trail ahead of head or beyond visual cap")
			shot.velocity = Vector2.ZERO
			check(shot.get_hostile_trail_points().is_empty(), "stationary shot invented direction")
		shot.free()
	actor.free()
	target.free()
	await process_frame
	print("TEST %s: EnemyAttackFeedbackTest %d" % ["PASS" if failures == 0 else "FAIL", assertions])
	quit(0 if failures == 0 else 1)
