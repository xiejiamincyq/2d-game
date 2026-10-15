extends Node
## Explicit observed actor owner; Window.current_scene is not the driver API.
const HOLD_SECONDS:=10.0
var chapter_reference: WeakRef
var began_usec:=0
var ended_usec:=0
var suppressed_ticks:=0
var peak:=0
var completed:=false
func bind_live_chapter(chapter: Node) -> void:
	chapter_reference=weakref(chapter)
func _ready() -> void:
	process_mode=Node.PROCESS_MODE_ALWAYS
	process_physics_priority=-1000
func _physics_process(_delta: float) -> void:
	var chapter: Node=chapter_reference.get_ref() as Node if chapter_reference!=null else null
	if completed or get_tree().paused or not is_instance_valid(chapter): return
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
	Input.action_release("fire")
	Input.action_release("dash_melee")
	suppressed_ticks+=1
func snapshot() -> Dictionary:
	return {"supplement_only":true,"completed":completed,"held_seconds":float(ended_usec-began_usec)/1000000.0 if completed else 0.0,
		"suppressed_physics_ticks":suppressed_ticks,"peak_during_first_encounter":peak,"owner_binding":"actual pilot chapter WeakRef",
		"scope":"Ten seconds of ordinary movement with fire/dash input released after >=12 live enemies; no actor, spawn, HP, damage, RNG, reward, clock or pause writes. Only a supplementary load case, never part of the ordinary 12-leg chain."}
