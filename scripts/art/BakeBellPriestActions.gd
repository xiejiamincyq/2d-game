extends SceneTree
## Original offline bone authoring; no combat events or physical-root tracks.
const BASE := "res://scenes/actors/native/bell_priest_paper_v1.tscn"
const BASE_LIBRARY := "res://assets/art/actors/native/bell_priest_motion_v1.tres"
const OUTPUT_SCENE := "res://scenes/actors/native/bell_priest_paper_v2.tscn"
const OUTPUT_LIBRARY := "res://assets/art/actors/native/bell_priest_motion_v2.tres"
const MANIFEST := "res://docs/art/native-manifests/bell_priest_paper_v2.json"
const Gate = preload("res://scripts/art/NativeRigCheckpoint.gd")
const STEM := "Facing/Skeleton2D/"
# Visual durations, not validated future damage/dodge timings.
const DURATIONS := {"bell":[0.24,0.42,0.54],"pendant":[0.22,0.56,0.66],"crown":[0.24,0.48,0.60]}
const CHARGED := {
	"bell":{"Torso:position":Vector2(0,-12),"Torso:rotation":-0.02,"Torso/Bell:position":Vector2(0,-7),"Torso/Bell:rotation":-0.08,"Torso/Bell/Clapper:rotation":-0.28,"Torso/Bell/LipL:rotation":-0.05,"Torso/Bell/LipR:rotation":0.05,"Torso/ArmL:rotation":-0.10,"Torso/ArmR:rotation":0.10,"Torso/ArmL/ForearmL:rotation":0.13,"Torso/ArmR/ForearmR:rotation":-0.13,"Torso/ArmL/ForearmL/HandL/ChainL:rotation":0.10,"Torso/ArmR/ForearmR/HandR/ChainR:rotation":-0.10,"Torso/Head:rotation":0.035,"Torso/RibsL:rotation":0.04,"Torso/RibsR:rotation":-0.04},
	"pendant":{"Torso:position":Vector2(0,-12),"Torso:rotation":-0.025,"Torso/Head:rotation":0.025,"Torso/RibsL:rotation":0.05,"Torso/RibsR:rotation":-0.05,"Torso/ArmL:rotation":-0.12,"Torso/ArmR:rotation":0.12,"Torso/ArmL/ForearmL:rotation":0.16,"Torso/ArmR/ForearmR:rotation":-0.16,"Torso/ArmL/ForearmL/HandL:rotation":-0.07,"Torso/ArmR/ForearmR/HandR:rotation":0.07,"Torso/ArmL/ForearmL/HandL/ChainL:rotation":0.20,"Torso/ArmR/ForearmR/HandR/ChainR:rotation":-0.20,"Torso/ArmL/ForearmL/HandL/ChainL/PendantL:rotation":-0.28,"Torso/ArmR/ForearmR/HandR/ChainR/PendantR:rotation":0.28},
	"crown":{"Torso:position":Vector2(0,-14),"Torso/Head:rotation":-0.035,"Torso/Head/Crown:position":Vector2(0,-23),"Torso/Head/Crown:rotation":-0.08,"Torso/Head/Crown:scale":Vector2(0.99,0.97),"Torso/Head/Mask:rotation":0.03,"Torso/RibsL:rotation":0.09,"Torso/RibsR:rotation":-0.09,"Torso/ArmL:rotation":-0.10,"Torso/ArmR:rotation":0.10,"Torso/ArmL/ForearmL:rotation":0.14,"Torso/ArmR/ForearmR:rotation":-0.14,"Torso/ArmL/ForearmL/HandL:rotation":-0.07,"Torso/ArmR/ForearmR/HandR:rotation":0.07,"Torso/Bell:rotation":-0.04}}
