extends "res://scripts/world/DestructibleObstacle.gd"
class_name ArenaObstacle

const PropArt = preload("res://scripts/world/ArenaPaperPropArt.gd")
const TerrainSweep = preload("res://scripts/world/TerrainSweep.gd")

var obstacle_size := Vector2(160.0, 100.0)
var obstacle_kind: StringName = &"planter"
var occlusion_rect := Rect2()
var plinth_style: StyleBoxFlat
var art: Node2D

func update_player_occlusion(player_position: Vector2, active: bool, delta: float) -> void:
	# Only fade a foreground obstacle overlapping the player's 84px visual,
	# never the player itself. Retain enough opacity to read the solid footprint.
	var local_player := to_local(player_position)
	var player_rect := Rect2(local_player - Vector2(42, 42), Vector2(84, 84))
	var in_front := local_player.y < 0.0
	var covers_player := active and in_front and occlusion_rect.intersects(player_rect)
	art.modulate.a = move_toward(art.modulate.a, 0.32 if covers_player else 1.0, maxf(delta, 0.0) * 5.0)

func setup(rect: Rect2, kind: StringName) -> void:
	set_layout_footprint(rect)
	name = "ArenaObstacle_%s" % kind
	# Sort at the front contact edge; keep the original world-space collider.
	position = Vector2(rect.get_center().x, rect.end.y)
	obstacle_size = rect.size
	obstacle_kind = kind
	collision_layer |= 1 | TerrainSweep.QUERY_LAYER
	collision_mask = 0
	add_to_group(&"arena_obstacles")
	var collision := CollisionShape2D.new()
	collision.name = "CollisionShape2D"
	var shape := RectangleShape2D.new()
	shape.size = obstacle_size
	collision.shape = shape
	collision.position.y = -obstacle_size.y * 0.5
	add_child(collision)

	art = PropArt.new()
	art.name = "Art"
	art.configure(obstacle_size,kind)
	occlusion_rect = art.get_visual_rect()
	add_child(art)
	plinth_style = StyleBoxFlat.new()
	plinth_style.bg_color = Color("6b684b") if kind == &"planter" else Color("8d987d")
	plinth_style.border_color = Color("142520")
	plinth_style.set_border_width_all(3)
	plinth_style.set_corner_radius_all(5)
	plinth_style.anti_aliasing = true
	queue_redraw()

func _draw() -> void:
	var footprint := Rect2(Vector2(-obstacle_size.x * 0.5, -obstacle_size.y), obstacle_size)
	draw_rect(Rect2(footprint.position + Vector2(3, 5), footprint.size), Color(0.09, 0.17, 0.15, 0.22))
	# The full solid footprint stays visible; the planter's exposed strip is soil,
	# not an empty slab. Small rounded corners do not change its collider.
	if plinth_style != null:
		draw_style_box(plinth_style, footprint)
	if obstacle_kind == &"planter":
		for x in [-0.28, 0.0, 0.28]:
			var center := Vector2(obstacle_size.x * x, -obstacle_size.y + 15.0)
			draw_line(center - Vector2(9, 0), center + Vector2(9, 0), Color("5d624b"), 2.0, true)
