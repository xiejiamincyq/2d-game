extends "res://scripts/components/NativeBossMotion.gd"
## Visual-only reader; no independently advancing attack clock or damage events.
const ACTIONS := [&"beam",&"probes",&"refract"]
func update(actor: CharacterBody2D,delta: float) -> void:
	if not is_finite(delta) or delta<0 or not view.is_inside_tree() or not view.skeleton.is_inside_tree(): return
	var combat = actor.attack_director
	if actor.entrance_resolved and combat!=null and combat.is_attacking():
		if combat.action not in ACTIONS or combat.action_stage not in [1,2,3] or not is_finite(combat.action_elapsed) or combat.action_elapsed<0: return
		locomotion_time += delta; hit_time += delta
		var clip: String = String(combat.action)+"_"+["warning","attack","recovery"][combat.action_stage-1]
		var elapsed: float = combat.action_elapsed
		if combat.action_stage==combat.Stage.WARNING: elapsed = elapsed/combat.DURATIONS[combat.action][0]*view.player.get_animation(clip).length
		view.sample_clip(clip,elapsed)
		return
	super.update(actor,delta)
