extends SceneTree
## Catches missing weights, page/cloak articulation and root/death regressions.
const Validator = preload("res://scripts/art/NativeArtValidator.gd")
const SCENE := "res://scenes/actors/native/spore_archivist_paper_v1.tscn"
var checks := 0
var failures := 0
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("TEST FAIL: SporeArchivistResourceTest "+label)
func _initialize() -> void:
	await process_frame
	check(ResourceLoader.exists(SCENE),"independent archivist skeleton missing")
	if failures:
		quit(1)
		return
	var entry = JSON.parse_string(FileAccess.get_file_as_string("res://docs/art/native-manifests/spore_archivist_paper_v1.json"))
	check(entry is Dictionary and entry.role=="boss" and Validator.new().validate_entry(entry).is_empty(),"opaque weighted non-attack boss contract")
	if failures:
		quit(1)
		return
	var view = load(SCENE).instantiate()
	root.add_child(view)
	check(view.skeleton.get_bone_count()==27,"canopy/book/cloak/limbs not separately weighted")
	check(view.player.get_animation_list().size()==5,"large attack animation gate bypassed")
	for clip in view.player.get_animation_list():
		check(str(clip) in ["idle","walk","hit","entrance","death"],"premature large attack resource")
	for path in ["Torso/Book/Spine/IndexOrigin","Torso/Head/Cap/SporeOrigin","Torso/SporeSatchel/ColonyOrigin"]:
		check(view.skeleton.get_node_or_null(path) is Marker2D,"future dispatch locator absent")
	for clip in ["idle","walk","hit","entrance"]:
		check(view.sample_clip(clip,view.player.get_animation(clip).length*0.45),"non-attack sample missing")
		check(view.transform==Transform2D.IDENTITY,"animation drives physical root")
		view.cancel_action()
		for index in 27:
			check(view.skeleton.get_bone(index).transform.is_equal_approx(view.skeleton.get_bone(index).rest),"cancel leaves distorted rest joint")
	view.sample_clip("walk",0.26)
	check(absf(view.skeleton.get_node("Torso/LegR/ShinR").rotation)>0.05,"walk reduced to whole-body bob")
	check(absf(view.skeleton.get_node("Torso/CloakL/HemL").rotation)>0.025,"cloak hem lacks delayed articulation")
	view.sample_clip("idle",1)
	check(absf(view.skeleton.get_node("Torso/Book/PageL").rotation)>0.02,"held book is rigid decoration")
	check(view.skeleton.get_node("Torso/Book/PageL").rotation*view.skeleton.get_node("Torso/Book/PageR").rotation<0,"book pages don't open relative to spine")
	view.sample_clip("death",0.84)
	check(not view.cancel_action() and not view.sample_clip("idle",0),"death resurrects")
	view.free()
	if not failures:
		print("TEST PASS: SporeArchivistResourceTest %d" % checks)
	quit(1 if failures else 0)
