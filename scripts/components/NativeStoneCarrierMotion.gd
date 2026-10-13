extends "res://scripts/components/NativeLargeMotion.gd"
## Read the real melee timer, not an independently advancing attack animation.
## A hit recoil must never hide the warning/impact of an armed heavy attack.
const IMPACT_SECONDS := 0.12
func update(actor: CharacterBody2D,delta: float) -> void:
	if not is_finite(delta) or delta<0:
		return
	if actor.is_attacking and actor.spawn_impulse_remaining<=0 and actor.get_target_player()!=null:
		locomotion_time += delta
		hit_time += delta
		var clip := "slam_warning"
		var at: float = maxf(0,actor.attack_windup-actor.attack_timer)
		if actor.attack_timer<=0:
			var elapsed: float = -actor.attack_timer
			clip = "slam_attack" if elapsed<=IMPACT_SECONDS else "slam_recovery"
			at = elapsed if elapsed<=IMPACT_SECONDS else elapsed-IMPACT_SECONDS
		view.sample_clip(clip,at)
		return
	super.update(actor,delta)
