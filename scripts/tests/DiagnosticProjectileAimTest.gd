extends SceneTree
const Aim = preload("res://scripts/art/DiagnosticProjectileAim.gd")
var assertions := 0
var failures := 0
func check(ok: bool, label: String) -> void:
	assertions += 1
	if not ok: failures += 1; push_error("TEST FAIL: DiagnosticProjectileAimTest " + label)
func trajectory(r: Vector2, target_velocity: Vector2, player_velocity: Vector2, speed: float, inheritance: float = 0.30) -> void:
	var v := target_velocity - player_velocity * inheritance
	var result := Aim.intercept(r, v, speed)
	check(result.solved and result.time > 0 and result.time <= 6, "positive reachable intercept")
	var bullet: Vector2 = (player_velocity * inheritance + result.direction * speed) * result.time
	var target: Vector2 = r + target_velocity * result.time
	check(bullet.distance_to(target) < 0.001, "actual inherited velocity reaches target")
	check(result.direction.is_finite() and is_equal_approx(result.direction.length(), 1.0), "finite unit normal aim")
func _initialize() -> void:
	trajectory(Vector2(300,0),Vector2.ZERO,Vector2.ZERO,300)
	trajectory(Vector2(300,0),Vector2.ZERO,Vector2(0,300),300)
	trajectory(Vector2(300,100),Vector2(20,60),Vector2(-80,160),300)
	trajectory(Vector2(300,0),Vector2(-300,0),Vector2.ZERO,300)
	trajectory(Vector2(300,0),Vector2.ZERO,Vector2(0,235),620,1.0)
	trajectory(Vector2(300,150),Vector2(-30,40),Vector2(0,300),620,1.0)
	var direct_miss := (Vector2(0,300)*0.30 + Vector2.RIGHT*300) - Vector2(300,0)
	check(direct_miss.length()>80,"direct point aim misses lateral inherited trajectory")
	var impossible := Aim.intercept(Vector2(300,0),Vector2(400,0),300)
	check(not impossible.solved and impossible.direction==Vector2.RIGHT,"receding faster target uses direct finite fallback")
	check(not Aim.intercept(Vector2(3000,0),Vector2.ZERO,300).solved,"lifetime-limited intercept")
	check(not Aim.intercept(Vector2.ZERO,Vector2.ZERO,300).solved,"coincident target no positive intercept")
	check(not Aim.intercept(Vector2(300,0),Vector2.ZERO,0).solved,"zero speed rejected")
	check(not Aim.intercept(Vector2(300,0),Vector2.ZERO,-3).solved,"negative speed rejected")
	var invalid := Aim.intercept(Vector2.INF,Vector2.ZERO,300)
	check(not invalid.solved and invalid.direction.is_finite(),"invalid input never poisons pointer")
	check(not Aim.intercept(Vector2.RIGHT,Vector2.INF,300).solved,"invalid target velocity rejected")
	check(not Aim.intercept(Vector2.RIGHT,Vector2.ZERO,INF).solved,"infinite speed rejected")
	check(not Aim.intercept(Vector2.RIGHT,Vector2.ZERO,300,0).solved,"invalid lifetime rejected")
	if failures==0: print("TEST PASS: DiagnosticProjectileAimTest %d"%assertions)
	quit(1 if failures>0 else 0)
