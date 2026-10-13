extends "res://scripts/components/NativeScrapperMotion.gd"
## Visual-only sampling: the charge controller owns motion, damage and phase time.
func update(actor: CharacterBody2D, delta: float) -> void:
	if not is_finite(delta) or delta < 0:
		return
	locomotion_time += delta
	hit_time += delta
	var clip := "idle"
	var seconds := locomotion_time
	var show_action: bool = actor.spawn_impulse_remaining <= 0 and actor.get_target_player() != null
	var charge = actor.charge_attack
	if show_action and charge.is_active():
		clip = "charge_warning" if charge.stage == charge.Stage.WARNING else "charge" if charge.stage == charge.Stage.ACTIVE else "charge_recovery"
		seconds = charge.elapsed
	elif show_action and actor.is_attacking:
		clip = "warning" if actor.attack_timer > 0 else "attack"
		var progress: float = 1 - actor.attack_timer / actor.attack_windup if actor.attack_timer > 0 else -actor.attack_timer / actor.attack_recovery
		seconds = view.player.get_animation(clip).length * clampf(progress,0,1)
	elif hit_time < 0.16:
		clip = "hit"
		seconds = hit_time
	elif actor.velocity.length_squared() > 1:
		clip = "walk"
	view.sample_clip(clip,seconds)
