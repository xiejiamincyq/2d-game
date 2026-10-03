extends SceneTree

const Policy = preload("res://scripts/art/NaturalRunPolicy.gd")
var assertions := 0
var failures := 0

func check(value: bool, message: String) -> void:
	assertions += 1
	if not value:
		failures += 1
		push_error("TEST FAIL: NaturalRunPolicyTest: " + message)

func _initialize() -> void:
	var policy := Policy.new()
	check(policy.nonzero_aim(Vector2(12, -7), Vector2(12, -7)) == Vector2(512, -7), "empty collection goal uses nonzero fallback aim")
	check(policy.nonzero_aim(Vector2(12, -7), Vector2(70, 20)) == Vector2(70, 20), "normal aim is not changed")
	check(policy.choose_direction(Vector2.ZERO, Vector2.RIGHT, [], func(_p: Vector2) -> bool: return true) == Vector2.RIGHT, "empty arena follows navigation")
	var threat := [Vector2(35, 0)]
	check(policy.choose_direction(Vector2.ZERO, Vector2.RIGHT, threat, func(_p: Vector2) -> bool: return true).x < 0, "nearby enemy overrides forward goal")
	var only_up := func(p: Vector2) -> bool: return p.y < -20 and absf(p.x) < 1
	check(policy.choose_direction(Vector2.ZERO, Vector2.RIGHT, [], only_up) == Vector2.UP, "rejects blocked candidates")
	check(policy.choose_direction(Vector2.ZERO, Vector2.RIGHT, [], func(_p: Vector2) -> bool: return false) == Vector2.ZERO, "no safe candidate does not invent teleport")
	check(policy.choose_direction(Vector2.ZERO, Vector2.ZERO, [], func(_p: Vector2) -> bool: return true) == Vector2.ZERO, "no goal and no threat waits")
	var first := policy.choose_direction(Vector2(120, -50), Vector2(1, 1), [Vector2(180, -25)], func(_p: Vector2) -> bool: return true)
	for _repeat in range(5):
		check(policy.choose_direction(Vector2(120, -50), Vector2(1, 1), [Vector2(180, -25)], func(_p: Vector2) -> bool: return true) == first, "same observations produce same input")
	check(is_equal_approx(first.length(), 1.0), "movement remains normal input magnitude")
	print("TEST %s: NaturalRunPolicyTest %d" % ["PASS" if failures == 0 else "FAIL", assertions])
	quit(0 if failures == 0 else 1)
