extends StaticBody2D
## Solid, opaque footprint and separately fading upper decoration.

const TerrainSweep = preload("res://scripts/world/TerrainSweep.gd")
const PropArt = preload("res://scripts/world/NurseryPropArt.gd")
const INK := Color("142520")

var obstacle_size := Vector2.ZERO
var occlusion_rect := Rect2()
var art: Node2D

func setup(rect: Rect2, kind: StringName) -> void:
	name = "Nursery_%s" % kind
	position = Vector2(rect.get_center().x, rect.end.y)
	obstacle_size = rect.size
	collision_layer = 1 | TerrainSweep.QUERY_LAYER
	collision_mask = 0
	add_to_group(&"arena_obstacles")
	var collision := CollisionShape2D.new()
	collision.name = "CollisionShape2D"
	var shape := RectangleShape2D.new()
	shape.size = rect.size
	collision.shape = shape
	collision.position.y = -rect.size.y * 0.5
	add_child(collision)
	art = PropArt.new()
	art.name = "Art"
	art.configure(rect.size, kind)
	add_child(art)
	occlusion_rect = Rect2(Vector2(-rect.size.x * 0.5, -rect.size.y - 28), rect.size + Vector2(0, 28))
	queue_redraw()

func update_player_occlusion(player_position: Vector2, active: bool, delta: float) -> void:
	var local_player := to_local(player_position)
	var player_rect := Rect2(local_player - Vector2(42, 42), Vector2(84, 84))
	var covered := active and local_player.y < 0 and occlusion_rect.intersects(player_rect)
	art.modulate.a = move_toward(art.modulate.a, 0.32 if covered else 1, maxf(delta, 0) * 5)

func _draw() -> void:
	var footprint := Rect2(Vector2(-obstacle_size.x * 0.5, -obstacle_size.y), obstacle_size)
	draw_rect(footprint, Color("6b6c50"))
	draw_rect(footprint, INK, false, 4)
	# Always visible front contact edge, exactly on the collider, not a tall sprite.
	draw_line(Vector2(-obstacle_size.x * 0.5, -2), Vector2(obstacle_size.x * 0.5, -2), Color("ac9871"), 4)
