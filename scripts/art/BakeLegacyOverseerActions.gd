extends SceneTree
## Original visual actions on the goal-created, frozen 23-bone paper rig.
const BASE := "res://scenes/actors/native/root_commander_paper_v1.tscn"
const BASE_LIBRARY := "res://assets/art/actors/native/root_commander_motion_v1.tres"
const OUTPUT_SCENE := "res://scenes/actors/native/root_overseer_paper_v1.tscn"
const OUTPUT_LIBRARY := "res://assets/art/actors/native/root_overseer_motion_v1.tres"
const STEM := "Facing/Skeleton2D/"
const DURATIONS := {"sweep":[1.0,0.22,0.28],"slam":[1.1,0.14,0.34],"aimed_fan":[0.45,0.55,0.24],"twin_spiral":[0.28,1.26,0.28],"broken_ring":[0.32,1.3,0.3]}
const CHARGED := {
	"sweep":{"Torso:rotation":-0.05,"Torso/ArmR:rotation":-0.22,"Torso/ArmR/ForearmR:rotation":-0.14,"Torso/ArmL:rotation":0.16,"Torso/Head:rotation":0.06,"Torso/MantleR:rotation":-0.08},
	"slam":{"Torso:position":Vector2(0,-9),"Torso/ArmR:rotation":-0.25,"Torso/ArmR/ForearmR:rotation":-0.13,"Torso/ArmL:rotation":0.20,"Torso/ArmL/ForearmL:rotation":0.14,"Torso/Head:rotation":-0.05,"Torso/MantleL:rotation":0.07},
	"aimed_fan":{"Torso/Core:scale":Vector2(0.91,1.06),"Torso/ArmR:rotation":-0.16,"Torso/ArmR/ForearmR/HandR/Staff:rotation":-0.10,"Torso/ArmL:rotation":0.12,"Torso/Head/Mask:rotation":-0.05},
	"twin_spiral":{"Torso/Core:scale":Vector2(1.08,0.94),"Torso/ArmR:rotation":-0.20,"Torso/ArmL:rotation":0.20,"Torso/MantleR:rotation":-0.10,"Torso/MantleL:rotation":0.10,"Torso/Head:rotation":-0.06,"Torso/SeedPack:rotation":0.06},
	"broken_ring":{"Torso/Core:scale":Vector2(0.90,0.94),"Torso/ArmR:rotation":-0.12,"Torso/ArmL:rotation":0.12,"Torso/MantleR:rotation":-0.10,"Torso/MantleL:rotation":0.10,"Torso/Head/HornR:rotation":-0.08,"Torso/Head/HornL:rotation":0.08}
}
const IMPACT := {
	"sweep":{"Torso:rotation":0.09,"Torso/ArmR:rotation":0.24,"Torso/ArmR/ForearmR:rotation":0.18,"Torso/ArmL:rotation":-0.14,"Torso/Head:rotation":-0.05,"Torso/MantleR:rotation":0.09},
	"slam":{"Torso:position":Vector2(0,-3),"Torso/ArmR:rotation":0.20,"Torso/ArmR/ForearmR:rotation":0.20,"Torso/ArmL:rotation":-0.18,"Torso/ArmL/ForearmL:rotation":-0.14,"Torso/Head:rotation":0.08,"Torso/MantleL:rotation":-0.07},
	"aimed_fan":{"Torso/Core:scale":Vector2(1.12,0.94),"Torso/ArmR:rotation":0.13,"Torso/ArmR/ForearmR/HandR/Staff:rotation":0.08,"Torso/ArmL:rotation":-0.10,"Torso/Head/Mask:rotation":0.05},
	"twin_spiral":{"Torso/Core:scale":Vector2(0.94,1.08),"Torso/ArmR:rotation":0.16,"Torso/ArmL:rotation":-0.16,"Torso/MantleR:rotation":0.09,"Torso/MantleL:rotation":-0.09,"Torso/Head:rotation":0.07,"Torso/SeedPack:rotation":-0.06},
	"broken_ring":{"Torso/Core:scale":Vector2(1.14,1.08),"Torso/ArmR:rotation":0.22,"Torso/ArmL:rotation":-0.22,"Torso/MantleR:rotation":0.14,"Torso/MantleL:rotation":-0.14,"Torso/Head/HornR:rotation":0.07,"Torso/Head/HornL:rotation":-0.07}
}
func _initialize() -> void: call_deferred("run")
func rest_value(view: Node,path: String) -> Variant:
	var bone: Bone2D = view.get_node(STEM+path.get_slice(":",0))
	match path.get_slice(":",1):
		"position": return bone.rest.origin
		"scale": return bone.rest.get_scale()
		_: return bone.rest.get_rotation()