const PEAK := {
	"bell":{"Torso:position":Vector2(0,-8),"Torso:rotation":0.025,"Torso/Bell:position":Vector2(0,6),"Torso/Bell:rotation":0.12,"Torso/Bell/Clapper:rotation":0.42,"Torso/Bell/LipL:rotation":0.11,"Torso/Bell/LipR:rotation":-0.11,"Torso/ArmL:rotation":0.08,"Torso/ArmR:rotation":-0.08,"Torso/ArmL/ForearmL:rotation":-0.10,"Torso/ArmR/ForearmR:rotation":0.10,"Torso/ArmL/ForearmL/HandL/ChainL:rotation":-0.13,"Torso/ArmR/ForearmR/HandR/ChainR:rotation":0.13,"Torso/Head:rotation":-0.035,"Torso/RibsL:rotation":-0.04,"Torso/RibsR:rotation":0.04},
	"pendant":{"Torso:position":Vector2(0,-11),"Torso:rotation":0.025,"Torso/Head:rotation":-0.025,"Torso/RibsL:rotation":-0.06,"Torso/RibsR:rotation":0.06,"Torso/ArmL:rotation":0.52,"Torso/ArmR:rotation":-0.52,"Torso/ArmL/ForearmL:rotation":0.32,"Torso/ArmR/ForearmR:rotation":-0.32,"Torso/ArmL/ForearmL/HandL:rotation":0.12,"Torso/ArmR/ForearmR/HandR:rotation":-0.12,"Torso/ArmL/ForearmL/HandL/ChainL:rotation":0.42,"Torso/ArmR/ForearmR/HandR/ChainR:rotation":-0.42,"Torso/ArmL/ForearmL/HandL/ChainL/PendantL:rotation":-0.54,"Torso/ArmR/ForearmR/HandR/ChainR/PendantR:rotation":0.54},
	"crown":{"Torso:position":Vector2(0,-16),"Torso/Head:rotation":0.04,"Torso/Head/Crown:position":Vector2(0,-27),"Torso/Head/Crown:rotation":0.12,"Torso/Head/Crown:scale":Vector2(1.06,1.02),"Torso/Head/Mask:rotation":-0.05,"Torso/RibsL:rotation":-0.24,"Torso/RibsR:rotation":0.24,"Torso/ArmL:rotation":0.08,"Torso/ArmR:rotation":-0.08,"Torso/ArmL/ForearmL:rotation":-0.10,"Torso/ArmR/ForearmR:rotation":0.10,"Torso/ArmL/ForearmL/HandL:rotation":0.07,"Torso/ArmR/ForearmR/HandR:rotation":-0.07,"Torso/Bell:rotation":0.04}}
const RELEASED := {
	"bell":{"Torso:position":Vector2(0,-9),"Torso:rotation":0.015,"Torso/Bell:position":Vector2(0,2),"Torso/Bell:rotation":0.025,"Torso/Bell/Clapper:rotation":0.10,"Torso/Bell/LipL:rotation":0.025,"Torso/Bell/LipR:rotation":-0.025,"Torso/ArmL:rotation":0.03,"Torso/ArmR:rotation":-0.03,"Torso/ArmL/ForearmL:rotation":-0.04,"Torso/ArmR/ForearmR:rotation":0.04,"Torso/ArmL/ForearmL/HandL/ChainL:rotation":-0.03,"Torso/ArmR/ForearmR/HandR/ChainR:rotation":0.03,"Torso/Head:rotation":-0.02,"Torso/RibsL:rotation":-0.02,"Torso/RibsR:rotation":0.02},
	"pendant":{"Torso:position":Vector2(0,-9),"Torso:rotation":0.015,"Torso/Head:rotation":-0.02,"Torso/RibsL:rotation":-0.025,"Torso/RibsR:rotation":0.025,"Torso/ArmL:rotation":-0.08,"Torso/ArmR:rotation":0.08,"Torso/ArmL/ForearmL:rotation":0.11,"Torso/ArmR/ForearmR:rotation":-0.11,"Torso/ArmL/ForearmL/HandL:rotation":-0.05,"Torso/ArmR/ForearmR/HandR:rotation":0.05,"Torso/ArmL/ForearmL/HandL/ChainL:rotation":0.12,"Torso/ArmR/ForearmR/HandR/ChainR:rotation":-0.12,"Torso/ArmL/ForearmL/HandL/ChainL/PendantL:rotation":-0.20,"Torso/ArmR/ForearmR/HandR/ChainR/PendantR:rotation":0.20},
	"crown":{"Torso:position":Vector2(0,-11),"Torso/Head:rotation":0.02,"Torso/Head/Crown:position":Vector2(0,-21),"Torso/Head/Crown:rotation":0.04,"Torso/Head/Crown:scale":Vector2(1.02,1.01),"Torso/Head/Mask:rotation":-0.015,"Torso/RibsL:rotation":-0.06,"Torso/RibsR:rotation":0.06,"Torso/ArmL:rotation":0.025,"Torso/ArmR:rotation":-0.025,"Torso/ArmL/ForearmL:rotation":-0.03,"Torso/ArmR/ForearmR:rotation":0.03,"Torso/ArmL/ForearmL/HandL:rotation":0.025,"Torso/ArmR/ForearmR/HandR:rotation":-0.025,"Torso/Bell:rotation":0.015}}
