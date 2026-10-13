extends SceneTree
## Offline original action authoring. The frozen anatomy/base clips stay intact.
const BASE := "res://scenes/actors/native/tide_shell_paper_v1.tscn"
const OUTPUT_SCENE := "res://scenes/actors/native/tide_shell_paper_v2.tscn"
const OUTPUT_LIBRARY := "res://assets/art/actors/native/tide_shell_motion_v2.tres"
const MANIFEST := "res://docs/art/native-manifests/tide_shell_paper_v2.json"
const Gate = preload("res://scripts/art/NativeRigCheckpoint.gd")
const STEM := "Facing/Skeleton2D/"
const DURATIONS := {"ripple":[0.28,0.72,0.60],"pincer":[0.24,0.36,0.58],"salt":[0.26,0.18,0.62]}
const CHARGED := {
	"ripple":{"Torso:position":Vector2(0,0),"Torso/Carapace:scale":Vector2(1.06,0.95),"Torso/Tail:rotation":0.12,"Torso/LegFL:rotation":-0.16,"Torso/LegFR:rotation":0.16,"Torso/LegBL:rotation":-0.12,"Torso/LegBR:rotation":0.12,"Torso/Head/EyeStalkL:rotation":0.14,"Torso/Head/EyeStalkR:rotation":-0.14},
	"pincer":{"Torso:rotation":-0.04,"Torso/ShoulderL:rotation":0.14,"Torso/ShoulderR:rotation":-0.14,"Torso/ShoulderL/ArmL:rotation":0.34,"Torso/ShoulderR/ArmR:rotation":-0.34,"Torso/ShoulderL/ArmL/PincerL:rotation":-0.16,"Torso/ShoulderR/ArmR/PincerR:rotation":0.16,"Torso/Head:rotation":0.04,"Torso/LegFL/ShinFL:rotation":0.10,"Torso/LegFR/ShinFR:rotation":-0.10},
	"salt":{"Torso/Head:position":Vector2(0,-27),"Torso/Head/Jaw:rotation":-0.22,"Torso/Carapace:scale":Vector2(1.04,1.03),"Torso/Tail:rotation":-0.13,"Torso/Head/EyeStalkL:rotation":-0.13,"Torso/Head/EyeStalkR:rotation":0.13,"Torso/ShoulderL/ArmL:rotation":0.13,"Torso/ShoulderR/ArmR:rotation":-0.13}}
const IMPACT := {
	"ripple":{"Torso:position":Vector2(0,-8),"Torso/Carapace:scale":Vector2(0.98,1.05),"Torso/Tail:rotation":-0.13,"Torso/LegFL:rotation":0.14,"Torso/LegFR:rotation":-0.14,"Torso/LegBL:rotation":0.12,"Torso/LegBR:rotation":-0.12,"Torso/Head/EyeStalkL:rotation":-0.10,"Torso/Head/EyeStalkR:rotation":0.10},
	"pincer":{"Torso:rotation":0.04,"Torso/ShoulderL:rotation":-0.14,"Torso/ShoulderR:rotation":0.14,"Torso/ShoulderL/ArmL:rotation":-0.34,"Torso/ShoulderR/ArmR:rotation":0.34,"Torso/ShoulderL/ArmL/PincerL:rotation":0.16,"Torso/ShoulderR/ArmR/PincerR:rotation":-0.16,"Torso/Head:rotation":-0.04,"Torso/LegFL/ShinFL:rotation":-0.10,"Torso/LegFR/ShinFR:rotation":0.10},
	"salt":{"Torso/Head:position":Vector2(0,-22),"Torso/Head/Jaw:rotation":0.32,"Torso/Carapace:scale":Vector2(0.98,0.97),"Torso/Tail:rotation":0.10,"Torso/Head/EyeStalkL:rotation":0.10,"Torso/Head/EyeStalkR:rotation":-0.10,"Torso/ShoulderL/ArmL:rotation":-0.10,"Torso/ShoulderR/ArmR:rotation":0.10}}
func _initialize() -> void: call_deferred("run")
func rest_value(view: Node,path: String) -> Variant:
	var bone: Bone2D = view.get_node(STEM+path.get_slice(":",0))
	match path.get_slice(":",1):
		"position": return bone.rest.origin
		"scale": return bone.rest.get_scale()
		_: return bone.rest.get_rotation()
func make_clip(view: Node,action: String,stage: int) -> Animation:
	var clip := Animation.new()
	clip.resource_name = action+"_"+["warning","attack","recovery"][stage]
	clip.length = DURATIONS[action][stage]
	var from: Dictionary = {} if stage==0 else CHARGED[action] if stage==1 else IMPACT[action]
	var to: Dictionary = CHARGED[action] if stage==0 else IMPACT[action] if stage==1 else {}
	var paths: Array = CHARGED[action].keys()
	paths.sort()
	for path in paths:
		var track := clip.add_track(Animation.TYPE_VALUE)
		clip.track_set_path(track,NodePath(STEM+path))
		var rest = rest_value(view,path)
		clip.track_insert_key(track,0,from.get(path,rest))
		if stage==1 and action=="pincer" and ("Shoulder" in path):
			# Left stroke, return, then right stroke: separate actual joint arcs.
			var left: bool = "ShoulderL" in path
			clip.track_insert_key(track,clip.length*0.28,to[path] if left else from[path])
			clip.track_insert_key(track,clip.length*0.52,from[path])
			clip.track_insert_key(track,clip.length*0.80,to[path] if not left else from[path])
		else:
			if stage==1: clip.track_insert_key(track,clip.length*0.35,to.get(path,rest))
		clip.track_insert_key(track,clip.length,to.get(path,rest))
	return clip
func run() -> void:
	var entry: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
	var errors := Gate.new().validate_entry(entry)
	if not errors.is_empty(): push_error(str(errors)); quit(1); return
	var before := FileAccess.get_sha256(BASE)
	var view: Node2D = load(BASE).instantiate()
	root.add_child(view)
	var player: AnimationPlayer = view.get_node("AnimationPlayer")
	player.stop()
	player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	var library: AnimationLibrary = player.get_animation_library("").duplicate(true)
	for action in DURATIONS:
		for stage in 3:
			var clip := make_clip(view,action,stage)
			library.add_animation(clip.resource_name,clip)
	var socket := Marker2D.new()
	socket.name = "SaltOrigin"
	socket.position = Vector2(0,12)
	view.get_node(STEM+"Torso/Head/Jaw").add_child(socket)
	socket.owner = view
	if ResourceSaver.save(library,OUTPUT_LIBRARY,ResourceSaver.FLAG_CHANGE_PATH)!=OK: view.free(); quit(1); return
	library = load(OUTPUT_LIBRARY)
	player.remove_animation_library("")
	player.add_animation_library("",library)
	view.cancel_action()
	player.stop()
	var packed := PackedScene.new()
	var ok := packed.pack(view)==OK and ResourceSaver.save(packed,OUTPUT_SCENE)==OK and FileAccess.get_sha256(BASE)==before
	view.free()
	await process_frame
	if ok: print("TIDE SHELL BAKE PASS: 25 bones, 9 original action clips, salt socket, frozen v1 preserved")
	quit(0 if ok else 1)
