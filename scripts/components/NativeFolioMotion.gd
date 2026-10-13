extends "res://scripts/components/NativeSporelingMotion.gd"
## Hand/satchel animation is visual-only; gameplay alone releases a projectile.
const RELEASE := "Facing/Skeleton2D/Torso/ArmR/ForearmR/HandR/Payload/Release"
const OriginSafety := preload("res://scripts/components/NativeProjectileOriginSafety.gd")

func get_safe_release(actor: CharacterBody2D) -> Vector2:
	var origin: Vector2 = view.get_node(RELEASE).global_position
	return OriginSafety.resolve(actor,origin,9)
