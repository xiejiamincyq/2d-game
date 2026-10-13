extends SceneTree
const SOURCE := "res://scripts/components/TideShellWaveGeometry.gd"
var checks := 0
var failures := 0
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("TEST FAIL: TideShellWaveGeometryTest "+label)
func _initialize() -> void:
	check(ResourceLoader.exists(SOURCE),"continuous hollow-wave collision absent")
	if failures: quit(1); return
	var geometry = load(SOURCE)
	check(geometry.hit_fraction(Vector2.ZERO,Vector2.ZERO,Vector2.ZERO,110,350,19)<0,"hollow centre becomes a filled damage disk")
	check(is_equal_approx(geometry.hit_fraction(Vector2.ZERO,Vector2(200,0),Vector2(200,0),110,350,19),71.0/240),"one large step tunnels through target")
	check(geometry.hit_fraction(Vector2.ZERO,Vector2(120,0),Vector2(120,0),110,350,19)==0,"initial boundary overlap missed")
	check(geometry.hit_fraction(Vector2.ZERO,Vector2(500,0),Vector2(500,0),110,350,19)<0,"range exceeds outer edge")
	check(geometry.hit_fraction(Vector2.ZERO,Vector2(200,0),Vector2(500,0),110,350,19)<0,"escaping target gets swept as static")
	check(geometry.hit_fraction(Vector2.ZERO,Vector2(140,0),Vector2(50,0),110,350,19)>=0,"moving inward through advancing edge missed")
	check(geometry.hit_fraction(Vector2.ZERO,Vector2(-200,0),Vector2(200,0),100,100,5)>=0,"fast target crosses static ring without hit")
	check(geometry.hit_fraction(Vector2.ZERO,Vector2(-50,0),Vector2(50,0),100,100,5)<0,"safe chord inside ring damaged")
	check(is_equal_approx(geometry.hit_fraction(Vector2.ZERO,Vector2(-120,100),Vector2(120,100),100,100,0),0.5),"tangent contact missed")
	for shift in [Vector2.ZERO,Vector2(912,-147),Vector2(-508,999)]:
		for angle in [0.0,0.7,2.4,4.9]:
			var at: Vector2 = Vector2(200,0).rotated(angle)+shift
			check(is_equal_approx(geometry.hit_fraction(shift,at,at,110,350,19),71.0/240),"rotation/world translation changes hit")
	for rate in [30,60,120]:
		for distance in [80.0,110.0,160.0,200.0,280.0,380.0]:
			var earliest := -1.0
			var duration := 0.72
			var ticks := int(ceil(duration*rate))
			for tick in ticks:
				var a := minf(tick/float(rate),duration)
				var b := minf((tick+1)/float(rate),duration)
				var fraction: float = geometry.hit_fraction(Vector2.ZERO,Vector2(distance,0),Vector2(distance,0),110+240*a/duration,110+240*b/duration,19)
				if fraction>=0:
					earliest = a+(b-a)*fraction
					break
			var full: float = geometry.hit_fraction(Vector2.ZERO,Vector2(distance,0),Vector2(distance,0),110,350,19)
			check((earliest<0 and full<0) or absf(earliest-full*duration)<0.0001,"frame rate changes contact")
	for values in [[NAN,350,19],[110,INF,19],[-1,350,19],[110,350,-1],[350,110,19]]:
		check(geometry.hit_fraction(Vector2.ZERO,Vector2(200,0),Vector2(200,0),values[0],values[1],values[2])<0,"invalid wave accepted")
	check(geometry.hit_fraction(Vector2(NAN,0),Vector2(200,0),Vector2(200,0),110,350,19)<0,"invalid world coordinates accepted")
	if not failures: print("TEST PASS: TideShellWaveGeometryTest %d" % checks)
	quit(1 if failures else 0)
