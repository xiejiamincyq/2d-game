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
	var frozen := Policy.new()
	var escaped := false
	for _frame in range(180):
		var direction := frozen.choose_direction(Vector2(221, 313), Vector2.RIGHT, [], func(_p: Vector2) -> bool: return true)
		escaped = escaped or direction.dot(Vector2.RIGHT) < 0.7
	check(escaped, "stationary pilot must break repeated forward input instead of oscillating forever")
	var replay_a := Policy.new(31)
	var replay_b := Policy.new(31)
	var varied := Policy.new(72)
	var same_sequence := true
	var different_sequence := false
	var respects_corridor := true
	var corridor := Policy.new(31)
	for _frame in range(720):
		var a := replay_a.choose_direction(Vector2.ZERO, Vector2.RIGHT, [], func(_p: Vector2) -> bool: return true)
		var b := replay_b.choose_direction(Vector2.ZERO, Vector2.RIGHT, [], func(_p: Vector2) -> bool: return true)
		var c := varied.choose_direction(Vector2.ZERO, Vector2.RIGHT, [], func(_p: Vector2) -> bool: return true)
		same_sequence = same_sequence and a == b
		different_sequence = different_sequence or a != c
		respects_corridor = respects_corridor and corridor.choose_direction(Vector2.ZERO, Vector2.RIGHT, [], only_up) == Vector2.UP
	check(same_sequence, "same pilot seed and observation sequence reproduce exploration and escape")
	check(different_sequence, "different pilot seeds vary exploration instead of sharing one frozen path")
	check(respects_corridor, "random escape still rejects blocked headings")
	check(replay_a.escape_events > 0 and replay_a.random_heading_changes == 10, "escape and periodic random exploration are observable")
	var travelling := Policy.new(31)
	var wandered := false
	for frame in range(720):
		var direction := travelling.choose_direction(Vector2(frame * 4, 0), Vector2.RIGHT, [], func(_p: Vector2) -> bool: return true)
		wandered = wandered or absf(direction.y) > 0.1
	check(wandered and travelling.escape_events == 0, "free travel visibly varies its input without needing a stuck escape")
	print("TEST %s: NaturalRunPolicyTest %d" % ["PASS" if failures == 0 else "FAIL", assertions])
	quit(0 if failures == 0 else 1)
