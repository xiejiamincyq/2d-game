extends "res://scripts/components/NativeScrapperMotion.gd"
## Only non-attack poses until the all-character rig gate opens. Existing
## gameplay warnings/impacts remain transitional, not new large attack art.
var entering := false
var entrance_time := 0.0
func update(actor: CharacterBody2D,delta: float) -> void:
	if not is_finite(delta) or delta<0:
		return
	locomotion_time += delta
	hit_time += delta
	if actor.spawn_impulse_remaining>0:
		if not entering:
			entrance_time = 0
		entering = true
		entrance_time += delta
	else:
		entering = false
	var clip := "idle"
	var seconds := locomotion_time
	if hit_time < view.player.get_animation("hit").length:
		clip = "hit"
		seconds = hit_time
	elif entering:
		clip = "entrance"
		seconds = entrance_time
	elif not actor.is_attacking and actor.velocity.length_squared()>1:
		clip = "walk"
	view.sample_clip(clip,seconds)
