extends SceneTree
## Original offline optical/tripod articulation; animation never emits damage.
const BASE := "res://scenes/actors/native/rift_observer_paper_v1.tscn"
const BASE_LIBRARY := "res://assets/art/actors/native/rift_observer_motion_v1.tres"
const OUTPUT_SCENE := "res://scenes/actors/native/rift_observer_paper_v2.tscn"
const OUTPUT_LIBRARY := "res://assets/art/actors/native/rift_observer_motion_v2.tres"
const MANIFEST := "res://docs/art/native-manifests/rift_observer_paper_v2.json"
const Gate = preload("res://scripts/art/NativeRigCheckpoint.gd")
const STEM := "Facing/Skeleton2D/"
const DURATIONS := {"beam":[0.30,0.12,0.45],"probes":[0.32,0.56,0.52],"refract":[0.30,0.60,0.60]}
func _initialize() -> void: call_deferred("run")
func offsets(action: String,peak: bool) -> Dictionary:
	var p := {
		"Torso:position":Vector2(0,2 if peak else -3),
		"Torso:rotation":0.018 if peak else -0.015,
		"Torso/LegL:rotation":-0.04 if peak else 0.06,
		"Torso/LegR:rotation":0.04 if peak else -0.06,
		"Torso/LegB:rotation":-0.03 if peak else 0.05,
		"Torso/LegL/ShinL:rotation":0.10 if peak else -0.08,
		"Torso/LegR/ShinR:rotation":-0.10 if peak else 0.08,
		"Torso/LegB/ShinB:rotation":0.08 if peak else -0.07,
		"Torso/Keel/Counterweight:rotation":0.12 if peak else -0.05}
	match action:
		"beam":
			p.merge({
				"Torso/Lens:position":Vector2(0,4 if peak else -3),
				"Torso/Lens:rotation":0.025 if peak else -0.025,
				"Torso/Lens/IrisL:position":Vector2(-5 if peak else 4.5,0),
				"Torso/Lens/IrisR:position":Vector2(5 if peak else -4.5,0),
				"Torso/Lens/Pupil:position":Vector2(3 if peak else 0,2 if peak else 0),
				"Torso/Lens/Pupil:scale":Vector2(0.10,0.10) if peak else Vector2(-0.20,-0.20),
				"Torso/ScopeArmL/ElbowL:rotation":-0.08 if peak else 0.08,
				"Torso/ScopeArmR/ElbowR:rotation":0.08 if peak else -0.08,
				"Torso/Beacon:rotation":0.06 if peak else -0.04},true)
		"probes":
			for side in ["L","R"]:
				var sign_x := -1.0 if side=="L" else 1.0
				var arm: String = "Torso/ScopeArm"+side
				p[arm+":rotation"] = sign_x*(0.24 if peak else -0.14)
				p[arm+"/Elbow"+side+":rotation"] = sign_x*(0.46 if peak else -0.18)
				p[arm+"/Elbow"+side+":position"] = Vector2(sign_x*9,0) if peak else Vector2(-sign_x*2,1)
				p[arm+"/Elbow"+side+"/Probe"+side+":rotation"] = sign_x*(-0.16 if peak else -0.12)
				p[arm+"/Elbow"+side+"/Probe"+side+":position"] = Vector2(sign_x*7,-1) if peak else Vector2(-sign_x*4,2)
			p["Torso/Lens/IrisL:position"] = Vector2(-1.5 if peak else 1,0)
			p["Torso/Lens/IrisR:position"] = Vector2(1.5 if peak else -1,0)
			p["Torso/Beacon:rotation"] = 0.05 if peak else -0.05
		"refract":
			p["Torso:position"] = Vector2(0,4 if peak else -5)
			p["Torso/RingHub:rotation"] = 0.0
			p["Torso/Lens:rotation"] = -0.04 if peak else 0.035
			p["Torso/Lens/IrisL:position"] = Vector2(-1.5 if peak else 1,0)
			p["Torso/Lens/IrisR:position"] = Vector2(1.5 if peak else -1,0)
			p["Torso/Beacon:rotation"] = 0.10 if peak else -0.045
			for index in 6:
				var path: String = "Torso/RingHub/Segment"+["A","B","C","D","E","F"][index]
				p[path+":rotation"] = (1 if index%2==0 else -1)*(0.13 if peak else 0.035)
				p[path+":position"] = Vector2.from_angle(-PI/2+TAU*index/6)*(5.5 if peak else 1.8)
	return p
