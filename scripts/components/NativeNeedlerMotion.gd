extends "res://scripts/components/NativeSporelingMotion.gd"
## Same visual ranged clocks, distinct articulated hand-gun aiming. No gameplay
## state writes, projectile emission, or enemy-root rotations in animations.
const GUN := "Facing/Skeleton2D/Torso/ArmR/ForearmR/HandR/NeedleGun"
const OriginSafety := preload("res://scripts/components/NativeProjectileOriginSafety.gd")
func update(actor: CharacterBody2D,delta: float) -> void:
	if not is_finite(delta) or delta<0:
		return
	# Same-clip sampling only reapplies keyed tracks; aim-only joints otherwise
	# retain last frame's procedural pose when a hidden target disappears.
	var gun: Bone2D = view.get_node(GUN)
	var arm: Bone2D = view.skeleton.get_node("Torso/ArmR")
	gun.apply_rest()
	arm.apply_rest()
	super.update(actor,delta)
	if actor.spawn_impulse_remaining>0:
		return
	var target: Node2D = actor.get_target_player()
	if target==null:
		return
	var target_at: Vector2 = actor.ranged_target_position if actor.ranged_is_winding_up or shot_remaining>0 else target.global_position
	var facing: Node2D = view.get_node("Facing")
	if absf(target_at.x-actor.global_position.x)>0.01:
		view.set_facing_left(target_at.x<actor.global_position.x)
	var direction := facing.to_local(target_at)-facing.to_local(gun.global_position)
	var hand: Bone2D = gun.get_parent()
	var hand_axis := facing.to_local(hand.to_global(Vector2.RIGHT))-facing.to_local(hand.global_position)
	var correction := wrapf(direction.angle()-hand_axis.angle(),-PI,PI)
	arm.rotation = clampf(arm.rotation+correction,-PI/3,PI/3)
	direction = hand.to_local(target_at)-gun.position
	gun.rotation = clampf(direction.angle(),-deg_to_rad(35),deg_to_rad(35))

func get_safe_muzzle(actor: CharacterBody2D) -> Vector2:
	var muzzle: Vector2 = view.get_node(GUN+"/Muzzle").global_position
	return OriginSafety.resolve(actor,muzzle,3)
