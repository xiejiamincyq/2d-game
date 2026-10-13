extends SceneTree
## External author fixture. Production resources must load from this PCK only.
var checks := 0
var failures := 0
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error("TEST FAIL: VerifyBellPriestPackedResources "+label)
func _initialize() -> void:
	await process_frame
	check(not FileAccess.file_exists("res://docs/art/native-manifests/bell_priest_paper_v2.json") and not ResourceLoader.exists("res://scripts/art/BakeBellPriestActions.gd"),"author source workspace accidentally available")
	var path := "res://scenes/actors/native/bell_priest_paper_v2.tscn"
	check(ResourceLoader.exists(path),"compiled original resource missing")
	if failures: quit(1); return
	var view = load(path).instantiate(); root.add_child(view)
	check(view.skeleton.get_bone_count()==26 and view.get_node("Facing/Skin").get_bone_count()==26,"serialized weighted anatomy lost")
	check(view.get_node("Facing/Skin").texture==null and view.player.get_animation_list().size()==14 and view.visual_bounds_padding==64,"raster/incomplete/framing fallback")
	var baseline = load("res://scenes/actors/native/bell_priest_paper_v1.tscn").instantiate(); root.add_child(baseline)
	var skin: Polygon2D = view.get_node("Facing/Skin"); var original: Polygon2D = baseline.get_node("Facing/Skin")
	check(view.transform==baseline.transform and view.get_node("Facing").transform==baseline.get_node("Facing").transform and skin.transform==original.transform,"body scale changed to conceal framing")
	check(skin.polygon==original.polygon and skin.vertex_colors==original.vertex_colors and skin.internal_vertex_count==original.internal_vertex_count,"original native body geometry changed")
	check(skin.polygons==original.polygons,"original native body triangulation changed")
	for index in 26:
		check(view.skeleton.get_bone(index).rest==baseline.skeleton.get_bone(index).rest,"original joint rest/scale changed")
		check(skin.get_bone_path(index)==original.get_bone_path(index) and skin.get_bone_weights(index)==original.get_bone_weights(index),"original weighted anatomy changed")
	baseline.free()
	for action in ["bell","pendant","crown"]:
		for stage in ["warning","attack","recovery"]:
			check(view.sample_clip(action+"_"+stage,0.1),"compiled action playback")
			check(view.transform==Transform2D.IDENTITY,"packed motion owns physical root")
			view.cancel_action()
			for index in 26: check(view.skeleton.get_bone(index).transform.is_equal_approx(view.skeleton.get_bone(index).rest),"packed joint residue")
	for locator in ["Torso/Bell/Clapper/BeatOrigin","Torso/Head/Crown/RecallOrigin","Torso/ArmL/ForearmL/HandL/ChainL/PendantL/PendantOrigin","Torso/ArmR/ForearmR/HandR/ChainR/PendantR/PendantOrigin"]:
		check(view.skeleton.get_node_or_null(locator) is Marker2D,"packed locator missing")
	view.free(); await process_frame
	if not failures: print("TEST PASS: VerifyBellPriestPackedResources %d"%checks)
	quit(1 if failures else 0)
