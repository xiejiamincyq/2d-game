extends Node
## Supplementary input-only load case. Never fed into the 12-leg victory chain.
const HOLD_SECONDS:=10.0
var began_usec:=0
var ended_usec:=0
var suppressed_ticks:=0
var peak:=0
var completed:=false
func _ready() -> void:
	process_mode=Node.PROCESS_MODE_ALWAYS
	process_physics_priority=-1000 # Input shaping before the real Player physics.
func _physics_process(_delta: float) -> void:
	var chapter:=get_tree().current_scene
	if completed or get_tree().paused or not is_instance_valid(chapter) or not chapter.has_method("_chapter_number"): return
	var director: Node=chapter.get("director")
	if not is_instance_valid(director) or director.state!=director.State.COMBAT or director.encounter_index!=0: return
	var count: int=director.get_active_enemies().size()
	peak=maxi(peak,count)
	var now:=Time.get_ticks_usec()
	if began_usec==0:
		if count<12: return
		began_usec=now
	if now-began_usec>=int(HOLD_SECONDS*1000000):
		ended_usec=now; completed=true
		return
	# Ordinary running remains under the existing obstacle/threat pilot. No
	# actor, spawn, HP, damage, RNG, reward, timer or pause state is assigned.
	Input.action_release("fire")
	Input.action_release("dash_melee")
	suppressed_ticks+=1
func snapshot() -> Dictionary:
	return {"supplement_only":true,"completed":completed,"held_seconds":float(ended_usec-began_usec)/1000000.0 if completed else 0.0,
		"suppressed_physics_ticks":suppressed_ticks,"peak_during_first_encounter":peak,
		"scope":"Ten seconds of real movement with fire/dash input released after >=12 live enemies; remaining gameplay and clocks unchanged. Copies only an already accepted actual predecessor journal. Not a replacement or predecessor for the ordinary 12-leg chain."}
