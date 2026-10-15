extends "res://scripts/art/VerifyFoundryChapterFlow.gd"
const DenseGate=preload("DenseInputGate.gd")
var dense_gate: Node
func _initialize() -> void:
	dense_gate=DenseGate.new(); root.call_deferred("add_child",dense_gate)
	super._initialize()
	additional_sources.append_array(["docs/performance/campaign-endless-dense-v2/ProbeFoundry.gd","docs/performance/campaign-endless-dense-v2/DenseInputGate.gd"])
func pilot_motion(chapter: Node,policy: RefCounted,step: int,threats: Array[Vector2],telegraph: Node,danger_distance: float) -> Dictionary:
	dense_gate.bind_live_chapter(chapter)
	return super.pilot_motion(chapter,policy,step,threats,telegraph,danger_distance)
func additional_report() -> Dictionary:
	var result:=super.additional_report()
	result["dense_input_probe"]=dense_gate.snapshot()
	return result
