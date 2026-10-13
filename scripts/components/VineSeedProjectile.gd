extends "res://scripts/components/RiftShardProjectile.gd"
## Reuse tested swept-circle flight, not the shard's artwork or stats.
var source_actor_id := 0
func ignore_source(actor: CollisionObject2D) -> void:
	source_actor_id = actor.get_instance_id()
	# Physics query getters return copies; append then assign the property back.
	var excluded: Array[RID] = sweep_query.exclude
	excluded.append(actor.get_rid())
	sweep_query.exclude = excluded
func _init() -> void:
	super._init()
	radius = 6
	damage = 18
	lifetime = 2.0
	velocity = Vector2(300,0)
	tint = Color("91b47d")
func _on_body_entered(body: Node) -> void:
	if body.get_instance_id()==source_actor_id: return
	super._on_body_entered(body)
func _draw() -> void:
	draw_set_transform(Vector2.ZERO,velocity.angle(),Vector2.ONE)
	var hull := PackedVector2Array([Vector2(-7,0),Vector2(-2,-7),Vector2(6,-3),Vector2(8,0),Vector2(6,3),Vector2(-2,7)])
	var inside := PackedVector2Array([Vector2(-5,0),Vector2(-1,-5),Vector2(5,-2),Vector2(6,0),Vector2(5,2),Vector2(-1,5)])
	draw_colored_polygon(hull,Color("171f25"))
	draw_colored_polygon(inside,tint)
	draw_line(Vector2(-3,0),Vector2(4,0),Color("e3d4b3"),1.0)
