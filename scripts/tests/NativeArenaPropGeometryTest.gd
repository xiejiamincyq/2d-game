extends SceneTree
## Inspect polygons actually submitted by the production drawing callback.
const PropArt = preload("res://scripts/world/ArenaPaperPropArt.gd")
var checks := 0
var failures := 0
class RecordedProp extends PropArt:
	var submitted: Array[PackedVector2Array] = []
	func _shape(points: Array[Vector2], color: Color) -> void:
		submitted.append(PackedVector2Array(points))
		super._shape(points, color)
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("TEST FAIL: NativeArenaPropGeometryTest " + message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	for size in [Vector2(20,2000),Vector2(280,20),Vector2(40,36),Vector2(80,72),Vector2(160,144),Vector2(320,288)]:
		for role in [&"planter",&"greenhouse",&"tank",&"pipe"]:
			var actual := RecordedProp.new()
			actual.configure(size,role)
			root.add_child(actual)
			await process_frame
			await process_frame
			check(not actual.submitted.is_empty(), "actual draw callback absent %s/%s" % [role,size])
			for points in actual.submitted:
				var triangles := Geometry2D.triangulate_polygon(points)
				check(triangles.size()==(points.size()-2)*3, "non-simple or degenerate polygon %s/%s: %s" % [role,size,points])
				for point in points:
					check(point.is_finite() and actual.get_visual_rect().has_point(point), "polygon outside declared art bounds")
			actual.free()
	await process_frame
	if not failures: print("TEST PASS: NativeArenaPropGeometryTest %d" % checks)
	quit(1 if failures else 0)
