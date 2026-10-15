extends "res://scripts/components/NativeBossMotion.gd"
## Attack stages share the actual chapter director clock, not autoplay events.
func sample_seed_release() -> void:
	# The preview and birth use the same t=0 release pose. A normal physics
	# frame can carry time past the warning boundary; that remainder belongs
	# to subsequent animation, not to a different unpreviewed launch point.
	view.sample_clip("seeds_attack",0)

func update(actor: CharacterBody2D,delta: float) -> void:
	if not is_finite(delta) or delta<0: return
	var combat = actor.attack_director
	if actor.entrance_resolved and combat!=null and combat.is_attacking():
		locomotion_time += delta
		hit_time += delta
		var suffix: String = ["warning","attack","recovery"][combat.action_stage-1]
		var clip := String(combat.action)+"_"+suffix
		var sample_time: float = combat.action_elapsed
		if combat.action==&"roots" or combat.action_stage==combat.Stage.WARNING:
			sample_time = sample_time/combat.DURATIONS[combat.action][combat.action_stage-1]*view.player.get_animation(clip).length
		view.sample_clip(clip,sample_time)
		return
	super.update(actor,delta)
