extends SceneTree
const Shapes = preload("res://scenes/art/technical/SpaceCutterShapes.gd")
func _initialize() -> void:
	var checks := 0
	var failures := 0
	for patch in Shapes.new().make():
		checks += 1
		if Geometry2D.triangulate_polygon(patch.points).is_empty():
			failures += 1
			push_error("TEST FAIL: SpaceCutterGeometryTest untriangulatable "+str(patch.bone))
	if not failures and checks>0: print("TEST PASS: SpaceCutterGeometryTest %d" % checks)
	quit(1 if failures or checks==0 else 0)
