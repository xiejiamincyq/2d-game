extends "res://scripts/components/NativeBossMotion.gd"
## Bones read the Archivist clock, never advance it or emit damage.
func update(actor: CharacterBody2D,delta: float) -> void:
	if not is_finite(delta) or delta<0 or not view.is_inside_tree() or not view.skeleton.is_inside_tree(): return
	var combat = actor.attack_director
	if actor.entrance_resolved and combat!=null and combat.is_attacking():
		locomotion_time += delta; hit_time += delta
		var clip: String = String(combat.action)+"_"+["warning","attack","recovery"][combat.action_stage-1]
		var elapsed: float = combat.action_elapsed
		if combat.action_stage==combat.Stage.WARNING: elapsed = elapsed/combat.DURATIONS[combat.action][0]*view.player.get_animation(clip).length
		view.sample_clip(clip,elapsed)
		return
	super.update(actor,delta)