func rest_value(view: Node,path: String) -> Variant:
	var rest: Transform2D = view.get_node(STEM+path.get_slice(":",0)).rest
	match path.get_slice(":",1):
		"position": return rest.origin
		"scale": return rest.get_scale()
		_: return rest.get_rotation()
func value_at(view: Node,path: String,offset: Variant) -> Variant:
	var rest = rest_value(view,path)
	return rest*(Vector2.ONE+offset) if path.get_slice(":",1)=="scale" else rest+offset
func make_clip(view: Node,action: String,stage: int) -> Animation:
	var charged := offsets(action,false); var peak := offsets(action,true)
	var clip := Animation.new(); clip.resource_name = action+"_"+["warning","attack","recovery"][stage]; clip.length = DURATIONS[action][stage]
	var paths: Array = charged.keys(); paths.sort()
	for path in paths:
		var rest = rest_value(view,path)
		var warning = value_at(view,path,charged[path]); var released = value_at(view,path,charged[path]*0.18)
		var track := clip.add_track(Animation.TYPE_VALUE); clip.track_set_path(track,NodePath(STEM+path))
		clip.track_insert_key(track,0,rest if stage==0 else warning if stage==1 else released)
		if stage==1:
			if action=="refract":
				for phase in [0.18,0.48,0.78]: clip.track_insert_key(track,clip.length*phase,value_at(view,path,peak[path]))
				for phase in [0.32,0.62]: clip.track_insert_key(track,clip.length*phase,warning)
			else:
				var phase := 0.16 if action=="beam" else 0.18 if "ScopeArmL" in path else 0.46 if "ScopeArmR" in path else 0.30
				clip.track_insert_key(track,clip.length*phase,value_at(view,path,peak[path]))
			clip.track_insert_key(track,clip.length*0.90,released)
		clip.track_insert_key(track,clip.length,warning if stage==0 else released if stage==1 else rest)
	return clip
func run() -> void:
	var entry: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
	if not Gate.new().validate_entry(entry).is_empty(): push_error("Unreviewed observer migration request"); quit(1); return
	if FileAccess.file_exists(OUTPUT_SCENE) or FileAccess.file_exists(OUTPUT_LIBRARY): push_error("Fresh observer outputs required, never overwrite approved assets"); quit(1); return
	var before := {BASE:FileAccess.get_sha256(BASE),BASE_LIBRARY:FileAccess.get_sha256(BASE_LIBRARY)}
	var view: Node2D = load(BASE).instantiate(); root.add_child(view)
	var player: AnimationPlayer = view.get_node("AnimationPlayer"); player.stop(); player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	var library: AnimationLibrary = player.get_animation_library("").duplicate(true)
	for action in DURATIONS:
		for stage in 3:
			var clip := make_clip(view,action,stage); library.add_animation(clip.resource_name,clip)
	if ResourceSaver.save(library,OUTPUT_LIBRARY,ResourceSaver.FLAG_CHANGE_PATH)!=OK: view.free(); quit(1); return
	library = load(OUTPUT_LIBRARY); player.remove_animation_library(""); player.add_animation_library("",library)
	view.cancel_action(); player.stop()
	# Continuous GPU probes exceed the original 16px frame by 7.30px.
	# Measured 23.30px + 1.70px safety; visual-only, not body scale/collision.
	view.visual_bounds_padding = 25.0
	var packed := PackedScene.new(); var ok := packed.pack(view)==OK and ResourceSaver.save(packed,OUTPUT_SCENE)==OK
	for path in before: ok = ok and FileAccess.get_sha256(path)==before[path]
	view.free(); await process_frame
	if ok: print("RIFT OBSERVER BAKE PASS: 30 bones,9 original articulated clips; v1 preserved")
	quit(0 if ok else 1)
