extends "res://scripts/components/ScrapperAttack.gd"
## Locked short-range pulse. No pounce or visual event can apply damage.
func get_warning_duration() -> float: return 0.40
func get_released_delay() -> float: return 0.15
func cancel() -> void:
	stage = Stage.IDLE
	cooldown = 2.2
	did_hit = false
func reach(actor: Node2D) -> float: return 28.0 if actor.is_fragment else 46.0
func consider(actor: Node2D,target: Node2D,delta: float) -> void:
	cooldown = maxf(0,cooldown-delta)
	if cooldown>0 or is_active() or not is_instance_valid(target): return
	if actor.global_position.distance_to(target.global_position)<=reach(actor):
		begin(actor,target,Move.CLAW)
func get_warning_polygon(actor: Node2D) -> PackedVector2Array:
	var points := PackedVector2Array([origin-actor.global_position])
	for index in 17:
		points.append(origin-actor.global_position+direction.rotated(lerpf(-PI/3,PI/3,index/16.0))*reach(actor))
	return points
func get_attack_strokes(actor: Node2D) -> Array[PackedVector2Array]:
	if stage!=Stage.ACTIVE: return []
	return Drawing.claw_strokes(origin-actor.global_position,direction,(elapsed-get_warning_duration())/CLAW_ACTIVE,reach(actor),PI/3)