func blend(a: Variant,b: Variant,ratio: float) -> Variant:
	return a.lerp(b,ratio) if a is Vector2 else lerpf(float(a),float(b),ratio)
func make_clip(view: Node,name: String,duration: float,from: Dictionary,to: Dictionary,active: bool=false) -> Animation:
	var clip := Animation.new(); clip.resource_name=name; clip.length=duration
	var paths: Array=from.keys()
	for path in to:
		if path not in paths: paths.append(path)
	paths.sort()
	for path in paths:
		var track:=clip.add_track(Animation.TYPE_VALUE)
		clip.track_set_path(track,NodePath(STEM+path))
		var rest=rest_value(view,path)
		for index in 5:
			var phase: float=[0.0,0.25,0.55,0.8,1.0][index]
			var ratio: float=[0.0,0.95,0.72,1.10,1.0][index] if active else phase
			clip.track_insert_key(track,duration*phase,blend(from.get(path,rest),to.get(path,rest),ratio))
	return clip
func run() -> void:
	var frozen: Dictionary={BASE:FileAccess.get_sha256(BASE),BASE_LIBRARY:FileAccess.get_sha256(BASE_LIBRARY)}
	var view: Node2D=load(BASE).instantiate(); root.add_child(view)
	var player: AnimationPlayer=view.get_node("AnimationPlayer")
	player.stop(); player.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	var library: AnimationLibrary=player.get_animation_library("").duplicate(true)
	for kind in DURATIONS:
		for index in 3:
			var name: String=kind+"_"+["warning","attack","recovery"][index]
			var a: Dictionary={} if index==0 else CHARGED[kind] if index==1 else IMPACT[kind]
			var b: Dictionary=CHARGED[kind] if index==0 else IMPACT[kind] if index==1 else {}
			library.add_animation(name,make_clip(view,name,DURATIONS[kind][index],a,b,index==1))
	var phase_pose: Dictionary={"Torso/Core:scale":Vector2(1.16,1.08),"Torso/Head:rotation":0.10,"Torso/ArmL:rotation":0.20,"Torso/ArmR:rotation":-0.20,"Torso/SeedPack:rotation":-0.07}
	library.add_animation("phase_transition",make_clip(view,"phase_transition",0.65,{},phase_pose,true))
	if ResourceSaver.save(library,OUTPUT_LIBRARY,ResourceSaver.FLAG_CHANGE_PATH)!=OK: view.free(); quit(1); return
	library=load(OUTPUT_LIBRARY)
	player.remove_animation_library(""); player.add_animation_library("",library)
	view.cancel_action(); player.stop()
	var packed:=PackedScene.new()
	var ok:=packed.pack(view)==OK and ResourceSaver.save(packed,OUTPUT_SCENE)==OK
	for path in frozen: ok=ok and FileAccess.get_sha256(path)==frozen[path]
	view.free(); await process_frame
	if ok: print("LEGACY OVERSEER BAKE PASS: 23 covered bones, 16 original action clips, frozen v1 preserved")
	quit(0 if ok else 1)
