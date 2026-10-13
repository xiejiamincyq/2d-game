extends SceneTree
## Run this external author fixture from a standalone PCK directory, not --path.
var checks := 0
var failures := 0
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("TIDE SHELL PACK FAIL: "+label)
func _initialize() -> void:
	await process_frame
	check(not FileAccess.file_exists("res://docs/art/native-manifests/tide_shell_paper_v2.json") and not ResourceLoader.exists("res://scripts/art/BakeTideShellActions.gd"),"author/source workspace accidentally available")
	var path := "res://scenes/actors/native/tide_shell_paper_v2.tscn"
	check(ResourceLoader.exists(path),"compiled native resource missing")
	if failures: quit(1); return
	var view = load(path).instantiate()
	root.add_child(view)
	check(view.skeleton.get_bone_count()==25 and view.get_node("Facing/Skin").get_bone_count()==25,"serialized weights lost")
	check(view.get_node("Facing/Skin").texture==null and view.player.get_animation_list().size()==14,"raster or incomplete animation fallback")
	for action in ["ripple","pincer","salt"]:
		for stage in ["warning","attack","recovery"]:
			var clip: String = action+"_"+stage
			check(view.sample_clip(clip,0.1),"compiled action cannot play")
			check(view.transform==Transform2D.IDENTITY,"packed motion changes physical root")
			view.cancel_action()
			for index in 25:
				var bone: Bone2D = view.skeleton.get_bone(index)
				check(bone.transform.is_equal_approx(bone.rest),"packed cancellation leaves residue")
	check(view.skeleton.get_node_or_null("Torso/Head/Jaw/SaltOrigin") is Marker2D,"serialized jaw socket missing")
	var geometry = load("res://scripts/components/TideShellWaveGeometry.gd")
	check(geometry.hit_fraction(Vector2.ZERO,Vector2.ZERO,Vector2.ZERO,110,350,19)<0,"compiled hollow-wave centre damaged")
	check(is_equal_approx(geometry.hit_fraction(Vector2.ZERO,Vector2(200,0),Vector2(200,0),110,350,19),71.0/240),"compiled continuous contact lost")
	view.free()
	await process_frame
	if not failures: print("TIDE SHELL PACK PASS: %d" % checks)
	quit(1 if failures else 0)
