extends SceneTree
## Author-only deterministic bake. Frozen v1 anatomy/noncombat motion untouched.
const BASE := "res://scenes/actors/native/furnace_foreman_paper_v1.tscn"
const OUTPUT_SCENE := "res://scenes/actors/native/furnace_foreman_paper_v2.tscn"
const OUTPUT_LIBRARY := "res://assets/art/actors/native/furnace_foreman_motion_v2.tres"
const STEM := "Facing/Skeleton2D/"
const DURATIONS := {"jet":[0.24,0.18,0.55],"ram":[0.28,0.5,0.70],"vents":[0.32,0.45,0.60]}
const CHARGED := {
	"jet":{"Torso/Bellows:scale":Vector2(1.18,0.91),"Torso/Chest:rotation":0.06,"Torso/Chest/Door:rotation":-0.24,"Torso/Chest/VentR:rotation":-0.10,"Torso/Head:rotation":-0.06,"Torso/ShoulderR/ArmR/ForearmR:rotation":-0.20},
	"ram":{"Torso:position":Vector2(-5,-13),"Torso:rotation":-0.10,"Torso/Head:rotation":-0.10,"Torso/Chimney:rotation":0.09,"Torso/LegL:rotation":-0.17,"Torso/LegR:rotation":0.17,"Torso/LegL/ShinL:rotation":0.14,"Torso/LegR/ShinR:rotation":0.14,"Torso/ShoulderR/ArmR:rotation":-0.2,"Torso/ShoulderL/ArmL:rotation":0.2},
	"vents":{"Torso/Bellows:scale":Vector2(1.20,0.90),"Torso/Chimney:rotation":-0.08,"Torso/Chest/Door:rotation":-0.20,"Torso/Chest/VentL:rotation":-0.1,"Torso/Chest/VentR:rotation":0.1,"Torso/Head/Visor:rotation":0.10,"Torso/ShoulderL/ArmL:rotation":0.23,"Torso/ShoulderR/ArmR:rotation":-0.23}}
const IMPACT := {
	"jet":{"Torso/Bellows:scale":Vector2(0.82,1.10),"Torso/Chest:rotation":-0.06,"Torso/Chest/Door:rotation":0.30,"Torso/Chest/VentR:rotation":0.12,"Torso/Head:rotation":0.05,"Torso/ShoulderR/ArmR/ForearmR:rotation":0.15},
	"ram":{"Torso:position":Vector2(4,-15),"Torso:rotation":0.17,"Torso/Head:rotation":-0.17,"Torso/Chimney:rotation":-0.12,"Torso/LegL:rotation":0.25,"Torso/LegR:rotation":-0.25,"Torso/LegL/ShinL:rotation":-0.1,"Torso/LegR/ShinR:rotation":0.2,"Torso/ShoulderR/ArmR:rotation":0.18,"Torso/ShoulderL/ArmL:rotation":-0.18},
	"vents":{"Torso/Bellows:scale":Vector2(0.90,1.14),"Torso/Chimney:rotation":0.10,"Torso/Chest/Door:rotation":0.18,"Torso/Chest/VentL:rotation":0.18,"Torso/Chest/VentR:rotation":-0.18,"Torso/Head/Visor:rotation":-0.07,"Torso/ShoulderL/ArmL:rotation":-0.2,"Torso/ShoulderR/ArmR:rotation":0.2}}
func _initialize() -> void: call_deferred("run")
func rest_value(view: Node,path: String) -> Variant:
	var bone: Bone2D = view.get_node(STEM+path.get_slice(":",0))
	match path.get_slice(":",1):
		"position": return bone.rest.origin
		"scale": return bone.rest.get_scale()
		_: return bone.rest.get_rotation()
func make_clip(view: Node,name: String,duration: float,from: Dictionary,to: Dictionary,recovery: bool = false) -> Animation:
	var clip := Animation.new(); clip.resource_name = name; clip.length = duration
	var paths: Array = from.keys()
	for path in to:
		if path not in paths: paths.append(path)
	paths.sort()
	for path in paths:
		var track := clip.add_track(Animation.TYPE_VALUE); clip.track_set_path(track,NodePath(STEM+path))
		var rest = rest_value(view,path)
		clip.track_insert_key(track,0,from.get(path,rest))
		if not recovery: clip.track_insert_key(track,duration*0.4,to.get(path,rest))
		clip.track_insert_key(track,duration,to.get(path,rest))
		if name=="ram_attack" and path in ["Torso/LegL:rotation","Torso/LegR:rotation","Torso/LegL/ShinL:rotation","Torso/LegR/ShinR:rotation"]:
			while clip.track_get_key_count(track)>0: clip.track_remove_key(track,0)
			var right: bool = "R" in path
			var shin: bool = "Shin" in path
			for step in 5:
				var swing := 1.0 if (step%2==0)==right else -1.0
				clip.track_insert_key(track,duration*step/4,0.18+swing*0.10 if shin else swing*0.25)
	return clip
func run() -> void:
	var before := FileAccess.get_sha256(BASE)
	var view: Node2D = load(BASE).instantiate(); root.add_child(view)
	var player: AnimationPlayer = view.get_node("AnimationPlayer")
	player.stop(); player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	var library: AnimationLibrary = player.get_animation_library("").duplicate(true)
	for kind in DURATIONS:
		for suffix in ["warning","attack","recovery"]:
			var index: int = ["warning","attack","recovery"].find(suffix)
			var a: Dictionary = {} if index==0 else CHARGED[kind] if index==1 else IMPACT[kind]
			var b: Dictionary = CHARGED[kind] if index==0 else IMPACT[kind] if index==1 else {}
			library.add_animation(kind+"_"+suffix,make_clip(view,kind+"_"+suffix,DURATIONS[kind][index],a,b,index==2))
	if ResourceSaver.save(library,OUTPUT_LIBRARY,ResourceSaver.FLAG_CHANGE_PATH)!=OK: view.free(); quit(1); return
	# Reload the saved external library; a duplicated resource can remain built-in.
	library = load(OUTPUT_LIBRARY)
	player.remove_animation_library(""); player.add_animation_library("",library)
	view.cancel_action(); player.stop()
	var packed := PackedScene.new()
	var ok := packed.pack(view)==OK and ResourceSaver.save(packed,OUTPUT_SCENE)==OK and FileAccess.get_sha256(BASE)==before
	view.free(); await process_frame
	if ok: print("FURNACE BAKE PASS: 23 covered bones, 9 original action clips, v1 preserved")
	quit(0 if ok else 1)
