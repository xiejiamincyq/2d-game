extends SceneTree
## Offline original authoring. Bone-only visual clips never dispatch damage.
const BASE := "res://scenes/actors/native/spore_archivist_paper_v1.tscn"
const BASE_LIBRARY := "res://assets/art/actors/native/spore_archivist_motion_v1.tres"
const OUTPUT_SCENE := "res://scenes/actors/native/spore_archivist_paper_v2.tscn"
const OUTPUT_LIBRARY := "res://assets/art/actors/native/spore_archivist_motion_v2.tres"
const MANIFEST := "res://docs/art/native-manifests/spore_archivist_paper_v2.json"
const Gate = preload("res://scripts/art/NativeRigCheckpoint.gd")
const STEM := "Facing/Skeleton2D/"
## Motion durations only: future combat/landing timing needs independent tests.
const DURATIONS := {"page":[0.22,0.40,0.52],"seal":[0.24,0.28,0.64],"brood":[0.26,0.36,0.70]}
const CHARGED := {
	"page":{"Torso:rotation":-0.025,"Torso/Book:position":Vector2(0,15),"Torso/Book:rotation":-0.06,"Torso/Book/PageL:rotation":-0.18,"Torso/Book/PageR:rotation":0.18,"Torso/Book/Spine:rotation":-0.06,"Torso/ArmL:rotation":-0.12,"Torso/ArmR:rotation":0.12,"Torso/ArmL/ForearmL:rotation":0.14,"Torso/ArmR/ForearmR:rotation":-0.14,"Torso/Head:rotation":0.035,"Torso/CloakL/HemL:rotation":-0.06,"Torso/CloakR/HemR:rotation":0.06},
	"seal":{"Torso:position":Vector2(0,-16),"Torso/Head:rotation":-0.035,"Torso/Head/Cap:scale":Vector2(0.99,0.94),"Torso/Head/GillL:rotation":-0.10,"Torso/Head/GillR:rotation":0.10,"Torso/ArmL:rotation":0.12,"Torso/ArmR:rotation":-0.12,"Torso/ArmL/ForearmL:rotation":-0.15,"Torso/ArmR/ForearmR:rotation":0.15,"Torso/Book/Spine:rotation":0.06,"Torso/CloakL/HemL:rotation":0.04,"Torso/CloakR/HemR:rotation":-0.04},
	"brood":{"Torso:rotation":-0.035,"Torso/SporeSatchel:scale":Vector2(1.04,0.91),"Torso/SporeSatchel:rotation":0.08,"Torso/Book:rotation":-0.07,"Torso/Book/Spine:rotation":-0.14,"Torso/ArmL:rotation":-0.13,"Torso/ArmL/ForearmL:rotation":0.16,"Torso/ArmR:rotation":0.10,"Torso/ArmR/ForearmR:rotation":-0.16,"Torso/Head:rotation":0.04,"Torso/CloakL/HemL:rotation":0.06,"Torso/CloakR/HemR:rotation":-0.04}}
const RELEASED := {
	"page":{"Torso:rotation":0.025,"Torso/Book:position":Vector2(0,18),"Torso/Book:rotation":0.06,"Torso/Book/PageL:rotation":0.34,"Torso/Book/PageR:rotation":-0.30,"Torso/Book/Spine:rotation":0.07,"Torso/ArmL:rotation":0.10,"Torso/ArmR:rotation":-0.10,"Torso/ArmL/ForearmL:rotation":-0.12,"Torso/ArmR/ForearmR:rotation":0.12,"Torso/Head:rotation":-0.035,"Torso/CloakL/HemL:rotation":0.06,"Torso/CloakR/HemR:rotation":-0.06},
	"seal":{"Torso:position":Vector2(0,-20),"Torso/Head:rotation":0.035,"Torso/Head/Cap:scale":Vector2(1.01,1.04),"Torso/Head/GillL:rotation":0.14,"Torso/Head/GillR:rotation":-0.14,"Torso/ArmL:rotation":-0.12,"Torso/ArmR:rotation":0.12,"Torso/ArmL/ForearmL:rotation":0.12,"Torso/ArmR/ForearmR:rotation":-0.12,"Torso/Book/Spine:rotation":-0.06,"Torso/CloakL/HemL:rotation":-0.04,"Torso/CloakR/HemR:rotation":0.04},
	"brood":{"Torso:rotation":0.035,"Torso/SporeSatchel:scale":Vector2(0.97,1.08),"Torso/SporeSatchel:rotation":-0.08,"Torso/Book:rotation":0.07,"Torso/Book/Spine:rotation":0.12,"Torso/ArmL:rotation":0.12,"Torso/ArmL/ForearmL:rotation":-0.14,"Torso/ArmR:rotation":-0.10,"Torso/ArmR/ForearmR:rotation":0.14,"Torso/Head:rotation":-0.04,"Torso/CloakL/HemL:rotation":-0.06,"Torso/CloakR/HemR:rotation":0.04}}
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
	var from: Dictionary = {} if stage==0 else CHARGED[action] if stage==1 else RELEASED[action]
	var to: Dictionary = CHARGED[action] if stage==0 else RELEASED[action] if stage==1 else {}
	var paths: Array = CHARGED[action].keys()
	paths.sort()
	for path in paths:
		var track := clip.add_track(Animation.TYPE_VALUE)
		clip.track_set_path(track,NodePath(STEM+path))
		var rest = rest_value(view,path)
		clip.track_insert_key(track,0,from.get(path,rest))
		if stage==1:
			if action=="page" and ("PageL" in path or "PageR" in path):
				# Actual leaf flick and counter-flick; not a rigid-book/root rotation.
				clip.track_insert_key(track,clip.length*0.20,to[path])
				clip.track_insert_key(track,clip.length*0.55,from[path])
				clip.track_insert_key(track,clip.length*0.80,to[path])
			else: clip.track_insert_key(track,clip.length*0.38,to.get(path,rest))
		clip.track_insert_key(track,clip.length,to.get(path,rest))
	return clip
func run() -> void:
	var entry: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
	var errors := Gate.new().validate_entry(entry)
	if not errors.is_empty(): push_error(str(errors)); quit(1); return
	if FileAccess.file_exists(OUTPUT_SCENE) or FileAccess.file_exists(OUTPUT_LIBRARY):
		push_error("Author a fresh resource revision; existing output must not be overwritten")
		quit(1)
		return
	var before := {BASE:FileAccess.get_sha256(BASE),BASE_LIBRARY:FileAccess.get_sha256(BASE_LIBRARY)}
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
	if ResourceSaver.save(library,OUTPUT_LIBRARY,ResourceSaver.FLAG_CHANGE_PATH)!=OK: view.free(); quit(1); return
	library = load(OUTPUT_LIBRARY)
	player.remove_animation_library("")
	player.add_animation_library("",library)
	view.cancel_action()
	player.stop()
	var packed := PackedScene.new()
	var ok := packed.pack(view)==OK and ResourceSaver.save(packed,OUTPUT_SCENE)==OK
	for path in before: ok = ok and FileAccess.get_sha256(path)==before[path]
	view.free()
	await process_frame
	if ok: print("SPORE ARCHIVIST BAKE PASS: 27 bones, 9 original action clips, 3 semantic sockets, frozen v1 preserved")
	quit(0 if ok else 1)
