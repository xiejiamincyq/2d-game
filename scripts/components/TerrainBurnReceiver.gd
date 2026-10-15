extends Node
## Lazily attached only by flame contact. Reuses the existing five-stack burn
## clock, outlives the emitting trail, and dies with its terrain receiver.
const Burn=preload("res://scripts/components/BurnStatus.gd")
const CHILD_NAME: StringName=&"TerrainFlameBurn"
var status:=Burn.new()

static func apply(target: Node2D,base_attack: float,duration: float) -> void:
	if not is_instance_valid(target) or target.is_queued_for_deletion() or not target.is_inside_tree(): return
	if not is_finite(base_attack) or not is_finite(duration) or base_attack<=0 or duration<=0: return
	var receiver=target.get_node_or_null(NodePath(CHILD_NAME))
	if receiver==null:
		receiver=load("res://scripts/components/TerrainBurnReceiver.gd").new()
		receiver.name=CHILD_NAME; target.add_child(receiver)
	receiver.status.apply_stack(base_attack,duration,0,&"burn")
	receiver.set_process(true)

func _process(delta: float) -> void:
	var target:=get_parent() as Node2D
	if not is_instance_valid(target) or target.is_queued_for_deletion() or not target.is_in_group(&"destructible_terrain"):
		queue_free(); return
	if not is_finite(delta) or delta<=0: return
	var amount:=status.advance(delta)
	if amount>0: target.take_damage(amount,&"burn")
	# Keep one dormant child for reuse. A queued child could swallow a fresh
	# contact in the same deferred-delete frame; the terrain owns its lifetime.
	if status.get_stack_count()==0: set_process(false)
