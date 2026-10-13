extends SceneTree
## New, editable actions for the actual standalone Boss; not ordinary OVERSEER.
const SCENE := "res://scenes/actors/native/root_overseer_paper_v1.tscn"
const MANIFEST := "res://docs/art/native-manifests/root_overseer_paper_v1.json"
const Validator = preload("res://scripts/art/NativeArtValidator.gd")
const ACTIONS := {
	"sweep":[1.0,0.22,0.28],"slam":[1.1,0.14,0.34],
	"aimed_fan":[0.45,0.55,0.24],"twin_spiral":[0.28,1.26,0.28],
	"broken_ring":[0.32,1.3,0.3]
}
var checks := 0
var failures := 0
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error("TEST FAIL: LegacyOverseerActionsResourceTest "+label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	check(ResourceLoader.exists(SCENE) and FileAccess.file_exists(MANIFEST),"standalone Boss has no separately authored 21-clip native resource")
	if failures: quit(1); return
	var entry: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
	check(Validator.new().validate_entry(entry).is_empty(),"original, editable post-rig contract rejected")
	var missing_proof := entry.duplicate(true); missing_proof.erase("rig_checkpoint")
	check(not Validator.new().validate_entry(missing_proof).is_empty(),"attack resource bypasses frozen rig checkpoint")
	var view = load(SCENE).instantiate(); root.add_child(view)
	check(view.skeleton.get_bone_count()==23 and view.player.get_animation_list().size()==21,"covered topology or full action count changed")
	check(view.player.get_animation_library("").resource_path=="res://assets/art/actors/native/root_overseer_motion_v1.tres","actions are not an external editable library")
	var clips := {"phase_transition":0.65}
	for kind in ACTIONS:
		for index in 3: clips[kind+"_"+["warning","attack","recovery"][index]] = ACTIONS[kind][index]
	for name in clips:
		check(view.player.has_animation(name),"actual action missing "+name)
		if not view.player.has_animation(name): continue
		var clip: Animation = view.player.get_animation(name)
		check(is_equal_approx(clip.length,clips[name]) and clip.loop_mode==Animation.LOOP_NONE,"nominal action duration/loop differs "+name)
		view.cancel_action()
		var before: Array[Transform2D] = []
		for index in 23: before.append(view.skeleton.get_bone(index).transform)
		check(view.sample_clip(name,clip.length*0.55),"action sampling refused "+name)
		var changed := 0
		for index in 23:
			if not before[index].is_equal_approx(view.skeleton.get_bone(index).transform): changed += 1
		check(changed>=3 and view.position==Vector2.ZERO and view.rotation==0 and view.modulate.a==1,"action is only root motion/fade or lacks articulation "+name)
		for track in clip.get_track_count():
			check(clip.track_get_type(track)==Animation.TYPE_VALUE and str(clip.track_get_path(track)).begins_with("Facing/Skeleton2D/"),"action has gameplay/event/physical track "+name)
		check(view.cancel_action(),"live action cannot be canceled "+name)
		for index in 23: check(view.skeleton.get_bone(index).transform.is_equal_approx(view.skeleton.get_bone(index).rest),"cancel retains joint pose "+name)
	view.sample_clip("death",0.5)
	check(not view.cancel_action() and not view.sample_clip("slam_attack",0),"dead body can resume attacking")
	view.free(); await process_frame
	if not failures: print("TEST PASS: LegacyOverseerActionsResourceTest %d"%checks)
	quit(1 if failures else 0)
