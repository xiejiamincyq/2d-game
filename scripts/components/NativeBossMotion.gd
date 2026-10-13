extends "res://scripts/components/NativeScrapperMotion.gd"
## No independent combat clock or attack pose. Existing director stays authoritative.
func update(actor: CharacterBody2D,delta: float) -> void:
	if not is_finite(delta) or delta<0:
		return
	locomotion_time += delta
	hit_time += delta
	if not actor.entrance_resolved:
		view.sample_clip("entrance",actor.entrance_progress*view.player.get_animation("entrance").length)
	elif hit_time<view.player.get_animation("hit").length:
		view.sample_clip("hit",hit_time)
	elif actor.velocity.length_squared()>1:
		view.sample_clip("walk",locomotion_time)
	else:
		view.sample_clip("idle",locomotion_time)
