extends "res://scripts/components/ScrapperAttack.gd"
## Same locked-sector/obstruction/unique-hit contract, never a pounce.
func get_warning_duration() -> float: return 0.18
func get_released_delay() -> float: return 0.15
func cancel() -> void:
	stage = Stage.IDLE
	cooldown = 2.0
	did_hit = false
func consider(actor: Node2D,target: Node2D,delta: float) -> void:
	cooldown = maxf(0,cooldown-delta)
	if cooldown>0 or is_active() or not is_instance_valid(target): return
	if actor.global_position.distance_to(target.global_position)<=64:
		begin(actor,target,Move.CLAW)