func _initialize() -> void: call_deferred("run")
func rest_value(view: Node,path: String) -> Variant:
	var rest: Transform2D = view.get_node(STEM+path.get_slice(":",0)).rest
	match path.get_slice(":",1):
		"position": return rest.origin
		"scale": return rest.get_scale()
		_: return rest.get_rotation()
func make_clip(view: Node,action: String,stage: int) -> Animation:
	var clip := Animation.new(); clip.resource_name = action+"_"+["warning","attack","recovery"][stage]; clip.length = DURATIONS[action][stage]
	var from: Dictionary = {} if stage==0 else CHARGED[action] if stage==1 else RELEASED[action]
	var to: Dictionary = CHARGED[action] if stage==0 else RELEASED[action] if stage==1 else {}
	var paths: Array = CHARGED[action].keys(); paths.sort()
	for path in paths:
		var track := clip.add_track(Animation.TYPE_VALUE); clip.track_set_path(track,NodePath(STEM+path))
		var rest = rest_value(view,path); clip.track_insert_key(track,0,from.get(path,rest))
		if stage==1:
			if action=="crown":
				for phase in [0.16,0.46,0.76]: clip.track_insert_key(track,clip.length*phase,PEAK[action][path])
				for phase in [0.30,0.60]: clip.track_insert_key(track,clip.length*phase,from[path])
			else:
				clip.track_insert_key(track,clip.length*(0.16 if action=="bell" else 0.24),PEAK[action][path])
				if action=="pendant": clip.track_insert_key(track,clip.length*0.50,PEAK[action][path])
			clip.track_insert_key(track,clip.length*0.90,to[path])
		clip.track_insert_key(track,clip.length,to.get(path,rest))
	return clip
func run() -> void:
	var entry: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
	if not Gate.new().validate_entry(entry).is_empty(): push_error("Unreviewed bell-priest resource request"); quit(1); return
	if FileAccess.file_exists(OUTPUT_SCENE) or FileAccess.file_exists(OUTPUT_LIBRARY): push_error("Fresh resource revision required; never overwrite approved output"); quit(1); return
	var before := {BASE:FileAccess.get_sha256(BASE),BASE_LIBRARY:FileAccess.get_sha256(BASE_LIBRARY)}
	var view: Node2D = load(BASE).instantiate(); root.add_child(view)
	view.visual_bounds_padding = 64 # GPU: old16 + measured43.343 + <5px safety; visual only.
	var player: AnimationPlayer = view.get_node("AnimationPlayer"); player.stop(); player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	var library: AnimationLibrary = player.get_animation_library("").duplicate(true)
	for action in DURATIONS:
		for stage in 3:
			var clip := make_clip(view,action,stage); library.add_animation(clip.resource_name,clip)
	if ResourceSaver.save(library,OUTPUT_LIBRARY,ResourceSaver.FLAG_CHANGE_PATH)!=OK: view.free(); quit(1); return
	library = load(OUTPUT_LIBRARY); player.remove_animation_library(""); player.add_animation_library("",library)
	view.cancel_action(); player.stop()
	var packed := PackedScene.new(); var ok := packed.pack(view)==OK and ResourceSaver.save(packed,OUTPUT_SCENE)==OK
	for path in before: ok = ok and FileAccess.get_sha256(path)==before[path]
	view.free(); await process_frame
	if ok: print("BELL PRIEST BAKE PASS: 26 bones, 9 original action clips, frozen v1 preserved")
	quit(0 if ok else 1)
