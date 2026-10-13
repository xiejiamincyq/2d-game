extends "res://scripts/components/NativeBossMotion.gd"
## Furnace action sampling is subordinate to the actual combat stage.
func update(actor: CharacterBody2D,delta: float) -> void:
	if not is_finite(delta) or delta<0: return
	var combat = actor.attack_director
	if actor.entrance_resolved and combat!=null and combat.is_attacking():
		locomotion_time += delta; hit_time += delta
		var suffix: String = ["warning","attack","recovery"][combat.action_stage-1]
		var clip := String(combat.action)+"_"+suffix
		var elapsed: float = combat.action_elapsed
		if combat.action_stage==combat.Stage.WARNING: elapsed = elapsed/combat.DURATIONS[combat.action][0]*view.player.get_animation(clip).length
		view.sample_clip(clip,elapsed)
		return
	super.update(actor,delta)
